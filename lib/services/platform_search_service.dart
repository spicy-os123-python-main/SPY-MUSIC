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

  /// Cache of full matched MediaItems for Spotify/Amazon tracks
  static final Map<String, MediaItem> _matchedItemCache = {};

  /// Invalidate match cache when playback fails or match was dead
  static void invalidateMatch(String trackId) {
    _matchCache.remove(trackId);
    _matchedItemCache.remove(trackId);
    printINFO("Invalidated match cache for: $trackId");
  }

  static MediaItem _mapDeezerTrack(Map item, String prefix, String platform) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Unbekannt';
    final artist = item['artist']?['name']?.toString() ?? '$platform Artist';
    final album = item['album']?['title']?.toString() ?? '$platform Track';
    final cover = item['album']?['cover_big']?.toString() ??
        item['album']?['cover_medium']?.toString();
    final rawDuration = item['duration'];
    int durationSec = 0;
    if (rawDuration is num) {
      durationSec = rawDuration.toInt();
    } else if (rawDuration is String) {
      durationSec = int.tryParse(rawDuration) ?? 0;
    }
    if (durationSec <= 0) durationSec = 180;

    return MediaItem(
      id: '${prefix}_$id',
      title: title,
      artist: artist,
      album: album,
      duration: Duration(seconds: durationSec),
      artUri: cover != null ? Uri.tryParse(cover) : null,
      extras: {
        'platform': platform,
        'is$platform': true,
        'searchQuery': '$title $artist',
        'originalId': id,
        'duration': durationSec,
        'length':
            "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
      },
    );
  }

  /// Search specifically for Spotify tracks
  static Future<List<MediaItem>> searchSpotify(String query,
      {int limit = 25}) async {
    try {
      final url =
          'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=$limit';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List? ?? [];
        return data
            .whereType<Map>()
            .map((item) => _mapDeezerTrack(item, 'sp', 'Spotify'))
            .toList();
      }
    } catch (e) {
      printERROR("Spotify platform search error: $e");
    }

    return [];
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
        return data
            .whereType<Map>()
            .map((item) => _mapDeezerTrack(item, 'az', 'Amazon'))
            .toList();
      }
    } catch (e) {
      printERROR("Amazon platform search error: $e");
    }

    return [];
  }

  /// Get current Spotify Top Hits for Home Screen
  static Future<List<MediaItem>> getSpotifyTopHits({int limit = 25}) async {
    try {
      final url = 'https://api.deezer.com/chart/0/tracks?limit=$limit';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List? ?? [];
        final items = data
            .whereType<Map>()
            .map((item) => _mapDeezerTrack(item, 'sp', 'Spotify'))
            .toList();
        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      printERROR("getSpotifyTopHits error: $e");
    }
    return await searchSpotify('Top Hits', limit: limit);
  }

  /// Get current Amazon Music Top Tracks for Home Screen
  static Future<List<MediaItem>> getAmazonTopTracks({int limit = 25}) async {
    try {
      final url = 'https://api.deezer.com/chart/0/tracks?limit=$limit&index=25';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List? ?? [];
        final items = data
            .whereType<Map>()
            .map((item) => _mapDeezerTrack(item, 'az', 'Amazon'))
            .toList();
        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      printERROR("getAmazonTopTracks error: $e");
    }
    return await searchAmazon('Popular Hits', limit: limit);
  }

  /// Spotify and Amazon results only carry metadata (they come from Deezer),
  /// so the audio has to be matched on another source. SoundCloud is tried
  /// first, YouTube Music only if SoundCloud has no usable match.
  static Future<MediaItem?> resolveMatchedTrack(
      String trackId, String searchQuery,
      {MediaItem? originalTrack, bool skipSoundCloud = false}) async {
    if (!skipSoundCloud && _matchedItemCache.containsKey(trackId)) {
      return _matchedItemCache[trackId];
    }

    final q = _cleanQuery(searchQuery);

    if (!skipSoundCloud) {
      try {
        final scTracks = await SoundCloudService()
            .searchTracks(q, limit: 8)
            .timeout(const Duration(seconds: 6));
        final match = findBestMatch(scTracks, originalTrack);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to SoundCloud: '${match.title}' by '${match.artist}'");
          return match;
        }
        printINFO("No SoundCloud match for $trackId ('$q')");
      } catch (e) {
        printERROR("SoundCloud match failed for $trackId: $e");
      }
    }

    try {
      final musicServices = Get.find<MusicServices>();
      final res = await musicServices
          .search(q, filter: 'songs', limit: 8)
          .timeout(const Duration(seconds: 6));
      final rawList = (res['Songs'] as List?) ?? (res['mixed'] as List?);
      final ytTracks = (rawList ?? const [])
          .whereType<MediaItem>()
          .where((e) => !e.id.startsWith('sp_') && !e.id.startsWith('az_'))
          .toList();
      final match = findBestMatch(ytTracks, originalTrack);
      if (match != null) {
        _remember(trackId, match);
        printINFO("Matched $trackId to YouTube: '${match.title}' by '${match.artist}'");
        return match;
      }
    } catch (e) {
      printERROR("YouTube match failed for $trackId: $e");
    }

    return null;
  }

  static void _remember(String trackId, MediaItem match) {
    _matchedItemCache[trackId] = match;
    _matchCache[trackId] = match.id;
  }

  static String _cleanQuery(String searchQuery) {
    final cleaned = searchQuery
        .replaceAll(RegExp(r'\(feat\.[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[feat\.[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\((official )?(video|audio)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(official )?(video|audio)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(lyrics\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[lyrics\]', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : searchQuery;
  }

  /// Backward-compatible method returning matched stream ID
  static Future<String?> resolveMatchedStreamId(
      String trackId, String searchQuery,
      {MediaItem? originalTrack}) async {
    final matched = await resolveMatchedTrack(trackId, searchQuery, originalTrack: originalTrack);
    return matched?.id;
  }

  /// Picks the candidate that fits the original track best (title, artist,
  /// duration). Returns null if nothing is close enough.
  static MediaItem? findBestMatch(List<MediaItem> candidates, MediaItem? original) {
    if (candidates.isEmpty) return null;
    if (original == null) return candidates.first;

    final expectedTitle = _normalizeString(original.title);
    final expectedArtist = _normalizeString(original.artist ?? '');
    final expectedDurationSec = original.duration?.inSeconds ?? 0;

    MediaItem? bestMatch;
    double bestScore = -1.0;

    for (var candidate in candidates) {
      double score = 0.0;
      final cTitle = _normalizeString(candidate.title);
      if (cTitle.isEmpty) continue;
      final cArtist = _normalizeString(candidate.artist ?? '');
      final cDurationSec = candidate.duration?.inSeconds ?? 0;

      // 1. Title matching
      if (cTitle == expectedTitle) {
        score += 50.0;
      } else if (cTitle.contains(expectedTitle) || expectedTitle.contains(cTitle)) {
        score += 35.0;
      } else {
        final expectedWords = expectedTitle.split(' ').where((w) => w.length > 2);
        int matchedWords = expectedWords.where((w) => cTitle.contains(w)).length;
        if (expectedWords.isNotEmpty) {
          score += (matchedWords / expectedWords.length) * 30.0;
        }
      }

      // 2. Artist matching
      if (expectedArtist.isNotEmpty) {
        if (cArtist.contains(expectedArtist) || cTitle.contains(expectedArtist)) {
          score += 25.0;
        }
      }

      // 3. Duration matching (penalize if difference is large)
      if (expectedDurationSec > 0 && cDurationSec > 0) {
        final diff = (expectedDurationSec - cDurationSec).abs();
        if (diff <= 10) {
          score += 25.0;
        } else if (diff <= 30) {
          score += 15.0;
        } else if (diff <= 60) {
          score += 5.0;
        } else {
          score -= 25.0; // Heavy penalty for hour-long mixes or 30-sec snippets
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    return bestScore >= 20.0 ? bestMatch : null;
  }

  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
