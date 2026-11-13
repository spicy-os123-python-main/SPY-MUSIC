import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'platform_search_service.dart';
import 'music_service.dart';
import '../utils/helper.dart';

class RecognizedSong {
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final double confidence; // 0.0 to 1.0
  final MediaItem? mediaItem;

  const RecognizedSong({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    required this.confidence,
    this.mediaItem,
  });

  MediaItem toMediaItem() {
    if (mediaItem != null) return mediaItem!;
    return MediaItem(
      id: "rec_${title.hashCode}",
      title: title,
      artist: artist,
      album: album,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl!) : null,
    );
  }
}

class SongRecognizerService extends GetxService {
  static final SongRecognizerService _instance = SongRecognizerService._internal();
  factory SongRecognizerService() => _instance;
  SongRecognizerService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Recognize a song from heard lyrics, spoken phrase, or humming query
  Future<RecognizedSong?> identifyByQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    try {
      printINFO("[SongRecognizer] Identifying song for query: '$clean'...");

      // 1. First Tier: YouTube Music Songs Search (exact studio matching)
      final musicServices = Get.find<MusicServices>();
      final ytRes = await musicServices.search(clean, filter: 'songs', limit: 6);
      final ytSongs = (ytRes['Songs'] as List?) ?? (ytRes['mixed'] as List?) ?? [];

      if (ytSongs.isNotEmpty) {
        final first = ytSongs.whereType<MediaItem>().firstOrNull;
        if (first != null) {
          printINFO("[SongRecognizer] Match found via YouTube Music: '${first.title}' by '${first.artist}'");
          return RecognizedSong(
            title: first.title,
            artist: first.artist ?? 'SPY Artist',
            album: first.album,
            artworkUrl: first.artUri?.toString(),
            confidence: 0.96,
            mediaItem: first,
          );
        }
      }

      // 2. Second Tier: Deezer Global Catalog Search (high-accuracy global database)
      final spMatches = await PlatformSearchService.searchSpotify(clean, limit: 5);
      if (spMatches.isNotEmpty) {
        final first = spMatches.first;
        final resolved = await PlatformSearchService.resolveMatchedTrack(
          first.id,
          first.extras?['searchQuery'] ?? '${first.title} ${first.artist}',
          originalTrack: first,
        );
        printINFO("[SongRecognizer] Match found via Catalog: '${first.title}' by '${first.artist}'");
        return RecognizedSong(
          title: first.title,
          artist: first.artist ?? 'SPY Artist',
          album: first.album,
          artworkUrl: first.artUri?.toString(),
          confidence: 0.94,
          mediaItem: resolved ?? first,
        );
      }
    } catch (e) {
      printERROR("[SongRecognizer] Identification error: $e");
    }
    return null;
  }

  /// Recognize audio stream snippet from AudD open endpoint
  Future<RecognizedSong?> identifyFromAudioUrl(String audioSampleUrl) async {
    try {
      final response = await _dio.post(
        "https://api.audd.io/",
        data: {
          'url': audioSampleUrl,
          'return': 'apple_music,spotify',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        if (data['status'] == 'success' && data['result'] != null) {
          final res = data['result'];
          final title = res['title']?.toString() ?? '';
          final artist = res['artist']?.toString() ?? '';
          if (title.isNotEmpty) {
            return await identifyByQuery("$title $artist");
          }
        }
      }
    } catch (e) {
      printINFO("[SongRecognizer] AudD API response: $e");
    }
    return null;
  }
}
