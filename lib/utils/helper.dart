// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../services/app_log_service.dart';
import '../services/discord_webhook_service.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import 'app_version.dart';

import '/ui/navigator.dart';
import '/ui/widgets/sort_widget.dart';

void printERROR(dynamic text, {String tag = "SPY MUSIC"}) {
  // Release logs enabled for troubleshooting via adb logcat -s flutter
  print("\x1B[31m[$tag ERROR]: $text\x1B[0m");

  // Keep in in-memory diagnostics buffer for 1-tap copying / sharing
  AppLogService.add('ERROR', text, tag: tag);

  // Send errors to configured Discord webhook
  DiscordWebhookService.sendError(text, tag: tag);
}

void printWarning(dynamic text, {String tag = 'SPY MUSIC'}) {
  print("\x1B[33m[$tag WARN]: $text\x1B[34m");
  AppLogService.add('WARN', text, tag: tag);
}

void printINFO(dynamic text, {String tag = 'SPY MUSIC'}) {
  print("\x1B[32m[$tag INFO]: $text\x1B[34m");
  AppLogService.add('INFO', text, tag: tag);
}

String? getCurrentRouteName() {
  String? currentPath;
  Get.nestedKey(ScreenNavigationSetup.id)?.currentState?.popUntil((route) {
    currentPath = route.settings.name;
    return true;
  });
  return currentPath;
}

void sortSongsNVideos(
  List songlist,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Date:
      compareFunction = (a, b) {
        final aDate = a.extras?['date'];
        final bDate = b.extras?['date'];
        if (aDate == null || bDate == null) {
          return 0.compareTo(0);
        }
        return aDate.compareTo(bDate);
      };
      break;
    case SortType.Duration:
      compareFunction = (a, b) =>
          (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero);
    case SortType.Name:
    default:
      compareFunction =
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      break;
  }

  songlist.sort(compareFunction);

  if (!isAscending) {
    List reversed = songlist.reversed.toList();
    songlist.clear();
    songlist.addAll(reversed);
  }
}

void sortAlbumNSingles(
  List albumList,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Date:
      compareFunction =
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      break;
    case SortType.Name:
    default:
      compareFunction = (a, b) {
        if (a.year == null || b.year == null) {
          return 0.compareTo(0);
        }
        return a.year!.compareTo(b.year!);
      };
      break;
  }

  albumList.sort(compareFunction);

  if (!isAscending) {
    List reversed = albumList.reversed.toList();
    albumList.clear();
    albumList.addAll(reversed);
  }
}

void sortPlayLists(
  List playlists,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;
  int titleSort(a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());

  switch (sortType) {
    case SortType.RecentlyPlayed:
      compareFunction = (a, b) {
        DateTime? alp = a.lastPlayed;
        DateTime? blp = b.lastPlayed;
        if (alp == null && blp == null) {
          return titleSort(a, b);
        }
        if (alp == null) {
          return 1;
        }
        if (blp == null) {
          return -1;
        }
        return blp.compareTo(alp);
      };
      break;
    case SortType.Name:
    default:
      compareFunction = titleSort;
      break;
  }

  playlists.sort(compareFunction);

  if (!isAscending) {
    List reversed = playlists.reversed.toList();
    playlists.clear();
    playlists.addAll(reversed);
  }
}

void sortArtist(
  List artistList,
  SortType sortType,
  bool isAscending,
) {
  Comparator compareFunction;

  switch (sortType) {
    case SortType.Name:
    default:
      compareFunction =
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
      break;
  }

  artistList.sort(compareFunction);

  if (!isAscending) {
    List reversed = artistList.reversed.toList();
    artistList.clear();
    artistList.addAll(reversed);
  }
}

