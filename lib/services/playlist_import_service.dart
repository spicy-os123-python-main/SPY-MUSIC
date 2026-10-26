import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../ui/screens/Library/library_controller.dart';
import 'music_service.dart';
import 'platform_search_service.dart';

class PlaylistImportService {
  static final PlaylistImportService _instance = PlaylistImportService._internal();
  factory PlaylistImportService() => _instance;
  PlaylistImportService._internal();

  final Dio _dio = Dio();

  /// Import a playlist from a URL (Spotify, YouTube, etc.)
  Future<Map<String, dynamic>> importFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return {'success': false, 'message': 'Ungültige URL'};
    }

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

      final title = entity['name'] ?? 'Importierte Spotify Playlist';
      final trackList = entity['trackList'] as List? ?? [];
      if (trackList.isEmpty) {
        return {'success': false, 'message': 'Spotify Playlist ist leer.'};
      }

      String? coverArtUrl;
      try {
        final sources = entity['coverArt']?['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          coverArtUrl = sources[0]['url']?.toString();
        }
      } catch (_) {}

      // 3. Convert all tracks to high-precision MediaItem objects
      final List<MediaItem> items = [];
      final musicServices = Get.find<MusicServices>();

      for (var t in trackList) {
        final trackName = (t['title'] ?? 'Unbekannt').toString().trim();
        final trackArtist = (t['subtitle'] ?? '').toString().trim();
        final durationMs = (t['duration'] is int)
            ? t['duration'] as int
            : (int.tryParse(t['duration']?.toString() ?? '180000') ?? 180000);
        final uri = t['uri']?.toString() ?? 'spotify:track:${items.length}';

        final targetItem = MediaItem(
          id: 'sp_${uri.replaceAll(':', '_')}',
          title: trackName,
          artist: trackArtist.isNotEmpty ? trackArtist : 'Spotify Artist',
          duration: Duration(milliseconds: durationMs),
          artUri: coverArtUrl != null
              ? Uri.tryParse(coverArtUrl)
              : Uri.tryParse(Playlist.thumbPlaceholderUrl),
          extras: {
            'searchQuery': '$trackName $trackArtist',
            'isSpotify': true,
            'platform': 'Spotify',
            'duration': durationMs ~/ 1000,
            'length':
                "${(durationMs ~/ 1000) ~/ 60}:${((durationMs ~/ 1000) % 60).toString().padLeft(2, '0')}",
          },
        );

        // High-precision studio match on YouTube Music (official releases at 1.0x speed)
        try {
          final res = await musicServices
              .search('$trackName $trackArtist', filter: 'songs', limit: 6)
              .timeout(const Duration(seconds: 4));
          final rawList = (res['Songs'] as List?) ?? (res['mixed'] as List?);
          final candidates = (rawList ?? const [])
              .whereType<MediaItem>()
              .where((e) => !e.id.startsWith('sp_') && !e.id.startsWith('az_'))
              .toList();
          final best = PlatformSearchService.findBestMatch(candidates, targetItem);
          if (best != null) {
            items.add(best);
            continue;
          }
        } catch (_) {}

        // Fallback: add targetItem with full metadata to resolve seamlessly on play
        items.add(targetItem);
      }

      // 4. Save to local library
      await _savePlaylistToLibrary(title, items);
      return {
        'success': true,
        'message': 'Spotify Playlist "$title" mit ${items.length} Songs erfolgreich importiert!',
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

      final musicServices = Get.find<MusicServices>();
      final result = await musicServices.getPlaylistOrAlbumSongs(playlistId: listId);
      final title = result['title'] ?? 'Importierte YouTube Playlist';
      final List<MediaItem> items = List<MediaItem>.from(result['tracks'] ?? []);

      if (items.isNotEmpty) {
        await _savePlaylistToLibrary(title, items);
        return {
          'success': true,
          'message': 'YouTube Playlist "$title" mit ${items.length} Songs erfolgreich importiert!',
          'count': items.length
        };
      }
      return {'success': false, 'message': 'YouTube Playlist enthielt keine Titel oder konnte nicht geladen werden.'};
    } catch (e) {
      return {'success': false, 'message': 'Fehler beim YouTube-Import: $e'};
    }
  }

  Future<bool> _savePlaylistToLibrary(String title, List<MediaItem> songItems) async {
    final libraryController = Get.find<LibraryPlaylistsController>();
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
    box.put(newPlaylist.playlistId, newPlaylist.toJson());
    await box.close();

    final plastbox = await Hive.openBox(newPlaylist.playlistId);
    for (MediaItem item in songItems) {
      plastbox.add(MediaItemBuilder.toJson(item));
    }
    await plastbox.close();

    libraryController.libraryPlaylists.add(newPlaylist);
    return true;
  }
}
