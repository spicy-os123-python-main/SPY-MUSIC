import 'dart:async';
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
          final rawDuration = item['duration'];
          int durationSec = 0;
          if (rawDuration is num) {
            durationSec = rawDuration.toInt();
          } else if (rawDuration is String) {
            durationSec = int.tryParse(rawDuration) ?? 0;
          }
          if (durationSec <= 0) durationSec = 180;

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
              'duration': durationSec,
              'length': "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
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
          final rawDuration = item['duration'];
          int durationSec = 0;
          if (rawDuration is num) {
            durationSec = rawDuration.toInt();
          } else if (rawDuration is String) {
            durationSec = int.tryParse(rawDuration) ?? 0;
          }
          if (durationSec <= 0) durationSec = 180;

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
              'duration': durationSec,
              'length': "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
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

  /// Fast fallback search with explicit YouTube labeling
  static Future<List<MediaItem>> _queryFilteredEngine(
      String query, String platformName) async {
    try {
      final musicServices = Get.find<MusicServices>();
      final results = await musicServices.search(query, filter: 'songs', limit: 25);
      final rawList = (results['Songs'] as List?) ?? (results['mixed'] as List?);
      if (rawList != null && rawList.isNotEmpty) {
        return rawList.whereType<MediaItem>().map((item) {
          final extras = Map<String, dynamic>.from(item.extras ?? {});
          extras['platform'] = '$platformName (via YouTube)';
          extras['isFallback'] = true;
          return item.copyWith(extras: extras);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Resolve audio stream for Spotify or Amazon track by matching track title, artist & duration
  /// Starts SoundCloud and YouTube search in parallel and picks first valid match to avoid slow sequential fallbacks
  static Future<MediaItem?> resolveMatchedTrack(
      String trackId, String searchQuery,
      {MediaItem? originalTrack}) async {
    if (_matchedItemCache.containsKey(trackId)) {
      return _matchedItemCache[trackId];
    }

    final cleanQuery = searchQuery
        .replaceAll(RegExp(r'\(feat\.[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[feat\.[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(official video\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[official video\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(official audio\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[official audio\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(lyrics\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[lyrics\]', caseSensitive: false), '')
        .trim();
    final q = cleanQuery.isNotEmpty ? cleanQuery : searchQuery;

    final completer = Completer<MediaItem?>();
    int pending = 2;

    void onResolved(MediaItem? match, String source) {
      if (completer.isCompleted) return;
      if (match != null) {
        _matchedItemCache[trackId] = match;
        _matchCache[trackId] = match.id;
        printINFO("Matched $trackId to $source: '${match.title}' by '${match.artist}'");
        completer.complete(match);
      } else {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    // 1. Parallel Task: SoundCloud Search & Match (timeout 5s)
    SoundCloudService()
        .searchTracks(q, limit: 5)
        .timeout(const Duration(seconds: 5))
        .then((scTracks) {
      final match =
          scTracks.isNotEmpty ? _findBestMatch(scTracks, originalTrack) : null;
      onResolved(match, 'SoundCloud');
    }).catchError((e) {
      printERROR("SoundCloud parallel resolution failed for $trackId: $e");
      onResolved(null, 'SoundCloud');
    });

    // 2. Parallel Task: YouTube Music Search & Match (timeout 5s)
    Future.microtask(() async {
      try {
        final musicServices = Get.find<MusicServices>();
        final res = await musicServices
            .search(searchQuery, filter: 'songs', limit: 5)
            .timeout(const Duration(seconds: 5));
        final rawList = (res['Songs'] as List?) ?? (res['mixed'] as List?);
        MediaItem? match;
        if (rawList != null && rawList.isNotEmpty) {
          final ytTracks = rawList
              .whereType<MediaItem>()
              .where((e) => !e.id.startsWith('sp_') && !e.id.startsWith('az_'))
              .toList();
          if (ytTracks.isNotEmpty) {
            match = _findBestMatch(ytTracks, originalTrack);
          }
        }
        onResolved(match, 'YouTube');
      } catch (e) {
        printERROR("YouTube parallel resolution failed for $trackId: $e");
        onResolved(null, 'YouTube');
      }
    });

    return await completer.future
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  /// Backward-compatible method returning matched stream ID
  static Future<String?> resolveMatchedStreamId(
      String trackId, String searchQuery,
      {MediaItem? originalTrack}) async {
    final matched = await resolveMatchedTrack(trackId, searchQuery, originalTrack: originalTrack);
    return matched?.id;
  }

  /// Match candidates against original track by comparing title, artist, and duration
  static MediaItem? _findBestMatch(List<MediaItem> candidates, MediaItem? original) {
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

    return bestScore >= 15.0 ? bestMatch : candidates.first;
  }

  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
