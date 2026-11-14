import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'music_service.dart';
import 'platform_search_service.dart';
import '../utils/audio_resampler.dart';
import '../utils/helper.dart';
import '../utils/shazam_signature_generator.dart';

class RecognizedSong {
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final double confidence; // 0.0 to 1.0
  final MediaItem? mediaItem;
  final String? source;

  const RecognizedSong({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    required this.confidence,
    this.mediaItem,
    this.source,
  });

  MediaItem toMediaItem() {
    if (mediaItem != null) return mediaItem!;
    return MediaItem(
      id: "rec_${title.hashCode}_${artist.hashCode}",
      title: title,
      artist: artist,
      album: album,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl!) : null,
    );
  }
}

class SongRecognizerService extends GetxService {
  static final SongRecognizerService _instance =
      SongRecognizerService._internal();
  factory SongRecognizerService() => _instance;
  SongRecognizerService._internal();

  Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  @visibleForTesting
  set dioForTesting(Dio d) => _dio = d;

  AudioRecorder? _recorder;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Ensure audio recorder is initialized
  AudioRecorder _getRecorder() {
    _recorder ??= AudioRecorder();
    return _recorder!;
  }

  /// Request microphone permission safely
  Future<bool> checkAndRequestMicPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final requested = await Permission.microphone.request();
      return requested.isGranted;
    } catch (e) {
      printERROR("[SongRecognizer] Permission check error: $e");
      return false;
    }
  }

  /// Real acoustic music recognition using device microphone and Shazam's recognition backend.
  /// Records [listenDuration] seconds of audio, builds an acoustic fingerprint, and identifies the song.
  Future<RecognizedSong?> listenAndRecognize({
    Duration listenDuration = const Duration(seconds: 6),
    void Function(String status)? onProgress,
  }) async {
    final hasPerm = await checkAndRequestMicPermission();
    if (!hasPerm) {
      throw Exception("Microphone permission is required to listen to music.");
    }

    final recorder = _getRecorder();
    if (!await recorder.hasPermission()) {
      throw Exception("Microphone recording permission not granted.");
    }

    _isRecording = true;
    String? tempFilePath;

    try {
      final tempDir = await getTemporaryDirectory();
      tempFilePath =
          '${tempDir.path}/spy_shazam_${DateTime.now().millisecondsSinceEpoch}.raw';

      onProgress?.call("listening");
      printINFO("[SongRecognizer] Starting 44.1kHz PCM recording to: $tempFilePath");

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: tempFilePath,
      );

      // Record for the specified duration
      await Future.delayed(listenDuration);

      onProgress?.call("analyzing");
      final savedPath = await recorder.stop();
      _isRecording = false;

      final filePath = savedPath ?? tempFilePath;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("Audio recording file could not be created.");
      }

      final rawBytes = await file.readAsBytes();
      try {
        await file.delete();
      } catch (_) {}

      if (rawBytes.length < 16000) {
        throw Exception("Audio sample too short or empty.");
      }

      printINFO("[SongRecognizer] Recorded ${rawBytes.length} bytes. Resampling to 16kHz...");
      final decoded = DecodedAudio(
        data: rawBytes,
        channelCount: 1,
        sampleRate: 44100,
      );

      final resampled = AudioResampler.resample(
        decoded,
        VibraSignature.requiredSampleRate,
      );

      printINFO("[SongRecognizer] Generating Shazam signature...");
      final signature = VibraSignature.fromI16(resampled.data);
      final sampleDurationMs =
          (resampled.data.length ~/ 2) * 1000 ~/ VibraSignature.requiredSampleRate;

      printINFO("[SongRecognizer] Calling Shazam API (sample: ${sampleDurationMs}ms)...");
      final uuid = _randomUuid();
      final sessionUuid = _randomUuid();
      final url =
          "https://amp.shazam.com/discovery/v5/en-US/US/android/-/tag/$uuid/$sessionUuid?sync=true&webv3=true&sampling=true&shazamapiversion=v3";

      final response = await _dio.post(
        url,
        options: Options(headers: {
          'Content-Type': 'application/json',
          'User-Agent':
              'com.shazam.android/13.25.0-230413 (Android; SDK 33;)',
        }),
        data: jsonEncode({
          'signature': {
            'uri': signature,
            'samplems': sampleDurationMs,
          }
        }),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data as Map;

        if (data['track'] != null) {
          final track = data['track'] as Map;
          final title = track['title']?.toString() ?? '';
          final artist = track['subtitle']?.toString() ?? '';
          final images = track['images'] as Map?;
          final cover = images?['coverarthq']?.toString() ??
              images?['coverart']?.toString();

          if (title.isNotEmpty) {
            printINFO("[SongRecognizer] Shazam Match: '$title' by '$artist'");
            onProgress?.call("resolving");

            final mediaItem = await _resolvePlayableTrack(
              title,
              artist,
              artworkUrl: cover,
            );

            return RecognizedSong(
              title: title,
              artist: artist.isNotEmpty ? artist : 'Unknown Artist',
              album: track['sections'] != null ? _extractShazamAlbum(track) : null,
              artworkUrl: cover,
              confidence: 0.98,
              mediaItem: mediaItem,
              source: 'Shazam Acoustic Radar',
            );
          }
        }
      }

      printINFO("[SongRecognizer] Shazam returned no match for audio sample.");
      return null;
    } catch (e) {
      printERROR("[SongRecognizer] Acoustic recognition error: $e");
      rethrow;
    } finally {
      _isRecording = false;
      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}
    }
  }

  /// Cancels active recording if any
  Future<void> cancelRecording() async {
    _isRecording = false;
    try {
      if (_recorder != null && await _recorder!.isRecording()) {
        await _recorder!.stop();
      }
    } catch (_) {}
  }

  static String? _extractShazamAlbum(Map track) {
    try {
      final sections = track['sections'] as List?;
      if (sections != null) {
        for (final sec in sections) {
          if (sec is Map && sec['type'] == 'SONG') {
            final metadata = sec['metadata'] as List?;
            if (metadata != null) {
              for (final meta in metadata) {
                if (meta is Map && meta['title']?.toString().toLowerCase() == 'album') {
                  return meta['text']?.toString();
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Comprehensive multi-source song search (lyrics, humming, song title, artist phrase)
  /// Queries iTunes (world-standard database & lyric search), Deezer, and YouTube Music.
  Future<List<RecognizedSong>> searchCandidates(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final List<RecognizedSong> results = [];
    final Set<String> seenKeys = {};

    printINFO("[SongRecognizer] Multi-source candidate search for: '$clean'");

    // 1. iTunes Search API (fastest, unmatched lyric & title catalog accuracy)
    try {
      final itunesUrl =
          "https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=8";
      final res = await _dio.get(itunesUrl);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        final list = data['results'] as List?;
        if (list != null) {
          for (final item in list) {
            if (item is Map) {
              final trackName = item['trackName']?.toString() ?? '';
              final artistName = item['artistName']?.toString() ?? '';
              final albumName = item['collectionName']?.toString();
              var artwork = item['artworkUrl100']?.toString();
              if (artwork != null) {
                artwork = artwork.replaceAll('100x100bb', '600x600bb');
              }
              final key = '${trackName.toLowerCase()}_${artistName.toLowerCase()}';
              if (trackName.isNotEmpty && !seenKeys.contains(key)) {
                seenKeys.add(key);
                results.add(RecognizedSong(
                  title: trackName,
                  artist: artistName,
                  album: albumName,
                  artworkUrl: artwork,
                  confidence: results.isEmpty ? 0.95 : 0.88,
                  source: 'iTunes Global Catalog',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      printINFO("[SongRecognizer] iTunes search error: $e");
    }

    // 2. Deezer Global API (high quality covers & European/global catalog)
    try {
      final deezerUrl =
          "https://api.deezer.com/search?q=${Uri.encodeComponent(clean)}&limit=8";
      final res = await _dio.get(deezerUrl);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        final list = data['data'] as List?;
        if (list != null) {
          for (final item in list) {
            if (item is Map) {
              final title = item['title']?.toString() ?? '';
              final artist = item['artist']?['name']?.toString() ?? '';
              final album = item['album']?['title']?.toString();
              final cover = item['album']?['cover_big']?.toString() ??
                  item['album']?['cover_medium']?.toString();
              final key = '${title.toLowerCase()}_${artist.toLowerCase()}';
              if (title.isNotEmpty && !seenKeys.contains(key)) {
                seenKeys.add(key);
                results.add(RecognizedSong(
                  title: title,
                  artist: artist,
                  album: album,
                  artworkUrl: cover,
                  confidence: results.isEmpty ? 0.94 : 0.85,
                  source: 'Deezer Catalog',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      printINFO("[SongRecognizer] Deezer search error: $e");
    }

    // 3. YouTube Music Songs (for deep underground / remixes / direct video IDs)
    try {
      if (Get.isRegistered<MusicServices>()) {
        final musicServices = Get.find<MusicServices>();
        final ytRes = await musicServices.search(clean, filter: 'songs', limit: 8);
        final ytSongs = (ytRes['Songs'] as List?) ?? (ytRes['mixed'] as List?) ?? [];
        for (final item in ytSongs) {
          if (item is MediaItem) {
            final key = '${item.title.toLowerCase()}_${(item.artist ?? '').toLowerCase()}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              results.add(RecognizedSong(
                title: item.title,
                artist: item.artist ?? 'SPY Artist',
                album: item.album,
                artworkUrl: item.artUri?.toString(),
                confidence: results.isEmpty ? 0.92 : 0.82,
                mediaItem: item,
                source: 'YouTube Music',
              ));
            }
          }
        }
      }
    } catch (e) {
      printINFO("[SongRecognizer] YouTube Music candidate search error: $e");
    }

    return results;
  }

  /// Recognize a song from heard lyrics, spoken phrase, or humming query.
  /// Resolves the best candidate to a playable MediaItem.
  Future<RecognizedSong?> identifyByQuery(String query) async {
    final candidates = await searchCandidates(query);
    if (candidates.isEmpty) return null;

    final top = candidates.first;
    if (top.mediaItem != null) return top;

    // Resolve top candidate to playable stream
    final resolvedItem = await _resolvePlayableTrack(
      top.title,
      top.artist,
      artworkUrl: top.artworkUrl,
    );

    return RecognizedSong(
      title: top.title,
      artist: top.artist,
      album: top.album,
      artworkUrl: top.artworkUrl,
      confidence: top.confidence,
      mediaItem: resolvedItem,
      source: top.source,
    );
  }

  /// Resolves a recognized title and artist to a playable MediaItem in the app
  Future<MediaItem?> _resolvePlayableTrack(
    String title,
    String artist, {
    String? artworkUrl,
  }) async {
    try {
      final query = '$title $artist';

      // 1. Check YouTube Music
      if (Get.isRegistered<MusicServices>()) {
        final musicServices = Get.find<MusicServices>();
        final ytRes = await musicServices.search(query, filter: 'songs', limit: 5);
        final ytSongs = (ytRes['Songs'] as List?) ?? (ytRes['mixed'] as List?) ?? [];
        final match = ytSongs.whereType<MediaItem>().firstOrNull;
        if (match != null) {
          return match;
        }
      }

      // 2. Fallback to Spotify/Deezer resolver via PlatformSearchService
      final spMatches = await PlatformSearchService.searchSpotify(query, limit: 3);
      if (spMatches.isNotEmpty) {
        final first = spMatches.first;
        final resolved = await PlatformSearchService.resolveMatchedTrack(
          first.id,
          first.extras?['searchQuery'] ?? query,
          originalTrack: first,
        );
        if (resolved != null) return resolved;
        return first;
      }
    } catch (e) {
      printERROR("[SongRecognizer] Error resolving playable track: $e");
    }

    // Fallback: Return standard MediaItem with artUri
    return MediaItem(
      id: "shazam_${title.hashCode}_${artist.hashCode}",
      title: title,
      artist: artist,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : null,
    );
  }

  static String _randomUuid() {
    final rng = Random();
    String hex(int len) =>
        List.generate(len, (_) => rng.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  @override
  void onClose() {
    _recorder?.dispose();
    super.onClose();
  }
}