/// Checks GitHub releases and returns full update details
Future<Map<String, dynamic>> checkAppUpdateDetails({String? currentVer}) async {
  currentVer ??= AppVersion.value;
  if (currentVer.trim().isEmpty || currentVer == "v1.0.0") {
    currentVer = AppVersion.value;
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'SPY-MUSIC-App/1.0',
        'Accept': 'application/vnd.github.v3+json',
      },
    ),
  );

  String latestTag = currentVer;
  String body = "";
  String htmlUrl =
      "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest";
  String downloadUrl =
      "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/spymusic-arm64-v8a.apk";
  String universalUrl =
      "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/spymusic.apk";
  String ipaUrl =
      "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/SPY-MUSIC.ipa";
  String? updatedAt;
  bool requestSucceeded = false;
  String? errorMsg;

  // 1. Primary: Official GitHub REST API
  try {
    final response = await dio.get(
      "https://api.github.com/repos/spicy-os123-python-main/SPY-MUSIC/releases/latest",
    );
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map;
      latestTag = data['tag_name']?.toString() ?? currentVer;
      body = data['body']?.toString() ?? '';
      htmlUrl = data['html_url']?.toString() ?? htmlUrl;
      updatedAt = data['published_at']?.toString() ?? data['updated_at']?.toString();
      final assets = data['assets'] as List? ?? [];
      for (var a in assets) {
        final name = a['name']?.toString() ?? '';
        final download = a['browser_download_url']?.toString();
        if (download != null) {
          if (name.contains('arm64-v8a') && name.endsWith('.apk')) {
            downloadUrl = download;
          } else if (name == 'spymusic.apk' ||
              (name.endsWith('.apk') && !name.contains('arm'))) {
            universalUrl = download;
          } else if (name.endsWith('.ipa')) {
            ipaUrl = download;
          }
        }
      }
      requestSucceeded = true;
    }
  } catch (e) {
    printWarning("GitHub releases/latest API unavailable: $e");
    errorMsg = e.toString();
  }

  // 2. Fallback: GitHub web redirect (bypasses GitHub API 60 req/hr rate limits)
  if (!requestSucceeded) {
    try {
      final redirectDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10)'},
        ),
      );
      final res = await redirectDio.get(
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest",
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      String? location = res.headers.value('location');
      if (location == null && res.realUri.toString().contains('/releases/tag/')) {
        location = res.realUri.toString();
      }
      if (location != null && location.contains('/releases/tag/')) {
        final extractedTag = location
            .split('/releases/tag/')
            .last
            .split('?')
            .first
            .split('#')
            .first
            .trim();
        if (extractedTag.isNotEmpty) {
          latestTag = extractedTag.startsWith('v') ? extractedTag : 'v$extractedTag';
          htmlUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/tag/$latestTag";
          downloadUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/spymusic-arm64-v8a.apk";
          universalUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/spymusic.apk";
          ipaUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/SPY-MUSIC.ipa";
          requestSucceeded = true;
          errorMsg = null;
        }
      }
    } catch (e) {
      printWarning("GitHub web redirect fallback unavailable: $e");
      errorMsg ??= e.toString();
    }
  }

  // 3. Fallback: GitHub tags endpoint
  if (!requestSucceeded) {
    try {
      final tagsRes = await dio.get(
        "https://api.github.com/repos/spicy-os123-python-main/SPY-MUSIC/tags",
      );
      if (tagsRes.statusCode == 200 && tagsRes.data is List) {
        final tags = tagsRes.data as List;
        if (tags.isNotEmpty) {
          final firstTag = tags[0]['name']?.toString() ?? currentVer;
          latestTag = firstTag.startsWith('v') ? firstTag : 'v$firstTag';
          htmlUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/tag/$latestTag";
          downloadUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/spymusic-arm64-v8a.apk";
          universalUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/spymusic.apk";
          ipaUrl =
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/$latestTag/SPY-MUSIC.ipa";
          requestSucceeded = true;
          errorMsg = null;
        }
      }
    } catch (e) {
      printWarning("GitHub tags fallback unavailable: $e");
      errorMsg ??= e.toString();
    }
  }

  final bool hasUpdate = AppVersion.isNewer(latestTag, currentVer);

  return {
    'hasUpdate': hasUpdate,
    'success': requestSucceeded,
    'error': requestSucceeded ? null : errorMsg,
    'latest': latestTag,
    'current': currentVer,
    'body': body,
    'htmlUrl': htmlUrl,
    'downloadUrl': downloadUrl,
    'universalUrl': universalUrl,
    'ipaUrl': ipaUrl,
    'updatedAt': updatedAt,
  };
}

