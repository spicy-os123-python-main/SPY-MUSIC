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
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
    },
  ));

  /// Cache of matched stream IDs for Spotify/Amazon tracks
  static final Map<String, String> _matchCache = {};

  /// Cache of full matched MediaItems for Spotify/Amazon tracks
  static final Map<String, MediaItem> _matchedItemCache = {};

  /// Clear all matched track caches
  static void clearAllCache() {
    _matchCache.clear();
    _matchedItemCache.clear();
    printINFO("Cleared PlatformSearchService match cache");
  }

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
        'artist': artist,
        'artists': [
          {'name': artist, 'id': ''}
        ],
        'originalId': id,
        'duration': durationSec,
        'length':
            "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
      },
    );
  }

  static MediaItem _mapItunesTrack(Map item, String prefix, String platform) {
    final id = item['trackId']?.toString() ?? '';
    final title = item['trackName']?.toString() ?? 'Unbekannt';
    final artist = item['artistName']?.toString() ?? '$platform Artist';
    final album = item['collectionName']?.toString() ?? '$platform Track';
    final cover100 = item['artworkUrl100']?.toString();
    final cover = cover100?.replaceAll('100x100bb', '600x600bb') ?? cover100;
    final durationMs = item['trackTimeMillis'] as int? ?? 180000;
    final durationSec = durationMs > 0 ? (durationMs / 1000).round() : 180;

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
        'artist': artist,
        'artists': [
          {'name': artist, 'id': ''}
        ],
        'originalId': id,
        'duration': durationSec,
        'length':
            "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
      },
    );
  }

  static Future<List<MediaItem>> _searchItunes(
      String query, String prefix, String platform,
      {int limit = 25}) async {
    try {
      final url =
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=$limit';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final list = rawData is Map
            ? (rawData['results'] as List? ?? [])
            : [];
        return list
            .whereType<Map>()
            .map((item) => _mapItunesTrack(item, prefix, platform))
            .toList();
      }
    } catch (_) {}
    return [];
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
        if (data.isNotEmpty) {
          return data
              .whereType<Map>()
              .map((item) => _mapDeezerTrack(item, 'sp', 'Spotify'))
              .toList();
        }
      }
    } catch (e) {
      printINFO("Deezer search unavailable, using iTunes fallback: $e");
    }

    // High-reliability fallback (iTunes Search API, no 403 blocks)
    return await _searchItunes(query, 'sp', 'Spotify', limit: limit);
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
        if (data.isNotEmpty) {
          return data
              .whereType<Map>()
              .map((item) => _mapDeezerTrack(item, 'az', 'Amazon'))
              .toList();
        }
      }
    } catch (e) {
      printINFO("Deezer search unavailable, using iTunes fallback: $e");
    }

    // High-reliability fallback (iTunes Search API, no 403 blocks)
    return await _searchItunes(query, 'az', 'Amazon', limit: limit);
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
    } catch (_) {}
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

  /// Spotify and Amazon tracks carry official studio metadata (from Deezer/Spotify),
  /// so the audio is matched against official studio releases on YouTube Music FIRST.
  /// SoundCloud is only queried as an absolute last resort with strict tempo/pitch checks.
  static Future<MediaItem?> resolveMatchedTrack(
      String trackId, String searchQuery,
      {MediaItem? originalTrack, bool skipSoundCloud = false}) async {
    if (!skipSoundCloud && _matchedItemCache.containsKey(trackId)) {
      return _matchedItemCache[trackId];
    }

    final q = _cleanQuery(searchQuery);

    // 1. YouTube Music FIRST! (Official studio releases from record labels at 1.0x speed)
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
        printINFO("Matched $trackId to YouTube Music: '${match.title}' by '${match.artist}'");
        return match;
      }
    } catch (e) {
      printERROR("YouTube Music matching failed for $trackId: $e");
    }

    // 2. YouTube Search with 'official audio' (label topic releases)
    try {
      final musicServices = Get.find<MusicServices>();
      final res = await musicServices
          .search('$q official audio', limit: 6)
          .timeout(const Duration(seconds: 6));
      final rawList = (res['Songs'] as List?) ?? (res['mixed'] as List?);
      final ytTracks = (rawList ?? const [])
          .whereType<MediaItem>()
          .where((e) => !e.id.startsWith('sp_') && !e.id.startsWith('az_'))
          .toList();
      final match = findBestMatch(ytTracks, originalTrack);
      if (match != null) {
        _remember(trackId, match);
        printINFO("Matched $trackId to YouTube Official Audio: '${match.title}' by '${match.artist}'");
        return match;
      }
    } catch (e) {
      printERROR("YouTube Official Audio search failed for $trackId: $e");
    }

    // 3. SoundCloud as absolute LAST resort ONLY (with strict tempo/pitch rejection)
    if (!skipSoundCloud) {
      try {
        final scTracks = await SoundCloudService()
            .searchTracks(q, limit: 6)
            .timeout(const Duration(seconds: 6));
        final match = findBestMatch(scTracks, originalTrack, strictSpeedCheck: true);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to SoundCloud fallback: '${match.title}' by '${match.artist}'");
          return match;
        }
        printINFO("No suitable SoundCloud match for $trackId ('$q')");
      } catch (e) {
        printERROR("SoundCloud fallback failed for $trackId: $e");
      }
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

  static final List<String> _unwantedTags = [
    'sped up',
    'speed up',
    'slowed',
    'slow',
    'reverb',
    'nightcore',
    'pitch',
    'pitched',
    'chipmunk',
    '8d audio',
    'bass boosted',
    'bassboost',
    'remix',
    'bootleg',
    'mashup',
    'cover',
    'tribute',
    'karaoke',
    'instrumental',
    'parody',
    'live',
    'concert',
  ];

  /// Picks the candidate that fits the original studio track best.
  /// Strictly rejects sped-up, slowed, nightcore, remix, or wrong-length tracks.
  static MediaItem? findBestMatch(List<MediaItem> candidates, MediaItem? original,
      {bool strictSpeedCheck = false}) {
    if (candidates.isEmpty) return null;
    if (original == null) return candidates.first;

    final origTitleLower = original.title.toLowerCase();
    final expectedTitle = _normalizeString(_coreTitle(original.title));
    final expectedArtist = _normalizeString(original.artist ?? '');
    int expectedDurationSec = original.duration?.inSeconds ?? 0;
    if (expectedDurationSec == 0 && original.extras != null) {
      if (original.extras!['duration'] is int) {
        expectedDurationSec = original.extras!['duration'] as int;
      } else if (original.extras!['length'] != null) {
        final parsed = _parseDurationString(original.extras!['length']?.toString());
        if (parsed != null) expectedDurationSec = parsed;
      }
    }

    MediaItem? bestMatch;
    double bestScore = -1.0;

    for (var candidate in candidates) {
      double score = 0.0;
      final rawTitleLower = candidate.title.toLowerCase();
      final cTitle = _normalizeString(_coreTitle(candidate.title));
      if (cTitle.isEmpty) continue;
      final cArtist = _normalizeString(candidate.artist ?? '');
      int cDurationSec = candidate.duration?.inSeconds ?? 0;
      if (cDurationSec == 0 && candidate.extras != null) {
        if (candidate.extras!['duration'] is int) {
          cDurationSec = candidate.extras!['duration'] as int;
        } else if (candidate.extras!['length'] != null) {
          final parsed = _parseDurationString(candidate.extras!['length']?.toString());
          if (parsed != null) cDurationSec = parsed;
        }
      }

      // 1. Strict rejection of unwanted modifications (sped up, nightcore, slowed, remix, cover)
      // unless original track explicitly has that tag
      bool hasUnwanted = false;
      for (final tag in _unwantedTags) {
        if (rawTitleLower.contains(tag) && !origTitleLower.contains(tag)) {
          hasUnwanted = true;
          break;
        }
      }
      if (hasUnwanted) {
        continue; // Immediately drop altered/remixed audio
      }

      // 2. Duration matching: Studio master tracks on YT Music and Spotify match within seconds
      if (expectedDurationSec > 0 && cDurationSec > 0) {
        final diff = (expectedDurationSec - cDurationSec).abs();
        if (strictSpeedCheck && diff > 7) {
          continue; // SoundCloud track differs too much -> skip
        }
        if (diff <= 2) {
          score += 45.0; // Near identical length -> studio master
        } else if (diff <= 5) {
          score += 35.0;
        } else if (diff <= 10) {
          score += 20.0;
        } else if (diff <= 20) {
          score -= 30.0;
        } else {
          score -= 100.0; // Heavy penalty for wrong length
        }
      }

      // 3. Title matching
      if (cTitle == expectedTitle) {
        score += 55.0;
      } else if (cTitle.startsWith(expectedTitle) || expectedTitle.startsWith(cTitle)) {
        score += 40.0;
      } else if (cTitle.contains(expectedTitle) || expectedTitle.contains(cTitle)) {
        score += 30.0;
      } else {
        final expectedWords = expectedTitle.split(' ').where((w) => w.length > 2).toList();
        if (expectedWords.isNotEmpty) {
          int matchedWords = expectedWords.where((w) => cTitle.contains(w)).length;
          score += (matchedWords / expectedWords.length) * 25.0;
        }
      }

      // 4. Artist matching
      if (expectedArtist.isNotEmpty) {
        if (cArtist == expectedArtist) {
          score += 35.0;
        } else if (cArtist.contains(expectedArtist) || expectedArtist.contains(cArtist)) {
          score += 25.0;
        } else if (cTitle.contains(expectedArtist) || rawTitleLower.contains(expectedArtist)) {
          score += 20.0;
        } else {
          score -= 15.0; // Wrong artist penalty
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    final minThreshold = strictSpeedCheck ? 65.0 : 45.0;
    return bestScore >= minThreshold ? bestMatch : null;
  }

  static int? _parseDurationString(String? time) {
    if (time == null || time.isEmpty) return null;
    try {
      int sec = 0;
      final splitted = time.split(':');
      if (splitted.length == 3) {
        sec += (int.tryParse(splitted[0]) ?? 0) * 3600 +
            (int.tryParse(splitted[1]) ?? 0) * 60 +
            (int.tryParse(splitted[2]) ?? 0);
      } else if (splitted.length == 2) {
        sec += (int.tryParse(splitted[0]) ?? 0) * 60 +
            (int.tryParse(splitted[1]) ?? 0);
      } else if (splitted.length == 1) {
        sec += int.tryParse(splitted[0]) ?? 0;
      }
      return sec > 0 ? sec : null;
    } catch (_) {
      return null;
    }
  }

  static String _coreTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*\(feat\.[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[feat\.[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*(feat|with)\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*.*remaster.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*remaster.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*single version.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*single version.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\((official )?(video|audio)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[(official )?(video|audio)\]', caseSensitive: false), '')
        .trim();
  }

  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
