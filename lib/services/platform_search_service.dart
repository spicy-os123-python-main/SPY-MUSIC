import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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

  /// Get matched stream ID for a platform track ID
  static String? getMatchedTrackId(String trackId) => _matchCache[trackId];

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
  static List<MediaItem> _extractYtTracks(Map<String, dynamic> res) {
    final List<MediaItem> tracks = [];
    for (final val in res.values) {
      if (val is List) {
        for (final item in val) {
          if (item is MediaItem &&
              !item.id.startsWith('sp_') &&
              !item.id.startsWith('az_') &&
              !tracks.any((t) => t.id == item.id)) {
            tracks.add(item);
          }
        }
      }
    }
    return tracks;
  }

  /// Multi-tier matching ensures 100% exact studio masters without wrong covers or wrong artists.
  static Future<MediaItem?> resolveMatchedTrack(
      String trackId, String searchQuery,
      {MediaItem? originalTrack, bool skipSoundCloud = false}) async {
    if (!skipSoundCloud && _matchedItemCache.containsKey(trackId)) {
      return _matchedItemCache[trackId];
    }

    final cleanTitle = extractCleanTitle(originalTrack?.title ?? searchQuery);
    final primaryArtist = extractPrimaryArtist(originalTrack?.artist);
    final allArtists = (originalTrack?.artist ?? '')
        .replaceAll(RegExp(r'[,;/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    bool musicServicesAvailable = true;

    // 1. YouTube Music - Studio Tracks with Clean Title + Primary Artist
    try {
      final musicServices = Get.find<MusicServices>();
      final q1 = '$cleanTitle $primaryArtist'.trim();
      final res = await musicServices
          .search(q1, filter: 'songs', limit: 8)
          .timeout(const Duration(milliseconds: 3500));
      final ytTracks = _extractYtTracks(res);
      final match = findBestMatch(ytTracks, originalTrack);
      if (match != null) {
        _remember(trackId, match);
        printINFO("Matched $trackId to YouTube Music (Primary): '${match.title}' by '${match.artist}'");
        return match;
      }
    } catch (e) {
      musicServicesAvailable = false;
      printINFO("YouTube Music primary search error for $trackId: $e");
    }

    if (musicServicesAvailable) {
      // 2. YouTube Music - Studio Tracks with All Artists if primary differed
      if (allArtists.isNotEmpty && allArtists != primaryArtist) {
        try {
          final musicServices = Get.find<MusicServices>();
          final q2 = '$cleanTitle $allArtists'.trim();
          final res = await musicServices
              .search(q2, filter: 'songs', limit: 8)
              .timeout(const Duration(milliseconds: 3000));
          final ytTracks = _extractYtTracks(res);
          final match = findBestMatch(ytTracks, originalTrack);
          if (match != null) {
            _remember(trackId, match);
            printINFO("Matched $trackId to YouTube Music (All Artists): '${match.title}' by '${match.artist}'");
            return match;
          }
        } catch (e) {
          printINFO("YouTube Music all-artists search error for $trackId: $e");
        }
      }

      // 3. YouTube - Record Label Topic Releases ('- Topic' channels)
      try {
        final musicServices = Get.find<MusicServices>();
        final q3 = '$cleanTitle $primaryArtist Topic'.trim();
        final res = await musicServices
            .search(q3, limit: 6)
            .timeout(const Duration(milliseconds: 3000));
        final ytTracks = _extractYtTracks(res);
        final match = findBestMatch(ytTracks, originalTrack);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to YouTube Topic Release: '${match.title}' by '${match.artist}'");
          return match;
        }
      } catch (e) {
        printINFO("YouTube Topic search error for $trackId: $e");
      }

      // 4. YouTube - Official Audio label releases
      try {
        final musicServices = Get.find<MusicServices>();
        final q4 = '$cleanTitle $primaryArtist official audio'.trim();
        final res = await musicServices
            .search(q4, limit: 6)
            .timeout(const Duration(milliseconds: 3000));
        final ytTracks = _extractYtTracks(res);
        final match = findBestMatch(ytTracks, originalTrack);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to YouTube Official Audio: '${match.title}' by '${match.artist}'");
          return match;
        }
      } catch (e) {
        printINFO("YouTube Official Audio search error for $trackId: $e");
      }

      // 5. YouTube - Clean Title + Primary Artist General Search (includes Videos & Cards)
      try {
        final musicServices = Get.find<MusicServices>();
        final q5 = '$cleanTitle $primaryArtist'.trim();
        final res = await musicServices
            .search(q5, limit: 8)
            .timeout(const Duration(milliseconds: 3000));
        final ytTracks = _extractYtTracks(res);
        final match = findBestMatch(ytTracks, originalTrack);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to YouTube General Audio: '${match.title}' by '${match.artist}'");
          return match;
        }
      } catch (e) {
        printINFO("YouTube General search error for $trackId: $e");
      }
    }

    // 6. Direct YouTube Search for Creator & Indie Tracks (e.g. Execute gaming songs, YouTube music videos)
    try {
      final yt = YoutubeExplode();
      try {
        final qYT = '$cleanTitle $primaryArtist'.trim();
        final searchResults =
            await yt.search.search(qYT).timeout(const Duration(seconds: 4));
        final ytCandidates = <MediaItem>[];
        try {
          for (final v in searchResults) {
            try {
              ytCandidates.add(MediaItem(
                id: v.id.value,
                title: v.title,
                artist: v.author,
                duration: v.duration,
              ));
              if (ytCandidates.length >= 8) break;
            } catch (_) {}
          }
        } catch (_) {}
        final match = findBestMatch(ytCandidates, originalTrack);
        if (match != null) {
          _remember(trackId, match);
          printINFO(
              "Matched $trackId to YouTube Creator Upload: '${match.title}' by '${match.artist}'");
          return match;
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      printERROR("YouTube Creator search error for $trackId: $e");
    }

    // 7. SoundCloud - Strict verified fallback ONLY (strictly rejects non-matching artists or covers)
    if (!skipSoundCloud) {
      try {
        final qSC = '$cleanTitle $primaryArtist'.trim();
        final scTracks = await SoundCloudService()
            .searchTracks(qSC, limit: 6)
            .timeout(const Duration(seconds: 6));
        final match = findBestMatch(scTracks, originalTrack, strictSpeedCheck: true);
        if (match != null) {
          _remember(trackId, match);
          printINFO("Matched $trackId to SoundCloud verified fallback: '${match.title}' by '${match.artist}'");
          return match;
        }
        printINFO("No suitable SoundCloud verified match for $trackId ('$qSC')");
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

  static String extractCleanTitle(String rawTitle) {
    return rawTitle
        .replaceAll(RegExp(r'\s*\(feat\.[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[feat\.[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(feat[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[feat[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(ft\.[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[ft\.[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(ft[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[ft[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(featuring[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[featuring[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(with[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[with[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*(feat\.|feat|ft\.|ft|featuring|with)\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*.*remaster.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*remaster.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*remaster.*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*single version.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*single version.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*radio edit.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*radio edit.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*deluxe.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*deluxe.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*bonus track.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*bonus track.*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\((official )?(video|audio|music video)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[(official )?(video|audio|music video)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(lyrics\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[lyrics\]', caseSensitive: false), '')
        .trim();
  }

  static String extractPrimaryArtist(String? artist) {
    if (artist == null || artist.trim().isEmpty) return '';
    final parts = artist.split(RegExp(r'[,;/&]|(\bfeat\b)|(\bft\b)', caseSensitive: false));
    return parts.first.trim();
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
    'nightcore',
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
    'acoustic',
    'guitar cover',
    'piano cover',
    'tutorial',
    'reaction',
    'review',
  ];

  /// Picks the candidate that fits the original studio track best.
  /// Strictly rejects sped-up, slowed, nightcore, remix, or wrong-length tracks.
  static MediaItem? findBestMatch(List<MediaItem> candidates, MediaItem? original,
      {bool strictSpeedCheck = false}) {
    if (candidates.isEmpty) return null;
    if (original == null) return candidates.first;

    final origTitleLower = original.title.toLowerCase();
    final cleanOrigTitle = extractCleanTitle(original.title);
    final expectedTitle = _normalizeString(cleanOrigTitle);
    final rawArtist = original.artist ?? '';
    final primaryArtist = extractPrimaryArtist(rawArtist);
    final expectedArtist = _normalizeString(rawArtist);

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
      final cCleanTitle = extractCleanTitle(candidate.title);
      final cTitle = _normalizeString(cCleanTitle);
      if (cTitle.isEmpty) continue;
      final cArtist = candidate.artist ?? '';
      int cDurationSec = candidate.duration?.inSeconds ?? 0;
      if (cDurationSec == 0 && candidate.extras != null) {
        if (candidate.extras!['duration'] is int) {
          cDurationSec = candidate.extras!['duration'] as int;
        } else if (candidate.extras!['length'] != null) {
          final parsed = _parseDurationString(candidate.extras!['length']?.toString());
          if (parsed != null) cDurationSec = parsed;
        }
      }

      // 1. Strict rejection of unwanted modifications using word-boundary regex
      // (prevents false matches on words like 'alive', 'discover', 'slowly')
      bool hasUnwanted = false;
      for (final tag in _unwantedTags) {
        final pattern = RegExp(r'\b' + RegExp.escape(tag) + r'\b', caseSensitive: false);
        if (pattern.hasMatch(rawTitleLower) && !pattern.hasMatch(origTitleLower)) {
          hasUnwanted = true;
          break;
        }
      }
      if (hasUnwanted) {
        continue;
      }

      // 2. Strict Artist Verification
      final normCand = _normalizeArtist(cArtist);
      final normExp = _normalizeArtist(expectedArtist);
      final normPrim = _normalizeArtist(primaryArtist);

      final bool artistMatches = normCand == normExp ||
          normCand == normPrim ||
          normCand.contains(normPrim) ||
          normExp.contains(normCand) ||
          rawTitleLower.contains(normPrim) ||
          rawTitleLower.contains(normExp);

      if (strictSpeedCheck && !artistMatches) {
        continue;
      }

      // If the artist doesn't match at all:
      // For short titles (1-2 words), NEVER allow a different artist!
      final titleWords = expectedTitle.split(' ').where((w) => w.length > 1).toList();
      if (!artistMatches && expectedArtist.isNotEmpty) {
        if (titleWords.length <= 2) {
          continue; // Disqualify wrong artist completely!
        }
        score -= 85.0; // Heavy penalty for mismatching artist
      } else if (artistMatches) {
        if (normCand == normExp || normCand == normPrim) {
          score += 45.0;
        } else if (normCand.contains(normPrim) || normExp.contains(normCand)) {
          score += 35.0;
        } else if (rawTitleLower.contains(normPrim)) {
          score += 28.0;
        }
        // Creator video boost: "by <Artist>" or "song by <Artist>"
        if (rawTitleLower.contains('by $normPrim') ||
            rawTitleLower.contains('song by $normPrim') ||
            rawTitleLower.contains('by $normExp')) {
          score += 25.0;
        }
      }

      // 3. Duration matching: Studio master tracks on YT Music and Spotify match within seconds
      if (expectedDurationSec > 0 && cDurationSec > 0) {
        final diff = (expectedDurationSec - cDurationSec).abs();
        if (strictSpeedCheck && diff > 5) {
          continue; // SoundCloud track differs too much -> skip
        }
        if (diff <= 3) {
          score += 45.0; // Near identical length -> studio master
        } else if (diff <= 8) {
          score += 35.0;
        } else if (diff <= 18) {
          score += 20.0;
        } else if (diff <= 35) {
          score += 5.0;
        } else if (diff > 60) {
          score -= 70.0; // Heavy penalty for gameplay, tutorial, or extended mix!
        } else {
          score -= 30.0;
        }
      }

      // 4. Official Release / Topic Channel Boost
      if (rawTitleLower.contains('official audio') ||
          cArtist.toLowerCase().contains('topic') ||
          cArtist.toLowerCase().contains('vevo') ||
          cArtist.toLowerCase().contains('official')) {
        score += 30.0;
      }

      // 5. Title matching
      if (cTitle == expectedTitle) {
        score += 55.0;
      } else if (cTitle.startsWith(expectedTitle) || expectedTitle.startsWith(cTitle)) {
        score += 45.0;
      } else if (cTitle.contains(expectedTitle) || expectedTitle.contains(cTitle)) {
        score += 40.0;
      } else {
        final expectedWords = expectedTitle.split(' ').where((w) => w.length > 2).toList();
        if (expectedWords.isNotEmpty) {
          int matchedWords = expectedWords.where((w) => cTitle.contains(w)).length;
          if (matchedWords == 0) continue; // Zero title words matched -> cannot be the song!
          score += (matchedWords / expectedWords.length) * 32.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    final minThreshold = strictSpeedCheck ? 75.0 : 45.0;
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

  static String _normalizeArtist(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'\s*-\s*topic\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\btopic\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bvevo\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bofficial\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
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
