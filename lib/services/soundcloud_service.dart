import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import '../utils/helper.dart';

class SoundCloudService {
  static final SoundCloudService _instance = SoundCloudService._internal();
  factory SoundCloudService() => _instance;
  SoundCloudService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  static String _clientId = 'GytJkwrLebfCWmFfWOuDf7WObQo2BND9';
  static bool _isRefreshingClient = false;
  static DateTime? _lastRefresh;

  /// Cache of resolved stream URLs by scTrackId or url
  static final Map<String, String> _streamCache = {};

  /// Get active client ID (auto-refreshes if needed)
  Future<String> getClientId() async {
    if (_lastRefresh == null ||
        DateTime.now().difference(_lastRefresh!).inHours > 6) {
      refreshClientId();
    }
    return _clientId;
  }

  /// Dynamically scrape latest client_id from SoundCloud assets
  Future<void> refreshClientId() async {
    if (_isRefreshingClient) return;
    _isRefreshingClient = true;
    try {
      final res = await _dio.get('https://soundcloud.com');
      final html = res.data.toString();
      final scriptRegex = RegExp(r'<script[^>]+src="(https://[^"]+assets/[^"]+\.js)"');
      final matches = scriptRegex.allMatches(html).toList();

      for (var m in matches.reversed.take(4)) {
        final scriptUrl = m.group(1);
        if (scriptUrl == null) continue;
        try {
          final sRes = await _dio.get(scriptUrl);
          final idMatch = RegExp(r'client_id:"([a-zA-Z0-9]{32})"').firstMatch(sRes.data.toString());
          if (idMatch != null) {
            _clientId = idMatch.group(1)!;
            _lastRefresh = DateTime.now();
            printINFO("SoundCloud client_id refreshed: $_clientId");
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      printERROR("SoundCloud refreshClientId error: $e");
    } finally {
      _isRefreshingClient = false;
    }
  }

  /// Search tracks on SoundCloud
  Future<List<MediaItem>> searchTracks(String query, {int limit = 25}) async {
    try {
      final cid = await getClientId();
      final url =
          'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(query)}&client_id=$cid&limit=$limit';

      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final data = response.data;
      final collection = (data is Map && data['collection'] is List)
          ? data['collection'] as List
          : [];

      final List<MediaItem> items = [];

      for (var item in collection) {
        if (item is! Map) continue;
        final track = item;

        final id = track['id']?.toString();
        final title = track['title']?.toString();
        if (id == null || title == null || title.isEmpty) continue;

        final user = track['user'] as Map?;
        final artist = user?['username']?.toString() ?? 'SoundCloud';

        // High-res artwork fallback
        String? artwork = track['artwork_url']?.toString();
        if (artwork != null) {
          artwork = artwork.replaceAll('-large.', '-t500x500.');
        } else {
          artwork = user?['avatar_url']?.toString();
        }

        final durationMs = (track['duration'] is int)
            ? track['duration'] as int
            : ((track['full_duration'] is int) ? track['full_duration'] as int : 0);

        // Find best transcoding URL
        final media = track['media'] as Map?;
        final transcodings = (media != null && media['transcodings'] is List)
            ? media['transcodings'] as List
            : [];

        String? bestTranscodingUrl;

        // 1. Prefer unencrypted progressive or full stream HLS
        for (var t in transcodings) {
          if (t is! Map) continue;
          final tUrl = t['url']?.toString() ?? '';
          final format = t['format'] as Map?;
          final protocol = format?['protocol']?.toString() ?? '';

          if (tUrl.contains('/stream/progressive')) {
            bestTranscodingUrl = tUrl;
            break;
          }
          if (tUrl.contains('/stream/hls') && !protocol.contains('encrypted')) {
            bestTranscodingUrl = tUrl;
          }
        }

        // 2. Fallback to any stream or preview transcoding if no clean stream
        if (bestTranscodingUrl == null) {
          for (var t in transcodings) {
            if (t is! Map) continue;
            final tUrl = t['url']?.toString() ?? '';
            final format = t['format'] as Map?;
            final protocol = format?['protocol']?.toString() ?? '';
            if (!protocol.contains('encrypted') && tUrl.isNotEmpty) {
              bestTranscodingUrl = tUrl;
              break;
            }
          }
        }

        if (bestTranscodingUrl == null && transcodings.isNotEmpty) {
          bestTranscodingUrl = transcodings.first['url']?.toString();
        }

        if (bestTranscodingUrl == null) continue;

        items.add(MediaItem(
          id: 'sc_$id',
          title: title,
          artist: artist,
          album: 'SoundCloud',
          duration: Duration(milliseconds: durationMs),
          artUri: artwork != null ? Uri.tryParse(artwork) : null,
          extras: {
            'isSoundCloud': true,
            'scTrackId': id,
            'transcodingUrl': bestTranscodingUrl,
            'permalink': track['permalink_url']?.toString(),
            'platform': 'SoundCloud',
          },
        ));
      }

      return items;
    } catch (e) {
      printERROR("SoundCloud search error: $e");
      return [];
    }
  }

  /// Get trending SoundCloud tracks for Home Screen Quick Picks
  Future<List<MediaItem>> getTrendingTracks({int limit = 25}) async {
    final queries = [
      'trending rap',
      'viral tiktok hits',
      'popular edm remix',
      'underground trap'
    ];
    queries.shuffle();
    return await searchTracks(queries.first, limit: limit);
  }

  /// Resolve the direct audio playback stream URL
  static Future<String?> resolveStreamUrl(String songId,
      {String? transcodingUrl}) async {
    if (_streamCache.containsKey(songId)) {
      return _streamCache[songId];
    }

    try {
      final service = SoundCloudService();
      final cid = await service.getClientId();

      String? targetTranscoding = transcodingUrl;

      // If transcoding URL is not provided in extras, fetch track details
      if (targetTranscoding == null) {
        final scId = songId.startsWith('sc_') ? songId.substring(3) : songId;
        final trackInfoUrl =
            'https://api-v2.soundcloud.com/tracks/$scId?client_id=$cid';
        final trackRes = await service._dio.get(trackInfoUrl);
        if (trackRes.data != null && trackRes.data['media'] != null) {
          final transcodings = trackRes.data['media']['transcodings'] as List? ?? [];
          for (var t in transcodings) {
            final u = t['url']?.toString() ?? '';
            if (u.contains('/stream/hls') || u.contains('/stream/progressive')) {
              targetTranscoding = u;
              break;
            }
          }
          if (targetTranscoding == null && transcodings.isNotEmpty) {
            targetTranscoding = transcodings.first['url']?.toString();
          }
        }
      }

      if (targetTranscoding == null) return null;

      final delim = targetTranscoding.contains('?') ? '&' : '?';
      final resolveUrl = '$targetTranscoding${delim}client_id=$cid';

      final response = await service._dio.get(resolveUrl);
      if (response.statusCode == 200 && response.data != null) {
        final streamUrl = response.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          _streamCache[songId] = streamUrl;
          return streamUrl;
        }
      }
    } catch (e) {
      printERROR("SoundCloud resolveStreamUrl error: $e");
    }

    return null;
  }
}
