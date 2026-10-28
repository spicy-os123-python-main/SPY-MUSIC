import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../ui/screens/Library/library_controller.dart';
import '../ui/widgets/snackbar.dart';
import 'music_service.dart';

class PlaylistImportService {
  static final PlaylistImportService _instance = PlaylistImportService._internal();
  static PlaylistImportService get instance => _instance;
  factory PlaylistImportService() => _instance;
  PlaylistImportService._internal();

  final Dio _dio = Dio();

  // Observable progress tracking for real-time cyber indicator in library top bar
  final RxBool isImporting = false.obs;
  final RxDouble importProgress = 0.0.obs;
  final RxInt currentTrack = 0.obs;
  final RxInt totalTracks = 0.obs;
  final RxString currentPlaylistTitle = "".obs;
  final RxString importStatus = "".obs;

  /// Starts a background import immediately, allowing the UI dialog to close instantly
  Future<void> startBackgroundImport(String url, {BuildContext? context}) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    if (isImporting.value) {
      _showFeedback('Ein Import läuft bereits im Hintergrund.');
      return;
    }

    _showFeedback('Playlist-Import im Hintergrund gestartet...');

    try {
      final res = await importFromUrl(cleanUrl);
      final msg = res['message']?.toString() ?? 'Import abgeschlossen';
      _showFeedback(msg);
    } catch (e) {
      _showFeedback('Fehler beim Import: $e');
    }
  }

  void _showFeedback(String msg) {
    try {
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          snackbar(Get.context!, msg, size: SanckBarSize.BIG),
        );
      } else {
        Get.rawSnackbar(
          message: msg,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF141828),
        );
      }
    } catch (_) {
      try {
        Get.rawSnackbar(
          message: msg,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF141828),
        );
      } catch (_) {}
    }
  }

  /// Import a playlist from a URL (Spotify, YouTube, etc.)
  Future<Map<String, dynamic>> importFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return {'success': false, 'message': 'Ungültige URL'};
    }

    isImporting.value = true;
    importProgress.value = 0.0;
    currentTrack.value = 0;
    totalTracks.value = 0;
    currentPlaylistTitle.value = "";
    importStatus.value = "Initialisiere Import...";

    try {
      // 1. Spotify Playlist Link
      if (url.contains('spotify.com/playlist/') || url.contains('spotify.link')) {
        return await _importSpotify(url);
      }

      // 2. YouTube / YouTube Music Playlist Link
      if (url.contains('list=') || url.contains('youtube.com') || url.contains('youtu.be')) {
        return await _importYouTube(uri);
      }

      return {
        'success': false,
        'message': 'Nicht unterstützter Link. Bitte Spotify- oder YouTube-Playlist-Link eingeben.'
      };
    } finally {
      isImporting.value = false;
      importProgress.value = 0.0;
      currentTrack.value = 0;
      totalTracks.value = 0;
      importStatus.value = "";
    }
  }

  Future<Map<String, dynamic>> _importSpotify(String url) async {
    try {
      // 1. Extract playlist ID (supporting direct links, shortened spotify.link, and URIs)
      String playlistId = '';
      if (url.contains('spotify.link')) {
        try {
          final redirectResp = await _dio.get(
            url,
            options: Options(
              followRedirects: true,
              maxRedirects: 5,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            ),
          );
          final real = redirectResp.realUri.toString();
          final reg = RegExp(r'playlist/([a-zA-Z0-9]+)');
          final match = reg.firstMatch(real);
          if (match != null) playlistId = match.group(1)!;
        } catch (_) {}
      }
      if (playlistId.isEmpty) {
        final reg = RegExp(r'playlist[/:]+([a-zA-Z0-9]+)');
        final match = reg.firstMatch(url);
        if (match != null) {
          playlistId = match.group(1)!;
        }
      }
      if (playlistId.isEmpty) {
        return {'success': false, 'message': 'Keine gültige Spotify Playlist-ID gefunden.'};
      }

      importStatus.value = "Lade Spotify Metadaten...";

      // 2. Fetch embed page HTML
      final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';
      final response = await _dio.get(
        embedUrl,
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }),
      );

      final html = response.data.toString();
      final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>').firstMatch(html);
      if (nextDataMatch == null) {
        return {'success': false, 'message': 'Spotify Playlist konnte nicht gelesen werden (privat oder ungültig).'};
      }

      final jsonData = jsonDecode(nextDataMatch.group(1)!);
      final entity = jsonData['props']?['pageProps']?['state']?['data']?['entity'];
      if (entity == null) {
        return {'success': false, 'message': 'Keine Trackdaten in Spotify Playlist gefunden.'};
      }

      final title = (entity['name'] ?? entity['title'] ?? 'Importierte Spotify Playlist').toString();
      final trackList = entity['trackList'] as List? ?? [];
      if (trackList.isEmpty) {
        return {'success': false, 'message': 'Spotify Playlist ist leer.'};
      }

      currentPlaylistTitle.value = title;
      totalTracks.value = trackList.length;
      currentTrack.value = 0;
      importProgress.value = 0.0;

      String? coverArtUrl;
      try {
        final sources = entity['coverArt']?['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          coverArtUrl = sources[0]['url']?.toString();
        }
      } catch (_) {}

      // 3. Process each track strictly as 1:1 Spotify track (NO YouTube search/replacement during import!)
      final List<MediaItem> items = [];

      for (int i = 0; i < trackList.length; i++) {
        final t = trackList[i];
        final trackName = (t['title'] ?? 'Unbekannt').toString().trim();
        final trackArtist = (t['subtitle'] ?? '').toString().trim();
        final durationMs = (t['duration'] is int)
            ? t['duration'] as int
            : (int.tryParse(t['duration']?.toString() ?? '180000') ?? 180000);
        final uri = t['uri']?.toString() ?? 'spotify:track:${items.length}';
        final trackId = uri.contains(':') ? uri.split(':').last : uri;
        final previewUrl = t['audioPreview']?['url']?.toString();

        final targetItem = MediaItem(
          id: 'sp_$trackId',
          title: trackName,
          artist: trackArtist.isNotEmpty ? trackArtist : 'Spotify Artist',
          album: title,
          duration: Duration(milliseconds: durationMs),
          artUri: coverArtUrl != null
              ? Uri.tryParse(coverArtUrl)
              : Uri.tryParse(Playlist.thumbPlaceholderUrl),
          extras: {
            'searchQuery': '$trackName $trackArtist',
            'isSpotify': true,
            'platform': 'Spotify',
            'spotifyUri': uri,
            'audioPreviewUrl': previewUrl,
            'duration': durationMs ~/ 1000,
            'length':
                "${(durationMs ~/ 1000) ~/ 60}:${((durationMs ~/ 1000) % 60).toString().padLeft(2, '0')}",
          },
        );

        items.add(targetItem);
        currentTrack.value = i + 1;
        importProgress.value = (i + 1) / trackList.length;
        importStatus.value = 'Importiere "$trackName" (${i + 1}/${trackList.length})';

        // Deliberate clean pacing: guarantees visual progress and avoids database locking
        await Future.delayed(const Duration(milliseconds: 35));
      }

      // 4. Save to local library
      await _savePlaylistToLibrary(title, items);
      return {
        'success': true,
        'message': 'Spotify Playlist "$title" (${items.length} Songs) erfolgreich importiert!',
        'count': items.length
      };
    } catch (e) {
      return {'success': false, 'message': 'Fehler beim Spotify-Import: $e'};
    }
  }

  Future<Map<String, dynamic>> _importYouTube(Uri uri) async {
    try {
      final listId = uri.queryParameters['list'];
      if (listId == null) {
        return {'success': false, 'message': 'Keine YouTube Playlist-ID gefunden.'};
      }

      importStatus.value = "Lade YouTube Playlist...";
      final musicServices = Get.find<MusicServices>();
      final result = await musicServices.getPlaylistOrAlbumSongs(playlistId: listId);
      final title = result['title'] ?? 'Importierte YouTube Playlist';
      final List<MediaItem> rawItems = List<MediaItem>.from(result['tracks'] ?? []);

      if (rawItems.isEmpty) {
        return {'success': false, 'message': 'YouTube Playlist enthielt keine Titel oder konnte nicht geladen werden.'};
      }

      currentPlaylistTitle.value = title;
      totalTracks.value = rawItems.length;
      currentTrack.value = 0;
      importProgress.value = 0.0;

      final List<MediaItem> items = [];
      for (int i = 0; i < rawItems.length; i++) {
        final item = rawItems[i];
        items.add(item);
        currentTrack.value = i + 1;
        importProgress.value = (i + 1) / rawItems.length;
        importStatus.value = 'Importiere "${item.title}" (${i + 1}/${rawItems.length})';
        await Future.delayed(const Duration(milliseconds: 30));
      }

      await _savePlaylistToLibrary(title, items);
      return {
        'success': true,
        'message': 'YouTube Playlist "$title" (${items.length} Songs) erfolgreich importiert!',
        'count': items.length
      };
    } catch (e) {
      return {'success': false, 'message': 'Fehler beim YouTube-Import: $e'};
    }
  }

  Future<bool> _savePlaylistToLibrary(String title, List<MediaItem> songItems) async {
    final newPlaylist = Playlist(
      title: title,
      playlistId: 'LIB${DateTime.now().millisecondsSinceEpoch}',
      thumbnailUrl: songItems.isNotEmpty
          ? songItems.first.artUri.toString()
          : Playlist.thumbPlaceholderUrl,
      description: 'Importiert via SPY MUSIC',
      isCloudPlaylist: false,
    );

    final box = await Hive.openBox('LibraryPlaylists');
    await box.put(newPlaylist.playlistId, newPlaylist.toJson());
    await box.close();

    final plastbox = await Hive.openBox(newPlaylist.playlistId);
    for (MediaItem item in songItems) {
      await plastbox.add(MediaItemBuilder.toJson(item));
    }
    await plastbox.close();

    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        Get.find<LibraryPlaylistsController>().refreshLib();
      }
    } catch (_) {}
    return true;
  }
}
