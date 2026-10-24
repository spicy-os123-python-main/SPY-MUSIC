import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../utils/helper.dart';

class _CachedStream {
  final String url;
  final DateTime expiresAt;
  _CachedStream(this.url, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

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

  /// Cache of resolved stream URLs with expiration
  static final Map<String, _CachedStream> _streamCache = {};

  /// Invalidate stream cache for a track (e.g. on playback error)
  static void invalidateStreamCache(String songId) {
    _streamCache.remove(songId);
    printINFO("Invalidated SoundCloud stream cache for: $songId");
  }

  /// Get active client ID (loads persisted Hive ID or falls back to default)
  Future<String> getClientId() async {
    try {
      final box = Hive.box('AppPrefs');
      final stored = box.get('soundcloud_client_id') as String?;
      if (stored != null && stored.isNotEmpty) {
        _clientId = stored;
      }
    } catch (_) {}
    return _clientId;
  }

  /// Dynamically scrape latest client_id from SoundCloud assets and persist to Hive
  Future<void> refreshClientId() async {
    if (_isRefreshingClient) return;
    _isRefreshingClient = true;
    try {
      printINFO("Refreshing SoundCloud client_id from soundcloud.com...");
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
            try {
              final box = Hive.box('AppPrefs');
              await box.put('soundcloud_client_id', _clientId);
            } catch (_) {}
            printINFO("SoundCloud client_id refreshed & saved to Hive: $_clientId");
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
  Future<List<MediaItem>> searchTracks(String query, {int limit = 25, bool isRetry = false}) async {
    try {
      final cid = await getClientId();
      final url =
          'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(query)}&client_id=$cid&limit=$limit';

      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) {
        printERROR("SoundCloud search returned HTTP ${response.statusCode} for query '$query'");
        return [];
      }

      final data = response.data;
      final collection = (data is Map && data['collection'] is List)
          ? data['collection'] as List
          : [];

      if (collection.isEmpty) {
        printINFO("SoundCloud search returned 0 items for: '$query'");
      }

      final List<MediaItem> items = [];

      for (var item in collection) {
        if (item is! Map) continue;
        final track = item;

        final id = track['id']?.toString();
        final title = track['title']?.toString();
        if (id == null || title == null || title.isEmpty) continue;

        final user = track['user'] as Map?;
        final artist = user?['username']?.toString() ?? 'SoundCloud';
        final trackAuth = track['track_authorization']?.toString();

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

        // Find best full unencrypted transcoding URL (strictly exclude previews and DRM)
        final media = track['media'] as Map?;
        final transcodings = (media != null && media['transcodings'] is List)
            ? media['transcodings'] as List
            : [];

        String? bestTranscodingUrl;

        for (var t in transcodings) {
          if (t is! Map) continue;
          final tUrl = t['url']?.toString() ?? '';
          final format = t['format'] as Map?;
          final protocol = format?['protocol']?.toString() ?? '';

          // Strictly skip preview and encrypted streams
          if (tUrl.contains('/preview') ||
              protocol.contains('preview') ||
              protocol.contains('encrypted')) {
            continue;
          }

          if (tUrl.contains('/stream/progressive')) {
            bestTranscodingUrl = tUrl;
            break;
          }
          if (tUrl.contains('/stream/hls')) {
            bestTranscodingUrl = tUrl;
          }
        }

        // Skip tracks with exclusively preview or encrypted streams
        if (bestTranscodingUrl == null) {
          continue;
        }

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
            'track_authorization': trackAuth,
            'permalink': track['permalink_url']?.toString(),
            'platform': 'SoundCloud',
          },
        ));
      }

      if (items.isEmpty && query.contains(" - ") && !isRetry) {
        final cleanQuery = query.replaceAll(" - ", " ").trim();
        return await searchTracks(cleanQuery, limit: limit, isRetry: true);
      }

      return items;
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final errBody = dioErr.response?.data?.toString();
      final trunc = errBody != null ? (errBody.length > 200 ? '${errBody.substring(0, 200)}...' : errBody) : 'none';
      printERROR("SoundCloud search failed [HTTP $status] for '$query': ${dioErr.message}, body: $trunc");

      if ((status == 401 || status == 403) && !isRetry) {
        printINFO("SoundCloud $status detected, refreshing client ID and retrying...");
        await refreshClientId();
        return await searchTracks(query, limit: limit, isRetry: true);
      }
      return [];
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
      {String? transcodingUrl, String? trackAuthorization, bool isRetry = false}) async {
    if (_streamCache.containsKey(songId)) {
      final cached = _streamCache[songId]!;
      if (!cached.isExpired) {
        return cached.url;
      }
      _streamCache.remove(songId);
    }

    try {
      final service = SoundCloudService();
      final cid = await service.getClientId();

      String? targetTranscoding = transcodingUrl;
      String? targetAuth = trackAuthorization;

      // If transcoding URL is not provided in extras, fetch track details
      if (targetTranscoding == null) {
        final scId = songId.startsWith('sc_') ? songId.substring(3) : songId;
        final trackInfoUrl =
            'https://api-v2.soundcloud.com/tracks/$scId?client_id=$cid';
        final trackRes = await service._dio.get(trackInfoUrl);
        if (trackRes.data != null) {
          targetAuth ??= trackRes.data['track_authorization']?.toString();
          if (trackRes.data['media'] != null) {
            final transcodings = trackRes.data['media']['transcodings'] as List? ?? [];
            for (var t in transcodings) {
              final u = t['url']?.toString() ?? '';
              final format = t['format'] as Map?;
              final protocol = format?['protocol']?.toString() ?? '';
              if (!protocol.contains('encrypted') &&
                  !protocol.contains('preview') &&
                  !u.contains('/preview') &&
                  (u.contains('/stream/progressive') || u.contains('/stream/hls'))) {
                targetTranscoding = u;
                break;
              }
            }
          }
        }
      }

      if (targetTranscoding == null) {
        printERROR("No valid unencrypted transcoding found for SoundCloud track: $songId");
        return null;
      }

      final delim = targetTranscoding.contains('?') ? '&' : '?';
      var resolveUrl = '$targetTranscoding${delim}client_id=$cid';
      if (targetAuth != null && targetAuth.isNotEmpty) {
        resolveUrl += '&track_authorization=$targetAuth';
      }

      final response = await service._dio.get(resolveUrl);
      if (response.statusCode == 200 && response.data != null) {
        final streamUrl = response.data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          // Cache stream URL with 10-minute expiration
          _streamCache[songId] = _CachedStream(
            streamUrl,
            DateTime.now().add(const Duration(minutes: 10)),
          );
          return streamUrl;
        }
      }
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final errBody = dioErr.response?.data?.toString();
      final trunc = errBody != null ? (errBody.length > 200 ? '${errBody.substring(0, 200)}...' : errBody) : 'none';
      printERROR("SoundCloud resolveStreamUrl failed [HTTP $status] for $songId: ${dioErr.message}, body: $trunc");

      if ((status == 401 || status == 403) && !isRetry) {
        printINFO("SoundCloud resolveStreamUrl $status, refreshing client ID...");
        await SoundCloudService().refreshClientId();
        return await resolveStreamUrl(songId,
            transcodingUrl: transcodingUrl,
            trackAuthorization: trackAuthorization,
            isRetry: true);
      }
    } catch (e) {
      printERROR("SoundCloud resolveStreamUrl error: $e");
    }

    return null;
  }
}
