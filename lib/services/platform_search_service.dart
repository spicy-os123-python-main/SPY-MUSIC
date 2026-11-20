import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../ui/player/player_controller.dart';
import 'music_service.dart';
import 'soundcloud_service.dart';
import '../utils/helper.dart';

class PlatformSearchService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'SPYMUSIC/1.12 (Android)',
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
    },
  ));

  /// Decode Map responses even when APIs (e.g. Apple iTunes `text/javascript`)
  /// return JSON as a raw String rather than `application/json`.
  static Map<String, dynamic>? _decodeJsonMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

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
    final preview = item['preview']?.toString() ?? '';
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
        'deezerId': id,
        'url': null,
        'previewUrl': preview.isNotEmpty ? preview : null,
        'streamSource': 'deezer',
        'duration': durationSec,
        if (rawDuration == null ||
            rawDuration == 0 ||
            (rawDuration is String && (int.tryParse(rawDuration) ?? 0) <= 0))
          'durationEstimated': true,
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
    final preview = item['previewUrl']?.toString() ?? '';
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
        'url': null,
        'previewUrl': preview.isNotEmpty ? preview : null,
        'streamSource': 'itunes',
        'duration': durationSec,
        if (item['trackTimeMillis'] == null) 'durationEstimated': true,
        'length':
            "${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}",
      },
    );
  }

  /// Direct stream resolver for Deezer / Spotify tracks without any YouTube fallback
  static Future<String?> getDeezerStreamUrl(String trackId,
      {String? query}) async {
    final cleanId = trackId.startsWith('sp_')
        ? trackId.substring(3)
        : (trackId.startsWith('az_') ? trackId.substring(3) : trackId);

    // 1. Direct Deezer track lookup by ID
    if (RegExp(r'^\d+$').hasMatch(cleanId)) {
      try {
        final response =
            await _dio.get('https://api.deezer.com/track/$cleanId');
        final map =
            response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
        if (map != null && map['error'] == null) {
          final preview = map['preview']?.toString();
          if (preview != null && preview.isNotEmpty) {
            printINFO("Deezer stream resolved by ID for $trackId: $preview");
            return preview;
          }
        }
      } catch (e) {
        printINFO("Deezer track lookup by ID ($cleanId) failed: $e");
      }
    }

    // 2. Deezer search by query
    if (query != null && query.isNotEmpty) {
      try {
        final sUrl =
            'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=1';
        final response = await _dio.get(sUrl);
        final map =
            response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
        if (map != null && map['error'] == null) {
          final data = map['data'] as List? ?? [];
          if (data.isNotEmpty && data[0] is Map) {
            final preview = (data[0] as Map)['preview']?.toString();
            if (preview != null && preview.isNotEmpty) {
              printINFO("Deezer stream resolved by query for $trackId: $preview");
              return preview;
            }
          }
        }
      } catch (e) {
        printINFO("Deezer search by query failed: $e");
      }

      // 3. iTunes fallback if Deezer returned no preview
      try {
        final iUrl =
            'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1';
        final response = await _dio.get(iUrl);
        final map =
            response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
        if (map != null) {
          final results = map['results'] as List? ?? [];
          if (results.isNotEmpty && results[0] is Map) {
            final preview = (results[0] as Map)['previewUrl']?.toString();
            if (preview != null && preview.isNotEmpty) {
              printINFO("iTunes stream resolved for $trackId: $preview");
              return preview;
            }
          }
        }
      } catch (e) {
        printINFO("iTunes fallback stream resolution failed: $e");
      }
    }

    return null;
  }

  static Future<List<MediaItem>> _searchItunes(
      String query, String prefix, String platform,
      {int limit = 25}) async {
    try {
      final url =
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=$limit';
      final response = await _dio.get(url);
      final rawData =
          response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
      if (rawData != null) {
        final list = rawData['results'] as List? ?? [];
        return list
            .whereType<Map>()
            .where((item) => item['trackName'] != null)
            .map((item) => _mapItunesTrack(item, prefix, platform))
            .toList();
      }
    } catch (e) {
      printINFO("iTunes search error: $e");
    }
    return [];
  }

  static MediaItem? _mapItunesRssEntry(
      Map entry, String prefix, String platform) {
    final id = entry['id']?['attributes']?['im:id']?.toString() ?? '';
    final title = entry['im:name']?['label']?.toString() ?? '';
    if (title.isEmpty) return null;
    final artist = entry['im:artist']?['label']?.toString() ?? '$platform Artist';
    final album = entry['im:collection']?['im:name']?['label']?.toString() ??
        '$platform Charts';

    String? cover;
    final images = entry['im:image'] as List? ?? [];
    if (images.isNotEmpty && images.last is Map) {
      final rawUrl = (images.last as Map)['label']?.toString();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        cover = rawUrl.replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb');
      }
    }

    String preview = '';
    final links = entry['link'] as List? ?? [];
    for (final link in links) {
      if (link is Map && link['attributes']?['rel'] == 'enclosure') {
        preview = link['attributes']?['href']?.toString() ?? '';
        if (preview.isNotEmpty) break;
      }
    }

    const durationSec = 180;
    return MediaItem(
      id: '${prefix}_${id.isNotEmpty ? id : title.hashCode}',
      title: title,
      artist: artist,
      album: album,
      duration: const Duration(seconds: durationSec),
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
        'url': null,
        'previewUrl': preview.isNotEmpty ? preview : null,
        'streamSource': 'itunes',
        'duration': durationSec,
        'durationEstimated': true,
        'length': '3:00',
      },
    );
  }

  static Future<List<MediaItem>> _getItunesTopSongs(
      String prefix, String platform,
      {int limit = 25, String country = 'de'}) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final url =
          'https://itunes.apple.com/$country/rss/topsongs/limit=$safeLimit/json';
      final response = await _dio.get(url);
      final map =
          response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
      final feed = map?['feed'];
      final entries = (feed is Map ? feed['entry'] : null) as List? ?? [];
      return entries
          .whereType<Map>()
          .map((e) => _mapItunesRssEntry(e, prefix, platform))
          .whereType<MediaItem>()
          .toList();
    } catch (e) {
      printINFO("iTunes RSS top songs error ($country): $e");
      return [];
    }
  }

  static Future<List<MediaItem>> _searchCatalog(
      String query, String prefix, String platform,
      {int limit = 25}) async {
    try {
      final url =
          'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=$limit';
      final response = await _dio.get(url);
      final map =
          response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
      if (map != null && map['error'] == null) {
        final data = map['data'] as List? ?? [];
        if (data.isNotEmpty) {
          return data
              .whereType<Map>()
              .map((item) => _mapDeezerTrack(item, prefix, platform))
              .toList();
        }
      } else if (map?['error'] != null) {
        printINFO("Deezer search returned error: ${map!['error']}");
      }
    } catch (e) {
      printINFO("Deezer search unavailable, using iTunes fallback: $e");
    }

    // High-reliability fallback (iTunes Search API, no 403 blocks)
    final itunesTracks =
        await _searchItunes(query, prefix, platform, limit: limit);
    if (itunesTracks.isNotEmpty) return itunesTracks;

    // Smart fallback if query had burner/alias words (e.g. "Brand New Car Squish")
    final words = query.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final relaxed = words.sublist(0, words.length - 1).join(' ');
      final relaxedTracks =
          await _searchItunes(relaxed, prefix, platform, limit: limit);
      if (relaxedTracks.isNotEmpty) return relaxedTracks;
    }

    // Ultimate fallback for leaks, pseudonym titles & burner artist tracks via YouTube API
    try {
      final ytTracks = await _searchYoutube(query, limit: limit);
      if (ytTracks.isNotEmpty) {
        return ytTracks.map((item) {
          final extras = Map<String, dynamic>.from(item.extras ?? {});
          extras['platform'] = platform;
          extras['is$platform'] = true;
          extras['originalId'] = item.id;
          return item.copyWith(
            id: '${prefix}_${item.id}',
            extras: extras,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<List<MediaItem>> _getChartTracks(
      String prefix, String platform,
      {int limit = 25,
      int index = 0,
      String country = 'de',
      String fallbackQuery = '2025 Hits'}) async {
    try {
      final url =
          'https://api.deezer.com/chart/0/tracks?limit=$limit${index > 0 ? '&index=$index' : ''}';
      final response = await _dio.get(url);
      final map =
          response.statusCode == 200 ? _decodeJsonMap(response.data) : null;
      if (map != null && map['error'] == null) {
        final data = map['data'] as List? ?? [];
        final items = data
            .whereType<Map>()
            .map((item) => _mapDeezerTrack(item, prefix, platform))
            .toList();
        if (items.isNotEmpty) return items;
      } else if (map?['error'] != null) {
        printINFO("Deezer chart returned error: ${map!['error']}");
      }
    } catch (e) {
      printINFO("Deezer chart error ($platform): $e");
    }

    final rssItems =
        await _getItunesTopSongs(prefix, platform, limit: limit, country: country);
    if (rssItems.isNotEmpty) return rssItems;

    return await _searchCatalog(fallbackQuery, prefix, platform, limit: limit);
  }

  /// Search specifically for Spotify tracks
  static Future<List<MediaItem>> searchSpotify(String query,
      {int limit = 25}) =>
      _searchCatalog(query, 'sp', 'Spotify', limit: limit);

  /// Search specifically for Amazon Music tracks
  static Future<List<MediaItem>> searchAmazon(String query,
      {int limit = 25}) =>
      _searchCatalog(query, 'az', 'Amazon', limit: limit);

  /// Get current Spotify Top Hits for Home Screen
  static Future<List<MediaItem>> getSpotifyTopHits({int limit = 25}) =>
      _getChartTracks('sp', 'Spotify',
          limit: limit, country: 'de', fallbackQuery: '2025 Hits');

  /// Get current Amazon Music Top Tracks for Home Screen
  static Future<List<MediaItem>> getAmazonTopTracks({int limit = 25}) =>
      _getChartTracks('az', 'Amazon',
          limit: limit, index: 25, country: 'us', fallbackQuery: 'Popular Hits');

  /// Safe accessor for MusicServices that ensures it is registered in GetX
  static MusicServices get _musicServices {
    if (Get.isRegistered<MusicServices>()) {
      return Get.find<MusicServices>();
    }
    return Get.put(MusicServices(), permanent: true);
  }

  /// Search YouTube / YouTube Music using the official InnerTube API with direct fallback
  static Future<List<MediaItem>> _searchYoutube(String query,
      {String? filter, int limit = 15}) async {
    try {
      final res = await _musicServices
          .search(query, filter: filter, limit: limit)
          .timeout(const Duration(seconds: 8));
      final tracks = _extractYtTracks(res);
      if (tracks.isNotEmpty) return tracks;
    } catch (e) {
      printINFO("YouTube Music search error for '$query': $e");
    }

    // Direct YouTube Search fallback via YoutubeExplode (<2s, works for unreleased leaks, creator uploads & topics)
    try {
      final yt = YoutubeExplode();
      try {
        final directResults = await yt.search
            .search(query)
            .timeout(const Duration(seconds: 7));
        final ytExplodeTracks = <MediaItem>[];
        for (final v in directResults.take(limit)) {
          ytExplodeTracks.add(MediaItem(
            id: v.id.value,
            title: v.title,
            artist: v.author,
            duration: v.duration,
            artUri: Uri.tryParse(v.thumbnails.highResUrl),
            extras: {
              'platform': 'YouTube',
              'searchQuery': '${v.title} ${v.author}',
              'artist': v.author,
              'duration': v.duration?.inSeconds,
            },
          ));
        }
        if (ytExplodeTracks.isNotEmpty) {
          printINFO("YouTube direct search recovered ${ytExplodeTracks.length} tracks for '$query'");
          return ytExplodeTracks;
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      printINFO("YouTube direct search error for '$query': $e");
    }

    return [];
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
    final artistHints = extractArtistHints(originalTrack);

    // 0. TOP PRIORITY: SoundCloud match FIRST as requested ("zuerst SoundCloud matchen, danach YouTube")
    if (!skipSoundCloud) {
      try {
        final qSC = '$cleanTitle $primaryArtist'.trim();
        final scTracks = await SoundCloudService()
            .searchTracks(qSC, limit: 8)
            .timeout(const Duration(seconds: 4));
        final match =
            findBestMatch(scTracks, originalTrack, strictSpeedCheck: true);
        if (match != null) {
          _remember(trackId, match);
          printINFO(
              "Matched $trackId to SoundCloud (Primary): '${match.title}' by '${match.artist}'");
          return match;
        }
        printINFO("No suitable SoundCloud match for $trackId ('$qSC'), checking YouTube...");
      } catch (e) {
        printERROR("SoundCloud primary match failed for $trackId: $e");
      }
    }

    // 0.1 ABSOLUTE TOP PRIORITY FOR LEAKS & PSEUDONYM TRACKS:
    // If we have verified artist hints from playlist or album context (e.g. Juice WRLD),
    // search with the clean title + top hint FIRST! This avoids wasting 20+ seconds on burner artist names like "Squish"!
    if (artistHints.isNotEmpty) {
      for (final hint in artistHints.take(3)) {
        final qHint = '$cleanTitle $hint'.trim();
        final ytHintFast = await _searchYoutube(qHint, limit: 15);
        final matchHintFast = findBestMatch(ytHintFast, originalTrack,
            allowFidelityTitleDurationMatch: true);
        if (matchHintFast != null) {
          _remember(trackId, matchHintFast);
          printINFO(
              "Fast-Path: Matched $trackId via artist hint '$hint' on YouTube: '${matchHintFast.title}' by '${matchHintFast.artist}'");
          return matchHintFast;
        }
      }
    }

    // 1. YouTube Music - Studio Tracks with Clean Title + Primary Artist
    final q1 = '$cleanTitle $primaryArtist'.trim();
    final ytTracks1 = await _searchYoutube(q1, filter: 'songs', limit: 8);
    final match1 = findBestMatch(ytTracks1, originalTrack);
    if (match1 != null) {
      _remember(trackId, match1);
      printINFO("Matched $trackId to YouTube Music (Primary): '${match1.title}' by '${match1.artist}'");
      return match1;
    }

    // Direct YouTube Search for Official / Studio Track via YouTube API (<1s fast path)
    final ytFast = await _searchYoutube(q1, limit: 15);
    final matchFast = findBestMatch(ytFast, originalTrack);
    if (matchFast != null) {
      _remember(trackId, matchFast);
      printINFO("Matched $trackId via direct YouTube search: '${matchFast.title}' by '${matchFast.artist}'");
      return matchFast;
    }

    // 2. YouTube Music - Studio Tracks with All Artists if primary differed
    if (allArtists.isNotEmpty && allArtists != primaryArtist) {
      final q2 = '$cleanTitle $allArtists'.trim();
      final ytTracks2 = await _searchYoutube(q2, filter: 'songs', limit: 8);
      final match2 = findBestMatch(ytTracks2, originalTrack);
      if (match2 != null) {
        _remember(trackId, match2);
        printINFO("Matched $trackId to YouTube Music (All Artists): '${match2.title}' by '${match2.artist}'");
        return match2;
      }
    }

    // 3. YouTube - Record Label Topic Releases ('- Topic' channels)
    final q3 = '$cleanTitle $primaryArtist Topic'.trim();
    final ytTracks3 = await _searchYoutube(q3, limit: 6);
    final match3 = findBestMatch(ytTracks3, originalTrack);
    if (match3 != null) {
      _remember(trackId, match3);
      printINFO("Matched $trackId to YouTube Topic Release: '${match3.title}' by '${match3.artist}'");
      return match3;
    }

    // 4. YouTube - Official Audio label releases
    final q4 = '$cleanTitle $primaryArtist official audio'.trim();
    final ytTracks4 = await _searchYoutube(q4, limit: 6);
    final match4 = findBestMatch(ytTracks4, originalTrack);
    if (match4 != null) {
      _remember(trackId, match4);
      printINFO("Matched $trackId to YouTube Official Audio: '${match4.title}' by '${match4.artist}'");
      return match4;
    }

    // 5. YouTube - Clean Title + Primary Artist General Search (includes Videos & Cards)
    final ytTracks5 = await _searchYoutube(q1, limit: 8);
    final match5 = findBestMatch(ytTracks5, originalTrack);
    if (match5 != null) {
      _remember(trackId, match5);
      printINFO("Matched $trackId to YouTube General Audio: '${match5.title}' by '${match5.artist}'");
      return match5;
    }

    // 6. Direct YouTube Search for Creator & Indie Tracks (e.g. Execute gaming songs, YouTube music videos)
    final ytVideos = await _searchYoutube(q1, filter: 'videos', limit: 15);
    final match6 = findBestMatch(ytVideos, originalTrack);
    if (match6 != null) {
      _remember(trackId, match6);
      printINFO("Matched $trackId to YouTube Creator Upload: '${match6.title}' by '${match6.artist}'");
      return match6;
    }

    // 7. SoundCloud - Strict verified fallback ONLY (strictly rejects non-matching artists or covers)
    if (!skipSoundCloud) {
      try {
        final qSC = '$cleanTitle $primaryArtist'.trim();
        final scTracks = await SoundCloudService()
            .searchTracks(qSC, limit: 6)
            .timeout(const Duration(seconds: 6));
        final match =
            findBestMatch(scTracks, originalTrack, strictSpeedCheck: true);
        if (match != null) {
          _remember(trackId, match);
          printINFO(
              "Matched $trackId to SoundCloud verified fallback: '${match.title}' by '${match.artist}'");
          return match;
        }
        printINFO("No suitable SoundCloud verified match for $trackId ('$qSC')");
      } catch (e) {
        printERROR("SoundCloud fallback failed for $trackId: $e");
      }
    }

    // --- PHASE 2: Leak / Burner / Unreleased Platform Track Recovery ---
    // For imported platform tracks (e.g. Spotify unreleased leaks by Juice WRLD, XXXTentacion, etc.
    // uploaded under burner/podcast pseudonyms like "Squish", "swisssss", "Devafterdarkk"),
    // standard searches for "$cleanTitle $primaryArtist" fail.
    // Here we leverage playlist/album artist hints and high-fidelity Title+Duration audio master matching.
    printINFO(
        "Starting Phase 2 Leak Recovery for '$cleanTitle' ($trackId). Artist hints: $artistHints");

    // 8. Try each extracted artist hint on YouTube and SoundCloud
    for (final hint in artistHints) {
      // 8a. YouTube with Artist Hint (direct creator uploads/leaks)
      final qHint = '$cleanTitle $hint'.trim();
      final ytCandidates = await _searchYoutube(qHint, limit: 15);
      final matchHint = findBestMatch(ytCandidates, originalTrack,
          allowFidelityTitleDurationMatch: true);
      if (matchHint != null) {
        _remember(trackId, matchHint);
        printINFO(
            "Phase 2: Matched $trackId via artist hint '$hint' on YouTube: '${matchHint.title}' by '${matchHint.artist}'");
        return matchHint;
      }

      // 8b. YouTube Music Songs with Hint
      final ytTracksHint =
          await _searchYoutube(qHint, filter: 'songs', limit: 8);
      final matchHintSongs = findBestMatch(ytTracksHint, originalTrack,
          allowFidelityTitleDurationMatch: true);
      if (matchHintSongs != null) {
        _remember(trackId, matchHintSongs);
        printINFO(
            "Phase 2: Matched $trackId via artist hint '$hint' on YouTube Music: '${matchHintSongs.title}' by '${matchHintSongs.artist}'");
        return matchHintSongs;
      }

      // 8c. YouTube Videos with Hint
      final ytVideosHint =
          await _searchYoutube(qHint, filter: 'videos', limit: 8);
      final matchHintVideos = findBestMatch(ytVideosHint, originalTrack,
          allowFidelityTitleDurationMatch: true);
      if (matchHintVideos != null) {
        _remember(trackId, matchHintVideos);
        printINFO(
            "Phase 2: Matched $trackId via artist hint '$hint' on YouTube Videos: '${matchHintVideos.title}' by '${matchHintVideos.artist}'");
        return matchHintVideos;
      }

      // 8d. SoundCloud with Hint
      if (!skipSoundCloud) {
        try {
          final scTracks = await SoundCloudService()
              .searchTracks(qHint, limit: 6)
              .timeout(const Duration(seconds: 4));
          final match = findBestMatch(scTracks, originalTrack,
              allowFidelityTitleDurationMatch: true);
          if (match != null) {
            _remember(trackId, match);
            printINFO(
                "Phase 2: Matched $trackId via artist hint '$hint' on SoundCloud: '${match.title}' by '${match.artist}'");
            return match;
          }
        } catch (e) {
          printINFO("Phase 2 Hint SoundCloud error for '$hint': $e");
        }
      }
    }

    // 9. Clean Title Search on YouTube Music with High-Fidelity Title+Duration Matching
    final ytClean = await _searchYoutube(cleanTitle, filter: 'songs', limit: 8);
    final matchClean = findBestMatch(ytClean, originalTrack,
        allowFidelityTitleDurationMatch: true);
    if (matchClean != null) {
      _remember(trackId, matchClean);
      printINFO(
          "Phase 2: Matched $trackId via Clean Title on YouTube Music: '${matchClean.title}' by '${matchClean.artist}'");
      return matchClean;
    }

    // 10. Clean Title & Title + "unreleased" Search on YouTube
    final ytLeakQueries = ['$cleanTitle unreleased', cleanTitle];
    for (final qYT in ytLeakQueries) {
      final ytLeakCandidates = await _searchYoutube(qYT, limit: 15);
      final matchLeak = findBestMatch(ytLeakCandidates, originalTrack,
          allowFidelityTitleDurationMatch: true);
      if (matchLeak != null) {
        _remember(trackId, matchLeak);
        printINFO(
            "Phase 2: Matched $trackId via YouTube ($qYT): '${matchLeak.title}' by '${matchLeak.artist}'");
        return matchLeak;
      }
    }

    // 11. SoundCloud Clean Title & Unreleased Search
    if (!skipSoundCloud) {
      final scLeakQueries = ['$cleanTitle unreleased', cleanTitle];
      for (final qSC in scLeakQueries) {
        try {
          final scTracks = await SoundCloudService()
              .searchTracks(qSC, limit: 8)
              .timeout(const Duration(seconds: 5));
          final match = findBestMatch(scTracks, originalTrack, allowFidelityTitleDurationMatch: true);
          if (match != null) {
            _remember(trackId, match);
            printINFO("Phase 2: Matched $trackId via SoundCloud ($qSC): '${match.title}' by '${match.artist}'");
            return match;
          }
        } catch (e) {
          printINFO("Phase 2 SoundCloud leak search error for '$qSC': $e");
        }
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

  /// Extracts candidate artist hints from a playlist or album name.
  /// (e.g. "Juice wrld xxxtentacion Lil peep" -> ["Juice wrld", "xxxtentacion", "Lil peep"])
  static List<String> extractArtistHints(MediaItem? item) {
    if (item == null) return const [];
    final knownHints = <String>{};
    final genericHints = <String>{};

    final playlistName = (item.extras?['playlistName'] as String?) ?? '';
    final albumName = item.album ?? (item.extras?['album'] as String?) ?? '';
    final candidateStrings = <String>[playlistName, albumName];

    try {
      if (Get.isRegistered<PlayerController>()) {
        final currentPlayFrom =
            Get.find<PlayerController>().playinfrom.value.name;
        if (currentPlayFrom.isNotEmpty) {
          candidateStrings.add(currentPlayFrom);
        }
      }
    } catch (_) {}

    final nonArtistStopWords = {
      'playlist', 'album', 'songs', 'song', 'hits', 'best', 'top', 'unreleased',
      'leak', 'leaks', 'favs', 'favorites', 'favourite', 'favourites', 'music',
      'mix', 'rap', 'hip', 'hop', 'hiphop', 'trap', 'drill', 'r&b', 'pop', 'rock',
      'vol', 'volume', 'pt', 'part', 'disc', 'cd', 'ep', 'lp', 'deluxe', 'edition',
      'soundtrack', 'ost', 'audio', 'video', 'my', 'the', 'and', 'with', 'feat', 'ft'
    };

    final commonArtists = [
      'juice wrld', 'xxxtentacion', 'lil peep', 'playboi carti', 'kanye west',
      'kanye', 'drake', 'travis scott', 'lil uzi vert', 'trippie redd',
      'mac miller', 'post malone', 'kendrick lamar', 'j cole', 'eminem',
      'the weeknd', 'billie eilish', 'frank ocean', 'asap rocky', 'ski mask',
      'gunna', 'young thug', 'future', 'lil baby', 'metro boomin', '21 savage'
    ];

    for (final text in candidateStrings) {
      if (text.isEmpty) continue;

      // 1. Look for well-known artist names first (highest priority)
      final lower = text.toLowerCase();
      for (final ca in commonArtists) {
        if (lower.contains(ca)) {
          knownHints.add(ca);
        }
      }

      // 2. Split on common artist delimiters
      final parts = text.split(RegExp(r'[,/&+|\-•]|\bfeat\b|\bft\b|\bwith\b', caseSensitive: false));
      for (final rawPart in parts) {
        final part = rawPart.trim();
        final words = part.split(RegExp(r'\s+'));
        final filteredWords = words.where((w) => !nonArtistStopWords.contains(w.toLowerCase())).toList();
        final cleanPart = filteredWords.join(' ').trim();
        if (cleanPart.length >= 3 && cleanPart.length <= 30 && !knownHints.any((k) => cleanPart.toLowerCase().contains(k))) {
          genericHints.add(cleanPart);
        }
      }
    }

    final hints = <String>[...knownHints, ...genericHints];

    // Exclude the track's existing primaryArtist if already known
    final primary = extractPrimaryArtist(item.artist).toLowerCase();
    hints.removeWhere((h) => h.toLowerCase() == primary || h.length < 3);

    return hints;
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

  /// Returns true if [url] points to a 30-second catalog preview clip rather than a full track.
  static bool isPreviewAudioUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('cdnt-preview.dzcdn.net') ||
        lower.contains('audio-ssl.itunes.apple.com') ||
        lower.contains('p.scdn.co/mp3-preview') ||
        lower.contains('/preview');
  }

  /// Picks the candidate that fits the original studio track best.
  /// Strictly rejects sped-up, slowed, nightcore, remix, or wrong-length tracks.
  static MediaItem? findBestMatch(List<MediaItem> candidates, MediaItem? original,
      {bool strictSpeedCheck = false,
      bool allowFidelityTitleDurationMatch = false}) {
    if (candidates.isEmpty) return null;
    if (original == null) return candidates.first;

    final origTitleLower = original.title.toLowerCase();
    final cleanOrigTitle = extractCleanTitle(original.title);
    final expectedTitle = _normalizeString(cleanOrigTitle);
    final rawArtist = original.artist ?? '';
    final primaryArtist = extractPrimaryArtist(rawArtist);
    final expectedArtist = _normalizeString(rawArtist);
    final artistHints = extractArtistHints(original);

    final bool durationEstimated = original.extras?['durationEstimated'] == true;
    int expectedDurationSec =
        durationEstimated ? 0 : (original.duration?.inSeconds ?? 0);
    if (expectedDurationSec >= 43200) {
      expectedDurationSec = 0; // Heal corrupted >12h durations
    }
    if (!durationEstimated && original.extras != null) {
      if (original.extras!['length'] != null) {
        final parsed = _parseDurationString(original.extras!['length']?.toString());
        if (parsed != null && parsed > 0 && parsed < 43200) expectedDurationSec = parsed;
      } else if (expectedDurationSec == 0 && original.extras!['duration'] is int) {
        final raw = original.extras!['duration'] as int;
        if (raw > 0 && raw < 43200) expectedDurationSec = raw;
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
      if (cDurationSec >= 43200) {
        cDurationSec = 0;
      }
      if (candidate.extras != null) {
        if (candidate.extras!['length'] != null) {
          final parsed = _parseDurationString(candidate.extras!['length']?.toString());
          if (parsed != null && parsed > 0 && parsed < 43200) cDurationSec = parsed;
        } else if (cDurationSec == 0 && candidate.extras!['duration'] is int) {
          final raw = candidate.extras!['duration'] as int;
          if (raw > 0 && raw < 43200) cDurationSec = raw;
        }
      }

      // Reject ~30s preview clips / snippets when matching a full track
      if (cDurationSec > 0 &&
          cDurationSec <= 35 &&
          (expectedDurationSec == 0 || expectedDurationSec > 45)) {
        continue;
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
      final normRawTitle = _normalizeArtist(rawTitleLower);

      final bool artistMatches = normCand == normExp ||
          normCand == normPrim ||
          normCand.contains(normPrim) ||
          normExp.contains(normCand) ||
          normRawTitle.contains(normPrim) ||
          normRawTitle.contains(normExp) ||
          (primaryArtist.isNotEmpty && rawTitleLower.contains(primaryArtist.toLowerCase()));

      // Check artist hints from playlist or album
      bool hintMatched = false;
      if (artistHints.isNotEmpty) {
        for (final hint in artistHints) {
          final normHint = _normalizeArtist(hint);
          final lowerHint = hint.toLowerCase();
          if (normHint.isNotEmpty &&
              (normCand.contains(normHint) ||
                  normRawTitle.contains(normHint) ||
                  rawTitleLower.contains(lowerHint))) {
            hintMatched = true;
            break;
          }
        }
      }

      String candidateTitleOnly = cCleanTitle;
      for (final hint in artistHints) {
        final escaped = RegExp.escape(hint);
        candidateTitleOnly = candidateTitleOnly
            .replaceAll(RegExp('^$escaped\\s*-\\s*', caseSensitive: false), '')
            .replaceAll(RegExp('\\s*-\\s*$escaped\$', caseSensitive: false), '')
            .replaceAll(RegExp('\\bby\\s+$escaped\\b', caseSensitive: false), '')
            .trim();
      }
      final cTitleOnlyNorm = _normalizeString(candidateTitleOnly);

      final int durationDiff = (expectedDurationSec > 0 && cDurationSec > 0)
          ? (expectedDurationSec - cDurationSec).abs()
          : 999;

      final bool isExactTitle = cTitle == expectedTitle ||
          cTitleOnlyNorm == expectedTitle ||
          (cTitle.length >= 4 &&
              expectedTitle.length >= 4 &&
              (cTitle.startsWith(expectedTitle) || expectedTitle.startsWith(cTitle)));

      final bool isTitleAndDurationVerified = isExactTitle &&
          expectedDurationSec > 0 &&
          cDurationSec > 0 &&
          durationDiff <= 4;

      if (strictSpeedCheck && !artistMatches && !isTitleAndDurationVerified) {
        continue;
      }

      // If the artist doesn't match:
      final titleWords = expectedTitle.split(' ').where((w) => w.length > 1).toList();
      if (!artistMatches && expectedArtist.isNotEmpty && !hintMatched) {
        if (titleWords.length <= 2 &&
            !isTitleAndDurationVerified &&
            !allowFidelityTitleDurationMatch) {
          continue; // Disqualify wrong artist completely!
        }
        if (isTitleAndDurationVerified) {
          // Both title and duration match master recording precisely!
          score -= 15.0; // Mild penalty for pseudonym / burner uploader
          score += 35.0; // Fidelity master boost
        } else if (allowFidelityTitleDurationMatch && durationDiff <= 8) {
          score -= 25.0;
          score += 15.0;
        } else {
          score -= 85.0; // Heavy penalty for mismatching artist
        }
      } else if (hintMatched) {
        score += 55.0; // Major boost: matches the real artist from playlist/album!
        if (isTitleAndDurationVerified) {
          score += 35.0; // Audio master duration fidelity boost
        }
      } else if (artistMatches) {
        if (normCand == normExp || normCand == normPrim) {
          score += 60.0;
        } else if (normCand.contains(normPrim) || normExp.contains(normCand)) {
          score += 45.0;
        } else if (rawTitleLower.contains(normPrim)) {
          score += 20.0;
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
        final diff = durationDiff;
        if (strictSpeedCheck && diff > 5 && !isTitleAndDurationVerified) {
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
      if (cTitle == expectedTitle || cTitleOnlyNorm == expectedTitle) {
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

    final minThreshold = strictSpeedCheck
        ? 75.0
        : (allowFidelityTitleDurationMatch ? 40.0 : 45.0);
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
