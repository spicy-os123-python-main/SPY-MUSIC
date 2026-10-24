// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../services/discord_webhook_service.dart';

import '/ui/navigator.dart';
import '/ui/widgets/sort_widget.dart';

void printERROR(dynamic text, {String tag = "SPY MUSIC"}) {
  // Release logs enabled for troubleshooting via adb logcat -s flutter
  print("\x1B[31m[$tag ERROR]: $text\x1B[0m");

  // Send errors to configured Discord webhook
  DiscordWebhookService.sendError(text, tag: tag);
}

void printWarning(dynamic text, {String tag = 'SPY MUSIC'}) {
  print("\x1B[33m[$tag WARN]: $text\x1B[34m");
}

void printINFO(dynamic text, {String tag = 'SPY MUSIC'}) {
  print("\x1B[32m[$tag INFO]: $text\x1B[34m");
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
        if (a.extras!['date'] == null || b.extras!['date'] == null) {
          return 0.compareTo(0);
        }
        return a.extras!['date'].compareTo(b.extras!['date']);
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

/// Checks GitHub tags and returns full update details
Future<Map<String, dynamic>> checkAppUpdateDetails({String? currentVer}) async {
  try {
    currentVer ??= "v1.0.0";
    final response = await Dio().get(
      "https://api.github.com/repos/spicy-os123-python-main/SPY-MUSIC/tags",
      options: Options(
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    final tags = response.data as List;
    if (tags.isEmpty) {
      return {'hasUpdate': false, 'latest': currentVer, 'current': currentVer};
    }
    final latestTag = tags[0]['name'] as String;

    final cleanCurrent = currentVer.toLowerCase().replaceAll('v', '').trim();
    final cleanLatest = latestTag.toLowerCase().replaceAll('v', '').trim();

    final curParts =
        cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latParts =
        cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (curParts.length < 3) {
      curParts.add(0);
    }
    while (latParts.length < 3) {
      latParts.add(0);
    }

    bool hasUpdate = false;
    for (int i = 0; i < 3; i++) {
      if (latParts[i] > curParts[i]) {
        hasUpdate = true;
        break;
      } else if (latParts[i] < curParts[i]) {
        break;
      }
    }

    return {
      'hasUpdate': hasUpdate,
      'latest': latestTag,
      'current': currentVer,
    };
  } catch (e) {
    printERROR("checkAppUpdateDetails error: $e");
    return {
      'hasUpdate': false,
      'error': e.toString(),
      'latest': currentVer ?? "v1.0.0",
      'current': currentVer ?? "v1.0.0",
    };
  }
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
