import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../ui/screens/Library/library_controller.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/widgets/snackbar.dart';
import 'music_service.dart';

class PlaylistImportService {
  static final PlaylistImportService _instance = PlaylistImportService._internal();
  static PlaylistImportService get instance => _instance;
  factory PlaylistImportService() => _instance;
  PlaylistImportService._internal();

  final Dio _dio = Dio();

  bool get _isGerman {
    try {
      if (Get.isRegistered<SettingsScreenController>()) {
        final settings = Get.find<SettingsScreenController>();
        if (settings.currentAppLanguageCode.value == 'de') return true;
        if (settings.currentAppLanguageCode.value != 'de') return false;
      }
    } catch (_) {}
    return (Get.locale?.languageCode ?? 'en') == 'de';
  }

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
      _showFeedback(_isGerman
          ? 'Ein Import läuft bereits im Hintergrund.'
          : 'An import is already running in background.');
      return;
    }

    _showFeedback(_isGerman
        ? 'Playlist-Import im Hintergrund gestartet...'
        : 'Playlist import started in background...');

    try {
      final res = await importFromUrl(cleanUrl);
      final msg = res['message']?.toString() ??
          (_isGerman ? 'Import abgeschlossen' : 'Import finished');
      _showFeedback(msg);
    } catch (e) {
      _showFeedback(
          _isGerman ? 'Fehler beim Import: $e' : 'Error importing playlist: $e');
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

  /// Import a playlist from a URL, short share link, or shared text
  Future<Map<String, dynamic>> importFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return {
        'success': false,
        'message': _isGerman ? 'Leere Eingabe' : 'Empty input'
      };
    }

    // 1. Direct raw JSON pasted in the input field
    if (cleanUrl.startsWith('{') && cleanUrl.contains('"songs"')) {
      isImporting.value = true;
      importProgress.value = 0.0;
      currentTrack.value = 0;
      totalTracks.value = 0;
      importStatus.value =
          _isGerman ? "Initialisiere Import..." : "Initializing import...";
      try {
        final data = jsonDecode(cleanUrl);
        if (data is Map<String, dynamic>) {
          return await _importFromSpyMusicJsonData(data);
        } else if (data is Map) {
          return await _importFromSpyMusicJsonData(
              Map<String, dynamic>.from(data));
        }
      } catch (e) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Ungültiges JSON-Format: $e'
              : 'Invalid JSON format: $e'
        };
      } finally {
        _resetProgress();
      }
    }

    // 2. Extract URL if user copied full shared message (e.g. title + url)
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(cleanUrl);
    String targetUrl = urlMatch != null ? urlMatch.group(0)! : cleanUrl;
    targetUrl = targetUrl.replaceAll(RegExp(r'''[/\.,;\)\]>"']+$'''), '');
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      return {
        'success': false,
        'message': _isGerman ? 'Ungültige URL' : 'Invalid URL'
      };
    }

    isImporting.value = true;
    importProgress.value = 0.0;
    currentTrack.value = 0;
    totalTracks.value = 0;
    currentPlaylistTitle.value = "";
    importStatus.value =
        _isGerman ? "Initialisiere Import..." : "Initializing import...";

    try {
      // 3. SPY MUSIC Cloud Share Link (dpaste.org, direct raw JSON, or spymusic file)
      if (targetUrl.contains('dpaste.org') ||
          targetUrl.contains('paste.c-net.org') ||
          targetUrl.endsWith('.json') ||
          targetUrl.endsWith('.spymusic')) {
        return await _importFromSpyMusicShare(targetUrl);
      }

      // 4. Spotify Playlist Link
      if (targetUrl.contains('spotify.com/playlist/') ||
          targetUrl.contains('spotify.link')) {
        return await _importSpotify(targetUrl);
      }

      // 5. YouTube / YouTube Music Playlist Link
      if (targetUrl.contains('list=') ||
          targetUrl.contains('youtube.com') ||
          targetUrl.contains('youtu.be')) {
        return await _importYouTube(uri);
      }

      // 6. Generic link fallback: attempt to fetch as SPY MUSIC share
      return await _importFromSpyMusicShare(targetUrl);
    } finally {
      _resetProgress();
    }
  }

  void _resetProgress() {
    isImporting.value = false;
    importProgress.value = 0.0;
    currentTrack.value = 0;
    totalTracks.value = 0;
    importStatus.value = "";
  }

  Future<String?> _fetchSpotifyTrackCover(String trackId) async {
    if (trackId.isEmpty) return null;
    try {
      final oembedUrl =
          'https://open.spotify.com/oembed?url=https://open.spotify.com/track/$trackId';
      final resp = await _dio.get(
        oembedUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data is Map
            ? resp.data as Map
            : jsonDecode(resp.data.toString());
        final thumb = data['thumbnail_url']?.toString();
        if (thumb != null && thumb.isNotEmpty) {
          return thumb;
        }
      }
    } catch (_) {}
    return null;
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
        return {
          'success': false,
          'message': _isGerman
              ? 'Keine gültige Spotify Playlist-ID gefunden.'
              : 'No valid Spotify playlist ID found.'
        };
      }

      importStatus.value = _isGerman
          ? "Lade Spotify Metadaten..."
          : "Loading Spotify metadata...";

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
        return {
          'success': false,
          'message': _isGerman
              ? 'Spotify Playlist konnte nicht gelesen werden (privat oder ungültig).'
              : 'Spotify playlist could not be loaded (private or invalid).'
        };
      }

      final jsonData = jsonDecode(nextDataMatch.group(1)!);
      final entity = jsonData['props']?['pageProps']?['state']?['data']?['entity'];
      if (entity == null) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Keine Trackdaten in Spotify Playlist gefunden.'
              : 'No track data found in Spotify playlist.'
        };
      }

      final title = (entity['name'] ??
              entity['title'] ??
              (_isGerman
                  ? 'Importierte Spotify Playlist'
                  : 'Imported Spotify Playlist'))
          .toString();
      final trackList = entity['trackList'] as List? ?? [];
      if (trackList.isEmpty) {
        return {
          'success': false,
          'message':
              _isGerman ? 'Spotify Playlist ist leer.' : 'Spotify playlist is empty.'
        };
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

      // 3. Process each track strictly as 1:1 Spotify track with individual official cover art
      final List<MediaItem> items = [];
      const int batchSize = 4;

      for (int i = 0; i < trackList.length; i += batchSize) {
        final end = (i + batchSize < trackList.length) ? i + batchSize : trackList.length;
        final batch = trackList.sublist(i, end);

        // Fetch official covers concurrently for this batch to ensure fast import with 100% accurate artwork
        final covers = await Future.wait(batch.map((t) {
          final uri = t['uri']?.toString() ?? '';
          final trackId = uri.contains(':') ? uri.split(':').last : uri;
          return _fetchSpotifyTrackCover(trackId);
        }));

        for (int j = 0; j < batch.length; j++) {
          final t = batch[j];
          final trackCover = covers[j];
          final trackName =
              (t['title'] ?? (_isGerman ? 'Unbekannt' : 'Unknown'))
                  .toString()
                  .trim();
          final rawArtist = (t['subtitle'] ?? '').toString().trim();
          final trackArtist = rawArtist.isNotEmpty ? rawArtist : 'Spotify Artist';
          final durationMs = (t['duration'] is int)
              ? t['duration'] as int
              : (int.tryParse(t['duration']?.toString() ?? '180000') ?? 180000);
          final uri = t['uri']?.toString() ?? 'spotify:track:${items.length}';
          final trackId = uri.contains(':') ? uri.split(':').last : uri;
          final previewUrl = t['audioPreview']?['url']?.toString();

          final finalCover = trackCover ?? coverArtUrl ?? Playlist.thumbPlaceholderUrl;

          final targetItem = MediaItem(
            id: 'sp_$trackId',
            title: trackName,
            artist: trackArtist,
            album: title,
            duration: Duration(milliseconds: durationMs),
            artUri: Uri.tryParse(finalCover),
            extras: {
              'searchQuery': '$trackName $trackArtist',
              'artist': trackArtist,
              'artists': [
                {'name': trackArtist, 'id': ''}
              ],
              'isSpotify': true,
              'platform': 'Spotify',
              'spotifyUri': uri,
              'audioPreviewUrl': previewUrl,
              'duration': durationMs ~/ 1000,
              'length':
                  "${(durationMs ~/ 1000) ~/ 60}:${((durationMs ~/ 1000) % 60).toString().padLeft(2, '0')}",
              'thumbnails': [
                {'url': finalCover}
              ],
              'artworkUrl': finalCover,
            },
          );

          items.add(targetItem);
          currentTrack.value = items.length;
          importProgress.value = items.length / trackList.length;
          importStatus.value = _isGerman
              ? 'Importiere "$trackName" ($trackArtist) (${items.length}/${trackList.length})'
              : 'Importing "$trackName" ($trackArtist) (${items.length}/${trackList.length})';
        }

        // Slight deliberate pacing for UI responsiveness
        await Future.delayed(const Duration(milliseconds: 30));
      }

      // 4. Save to local library
      await _savePlaylistToLibrary(title, items);
      return {
        'success': true,
        'message': _isGerman
            ? 'Spotify Playlist "$title" (${items.length} Songs) erfolgreich importiert!'
            : 'Spotify playlist "$title" (${items.length} songs) successfully imported!',
        'count': items.length
      };
    } catch (e) {
      return {
        'success': false,
        'message': _isGerman
            ? 'Fehler beim Spotify-Import: $e'
            : 'Error during Spotify import: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _importYouTube(Uri uri) async {
    try {
      final listId = uri.queryParameters['list'];
      if (listId == null) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Keine YouTube Playlist-ID gefunden.'
              : 'No YouTube playlist ID found.'
        };
      }

      importStatus.value = _isGerman
          ? "Lade YouTube Playlist..."
          : "Loading YouTube playlist...";
      final musicServices = Get.find<MusicServices>();
      final result = await musicServices.getPlaylistOrAlbumSongs(
          playlistId: listId, limit: 10000);
      final title = result['title'] ??
          (_isGerman
              ? 'Importierte YouTube Playlist'
              : 'Imported YouTube Playlist');
      final List<MediaItem> rawItems =
          List<MediaItem>.from(result['tracks'] ?? []);

      if (rawItems.isEmpty) {
        return {
          'success': false,
          'message': _isGerman
              ? 'YouTube Playlist enthielt keine Titel oder konnte nicht geladen werden.'
              : 'YouTube playlist contains no tracks or could not be loaded.'
        };
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
        if (i % 20 == 0 || i == rawItems.length - 1) {
          importStatus.value = _isGerman
              ? 'Importiere "${item.title}" (${i + 1}/${rawItems.length})'
              : 'Importing "${item.title}" (${i + 1}/${rawItems.length})';
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }

      await _savePlaylistToLibrary(title, items);
      return {
        'success': true,
        'message': _isGerman
            ? 'YouTube Playlist "$title" (${items.length} Songs) erfolgreich importiert!'
            : 'YouTube playlist "$title" (${items.length} songs) successfully imported!',
        'count': items.length
      };
    } catch (e) {
      return {
        'success': false,
        'message': _isGerman
            ? 'Fehler beim YouTube-Import: $e'
            : 'Error during YouTube import: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _importFromSpyMusicShare(String url) async {
    try {
      importStatus.value = _isGerman
          ? "Lade Playlist-Daten herunter..."
          : "Downloading playlist data...";
      final clean = url.trim().replaceAll(RegExp(r'''[/\.,;\)\]>"']+$'''), '');
      final rawUrl = clean.contains('dpaste.org') && !clean.endsWith('/raw')
          ? '$clean/raw'
          : clean;

      final response = await _dio.get(
        rawUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/plain, application/json, */*',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Konnte Playlist nicht vom Share-Link laden (HTTP ${response.statusCode}).'
              : 'Could not load playlist from share link (HTTP ${response.statusCode}).'
        };
      }

      dynamic rawData;
      if (response.data is Map) {
        rawData = response.data;
      } else if (response.data is String) {
        final text = (response.data as String).trim();
        try {
          rawData = jsonDecode(text);
        } catch (_) {
          final firstBrace = text.indexOf('{');
          final lastBrace = text.lastIndexOf('}');
          if (firstBrace != -1 && lastBrace > firstBrace) {
            final jsonSub = text.substring(firstBrace, lastBrace + 1);
            rawData = jsonDecode(jsonSub);
          }
        }
      }

      if (rawData == null || rawData is! Map) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Ungültiges Playlist-Format.'
              : 'Invalid playlist format.'
        };
      }

      return await _importFromSpyMusicJsonData(
          Map<String, dynamic>.from(rawData));
    } catch (e) {
      return {
        'success': false,
        'message': _isGerman
            ? 'Fehler beim Laden des Share-Links: $e'
            : 'Error loading share link: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _importFromSpyMusicJsonData(
      Map<String, dynamic> data) async {
    try {
      final playlistInfo =
          data['playlistInfo'] is Map ? data['playlistInfo'] as Map : {};
      final title = (playlistInfo['title']?.toString() ??
              data['title']?.toString() ??
              (_isGerman ? 'Geteilte Playlist' : 'Shared Playlist'))
          .trim();
      final rawSongs = data['songs'] is List ? data['songs'] as List : [];

      if (rawSongs.isEmpty) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Die geteilte Playlist enthält keine Songs.'
              : 'The shared playlist contains no songs.'
        };
      }

      currentPlaylistTitle.value = title;
      totalTracks.value = rawSongs.length;
      currentTrack.value = 0;
      importProgress.value = 0.05;
      importStatus.value =
          '$title (${rawSongs.length} ${_isGerman ? "Songs" : "songs"})...';

      final List<MediaItem> items = [];
      for (int i = 0; i < rawSongs.length; i++) {
        final rawSong = rawSongs[i];
        try {
          final mediaItem = MediaItemBuilder.fromJson(rawSong);
          if (mediaItem.id.isNotEmpty && mediaItem.title.isNotEmpty) {
            items.add(mediaItem);
          }
        } catch (_) {}

        currentTrack.value = i + 1;
        importProgress.value = 0.1 + (0.85 * (i + 1) / rawSongs.length);
        if (i % 30 == 0 || i == rawSongs.length - 1) {
          importStatus.value = _isGerman
              ? 'Importiere ${i + 1}/${rawSongs.length} Songs...'
              : 'Importing ${i + 1}/${rawSongs.length} songs...';
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }

      if (items.isEmpty) {
        return {
          'success': false,
          'message': _isGerman
              ? 'Keine gültigen Songs in der Playlist gefunden.'
              : 'No valid songs found in playlist.'
        };
      }

      importStatus.value = _isGerman
          ? 'Speichere Playlist in Bibliothek...'
          : 'Saving playlist to library...';
      final thumb = playlistInfo['thumbnailUrl']?.toString() ??
          (items.isNotEmpty && items.first.artUri != null
              ? items.first.artUri.toString()
              : null) ??
          Playlist.thumbPlaceholderUrl;

      await _savePlaylistToLibrary(
        title,
        items,
        customThumbnail: thumb,
        description: _isGerman
            ? 'Geteilt via SPY MUSIC (${items.length} Songs)'
            : 'Shared via SPY MUSIC (${items.length} songs)',
      );

      importProgress.value = 1.0;
      return {
        'success': true,
        'message': _isGerman
            ? 'Playlist "$title" (${items.length} Songs) erfolgreich importiert!'
            : 'Playlist "$title" (${items.length} songs) successfully imported!',
        'count': items.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': _isGerman
            ? 'Fehler beim Importieren der Playlist: $e'
            : 'Error importing playlist: $e'
      };
    }
  }

  Future<bool> _savePlaylistToLibrary(String title, List<MediaItem> songItems,
      {String? customThumbnail, String? description}) async {
    final newPlaylist = Playlist(
      title: title,
      playlistId: 'LIB${DateTime.now().millisecondsSinceEpoch}',
      thumbnailUrl: customThumbnail ??
          (songItems.isNotEmpty && songItems.first.artUri != null
              ? songItems.first.artUri.toString()
              : Playlist.thumbPlaceholderUrl),
      description: description ??
          (_isGerman ? 'Importiert via SPY MUSIC' : 'Imported via SPY MUSIC'),
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
