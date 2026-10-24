import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'music_service.dart';
import 'soundcloud_service.dart';
import '../utils/helper.dart';

class PlatformSearchService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// Cache of matched stream IDs for Spotify/Amazon tracks
  static final Map<String, String> _matchCache = {};

  /// Search specifically for Spotify tracks
  static Future<List<MediaItem>> searchSpotify(String query,
      {int limit = 25}) async {
    try {
      final url =
          'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=$limit';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List? ?? [];
        final List<MediaItem> items = [];

        for (var item in data) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ?? 'Unbekannt';
          final artist = item['artist']?['name']?.toString() ?? 'Spotify Artist';
          final album = item['album']?['title']?.toString() ?? 'Spotify Track';
          final cover = item['album']?['cover_big']?.toString() ??
              item['album']?['cover_medium']?.toString();
          final durationSec = (item['duration'] is int) ? item['duration'] as int : 180;

          items.add(MediaItem(
            id: 'sp_$id',
            title: title,
            artist: artist,
            album: album,
            duration: Duration(seconds: durationSec),
            artUri: cover != null ? Uri.tryParse(cover) : null,
            extras: {
              'platform': 'Spotify',
              'isSpotify': true,
              'searchQuery': '$title $artist',
              'originalId': id,
            },
          ));
        }

        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      printERROR("Spotify platform search error: $e");
    }

    // Fallback: query tagged Spotify tracks
    return await _queryFilteredEngine('Spotify $query', 'Spotify');
  }

  /// Search specifically for Amazon Music tracks
  static Future<List<MediaItem>> searchAmazon(String query,
      {int limit = 25}) async {
    try {
      final url =
          'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=$limit';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List? ?? [];
        final List<MediaItem> items = [];

        for (var item in data) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ?? 'Unbekannt';
          final artist = item['artist']?['name']?.toString() ?? 'Amazon Artist';
          final album = item['album']?['title']?.toString() ?? 'Amazon Music';
          final cover = item['album']?['cover_big']?.toString() ??
              item['album']?['cover_medium']?.toString();
          final durationSec = (item['duration'] is int) ? item['duration'] as int : 180;

          items.add(MediaItem(
            id: 'az_$id',
            title: title,
            artist: artist,
            album: album,
            duration: Duration(seconds: durationSec),
            artUri: cover != null ? Uri.tryParse(cover) : null,
            extras: {
              'platform': 'Amazon Music',
              'isAmazon': true,
              'searchQuery': '$title $artist',
              'originalId': id,
            },
          ));
        }

        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      printERROR("Amazon platform search error: $e");
    }

    return await _queryFilteredEngine('Amazon Music $query', 'Amazon Music');
  }

  /// Get current Spotify Top Hits for Home Screen
  static Future<List<MediaItem>> getSpotifyTopHits({int limit = 25}) async {
    return await searchSpotify('Spotify Top 50 Global', limit: limit);
  }

  /// Get current Amazon Music Top Tracks for Home Screen
  static Future<List<MediaItem>> getAmazonTopTracks({int limit = 25}) async {
    return await searchAmazon('Amazon Music Best Hits', limit: limit);
  }

  /// Fast fallback search
  static Future<List<MediaItem>> _queryFilteredEngine(
      String query, String platformName) async {
    try {
      final musicServices = Get.find<MusicServices>();
      final results = await musicServices.search(query, filter: 'songs', limit: 25);
      final rawList = (results['Songs'] as List?) ?? (results['mixed'] as List?);
      if (rawList != null && rawList.isNotEmpty) {
        return rawList.whereType<MediaItem>().map((item) {
          final extras = Map<String, dynamic>.from(item.extras ?? {});
          extras['platform'] = platformName;
          return item.copyWith(extras: extras);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Resolve audio stream for Spotify or Amazon track by matching track title & artist
  static Future<String?> resolveMatchedStreamId(
      String trackId, String searchQuery) async {
    if (_matchCache.containsKey(trackId)) {
      return _matchCache[trackId];
    }

    // 1. Resolve via SoundCloud first (independent CDN, no rate limits, doesn't touch YouTube)
    try {
      final cleanQuery = searchQuery
          .replaceAll(RegExp(r'\(feat\.[^)]*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[feat\.[^\]]*\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(official video\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[official video\]', caseSensitive: false), '')
          .trim();
      final q = cleanQuery.isNotEmpty ? cleanQuery : searchQuery;
      final scTracks = await SoundCloudService().searchTracks(q, limit: 3);
      if (scTracks.isNotEmpty) {
        final match = scTracks.first;
        _matchCache[trackId] = match.id;
        return match.id;
      }
    } catch (e) {
      printERROR("SoundCloud resolution failed for $trackId: $e");
    }

    // 2. Fallback to MusicServices (YouTube Music) if SoundCloud has no result
    try {
      final musicServices = Get.find<MusicServices>();
      final res =
          await musicServices.search(searchQuery, filter: 'songs', limit: 3);
      final rawList = (res['Songs'] as List?) ?? (res['mixed'] as List?);
      if (rawList != null && rawList.isNotEmpty) {
        final match = rawList.firstWhere(
            (e) => e is MediaItem && !e.id.startsWith('sp_') && !e.id.startsWith('az_'),
            orElse: () => null);
        if (match != null && match is MediaItem) {
          _matchCache[trackId] = match.id;
          return match.id;
        }
      }
    } catch (e) {
      printERROR("Match error for $trackId: $e");
    }

    return null;
  }
}