/// Return true if new version available
Future<bool> newVersionCheck(String currentVersion) async {
  try {
    final details = await checkAppUpdateDetails(currentVer: currentVersion);
    return details['hasUpdate'] == true;
  } catch (e) {
    return false;
  }
}

bool isValidArtist(dynamic val) {
  if (val == null) return false;
  final s = val.toString().trim();
  final lower = s.toLowerCase();
  return s.isNotEmpty &&
      lower != 'null' &&
      lower != 'na' &&
      lower != 'n/a' &&
      lower != 'undefined';
}

String? extractArtistName(dynamic val) {
  if (val == null) return null;
  if (val is String) {
    if (isValidArtist(val)) return val.trim();
    return null;
  }
  if (val is Map) {
    final name = val['name'] ?? val['text'] ?? val['artist'];
    if (name != null && isValidArtist(name)) {
      return name.toString().trim();
    }
  }
  if (val is List) {
    final names = val
        .map((e) => extractArtistName(e))
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      return names.join(', ');
    }
  }
  return null;
}

String getSafeSongArtist(dynamic song, {String? fallback}) {
  bool isDe = false;
  try {
    if (Get.isRegistered<SettingsScreenController>()) {
      isDe = Get.find<SettingsScreenController>().currentAppLanguageCode.value ==
          'de';
    } else {
      isDe = (Get.locale?.languageCode ?? 'en') == 'de';
    }
  } catch (_) {
    isDe = (Get.locale?.languageCode ?? 'en') == 'de';
  }
  final defaultFallback =
      fallback ?? (isDe ? 'Unbekannter Künstler' : 'Unknown Artist');

  if (song == null) return defaultFallback;

  // 1. Direct song.artist
  try {
    final a = song.artist?.toString();
    if (isValidArtist(a)) return a!.trim();
  } catch (_) {}

  // 2. song.extras?['artist'] (can be String, Map, or List)
  try {
    final a = extractArtistName(song.extras?['artist']);
    if (a != null && a.isNotEmpty) return a;
  } catch (_) {}

  // 3. song.extras?['artists'] (List of Maps, List of Strings, or String)
  try {
    final a = extractArtistName(song.extras?['artists']);
    if (a != null && a.isNotEmpty) return a;
  } catch (_) {}

  // 4. song.extras?['author'] or uploaderName or uploader or channel
  try {
    final a = extractArtistName(song.extras?['author'] ??
        song.extras?['uploaderName'] ??
        song.extras?['uploader'] ??
        song.extras?['channelTitle'] ??
        song.extras?['channel']);
    if (a != null && a.isNotEmpty) return a;
  } catch (_) {}

  // 5. song.extras?['subtitle']
  try {
    final sub = song.extras?['subtitle']?.toString();
    if (isValidArtist(sub)) {
      final parts = sub!.split('•');
      final candidate = parts.first.trim();
      if (isValidArtist(candidate)) return candidate;
    }
  } catch (_) {}

  // 6. song.extras?['searchQuery']
  try {
    final sq = song.extras?['searchQuery']?.toString();
    if (isValidArtist(sq)) {
      final title = song.title?.toString().trim() ?? '';
      if (title.isNotEmpty && sq!.toLowerCase().startsWith(title.toLowerCase())) {
        final rem = sq.substring(title.length).trim();
        if (isValidArtist(rem)) return rem;
      }
      return sq!.trim();
    }
  } catch (_) {}

  // 7. song.album fallback if not generic
  try {
    final album = song.album?.toString();
    if (isValidArtist(album) &&
        album != song.title?.toString() &&
        album != 'SoundCloud' &&
        album != 'YouTube' &&
        album != 'Spotify' &&
        album != 'Amazon') {
      return album!.trim();
    }
  } catch (_) {}

  return defaultFallback;
}

String getTimeString(Duration time) {
  final minutes = time.inMinutes.remainder(Duration.minutesPerHour).toString();
  final seconds = time.inSeconds
      .remainder(Duration.secondsPerMinute)
      .toString()
      .padLeft(2, '0');
  return time.inHours > 0
      ? "${time.inHours}:${minutes.padLeft(2, "0")}:$seconds"
      : "$minutes:$seconds";
}
