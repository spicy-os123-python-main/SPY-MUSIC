import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/screens/Settings/settings_screen_controller.dart';

import '../../../models/music_source.dart';
import '../../../services/soundcloud_service.dart';
import '../../../services/platform_search_service.dart';
import '../../../utils/helper.dart';
import '../../widgets/platform_selector_widget.dart';
import '../Home/home_screen_controller.dart';
import '/services/music_service.dart';
import '/ui/widgets/sort_widget.dart';

class SearchResultScreenController extends GetxController
    with GetTickerProviderStateMixin {
  final navigationRailCurrentIndex = 0.obs;
  final isResultContentFetced = false.obs;
  final isSeparatedResultContentFetced = false.obs;
  final resultContent = <String, dynamic>{}.obs;
  final separatedResultContent = <String, dynamic>{}.obs;
  final musicServices = Get.find<MusicServices>();
  final queryString = ''.obs;
  final railItems = <String>[].obs;
  final railitemHeight = Get.size.height.obs;
  final additionalParamNext = {};
  bool continuationInProgress = false;
  TabController? tabController;
  bool isTabTransitionReversed = false;
  // ScrollControllers List
  final Map<String, ScrollController> scrollControllers = {};

  @override
  void onReady() {
    _getInitSearchResult();
    Get.find<HomeScreenController>().whenHomeScreenOnTop();
    super.onReady();
  }

  Future<void> onDestinationSelected(int value,
      {bool ignoreTabCommand = false}) async {
    if (railItems.isEmpty) {
      return;
    }

    isTabTransitionReversed = value > navigationRailCurrentIndex.value;
    isSeparatedResultContentFetced.value = false;
    navigationRailCurrentIndex.value = value;

    if (tabController != null && !ignoreTabCommand) {
      tabController?.animateTo(value);
    }

    if (value > 0 &&
        (!separatedResultContent.containsKey(railItems[value - 1]) ||
            separatedResultContent[railItems[value - 1]] == null ||
            separatedResultContent[railItems[value - 1]].isEmpty)) {
      final tabName = railItems[value - 1];

      // If initial result already had items for this tab, reuse them
      if (resultContent.containsKey(tabName) &&
          (resultContent[tabName] as List).isNotEmpty) {
        separatedResultContent[tabName] = List.from(resultContent[tabName]);
        isSeparatedResultContentFetced.value = true;
      } else {
        MusicSource selectedPlatform = MusicSource.all;
        if (Get.isRegistered<PlatformSelectorController>()) {
          selectedPlatform =
              Get.find<PlatformSelectorController>().selectedSource.value;
        }

        if (selectedPlatform == MusicSource.soundcloud ||
            selectedPlatform == MusicSource.spotify ||
            selectedPlatform == MusicSource.amazon) {
          separatedResultContent[tabName] = [];
        } else {
          final itemCount =
              (tabName == 'Songs' || tabName == 'Videos') ? 25 : 10;
          final x = await musicServices.search(queryString.value,
              filter: tabName.replaceAll(" ", "_").toLowerCase(),
              limit: itemCount,
              filterParams: resultContent['searchEndpoint'] != null
                  ? resultContent['searchEndpoint'][tabName]
                  : null);

          separatedResultContent[tabName] =
              x[tabName] ?? x["Songs"] ?? x["mixed"] ?? [];
          additionalParamNext[tabName] = x['params'];
        }
      }

      final scrollController = scrollControllers[tabName];
      if (scrollController != null) {
        scrollController.addListener(() {
          if (!scrollController.hasClients) return;
          double maxScroll = scrollController.position.maxScrollExtent;
          double currentScroll = scrollController.position.pixels;
          if (currentScroll >= maxScroll / 2 &&
              additionalParamNext[tabName] != null &&
              additionalParamNext[tabName]['additionalParams'] != null &&
              additionalParamNext[tabName]['additionalParams'] !=
                  '&ctoken=null&continuation=null') {
            if (!continuationInProgress) {
              continuationInProgress = true;
              getContinuationContents();
            }
          }
        });
      }
    }
    isSeparatedResultContentFetced.value = true;
  }

  Future<void> getContinuationContents() async {
    final tabName = railItems[navigationRailCurrentIndex.value - 1];

    if (additionalParamNext[tabName] == null) {
      continuationInProgress = false;
      return;
    }

    try {
      final x =
          await musicServices.getSearchContinuation(additionalParamNext[tabName]);
      final newItems = x[tabName] ?? x["Songs"] ?? [];
      if (newItems is List && newItems.isNotEmpty) {
        if (separatedResultContent[tabName] == null) {
          separatedResultContent[tabName] = [];
        }
        (separatedResultContent[tabName]).addAll(newItems);
      }
      additionalParamNext[tabName] = x['params'];
      separatedResultContent.refresh();
    } catch (_) {}

    continuationInProgress = false;
  }

  void viewAllCallback(String text) {
    onDestinationSelected(railItems.indexOf(text) + 1);
  }

  Future<void> _getInitSearchResult() async {
    isResultContentFetced.value = false;
    final args = Get.arguments;
    if (args != null) {
      queryString.value = args;
      String finalQuery = args;

      // Check if user has SoundCloud selected as platform
      MusicSource selectedPlatform = MusicSource.all;
      if (Get.isRegistered<PlatformSelectorController>()) {
        selectedPlatform =
            Get.find<PlatformSelectorController>().selectedSource.value;
      }

      if (selectedPlatform == MusicSource.soundcloud) {
        printINFO("Exclusive SoundCloud Search for: $finalQuery");
        final scTracks = await SoundCloudService().searchTracks(finalQuery);
        resultContent.value = {
          "Songs": scTracks,
        };
      } else if (selectedPlatform == MusicSource.spotify) {
        printINFO("Exclusive Spotify Search for: $finalQuery");
        final spTracks = await PlatformSearchService.searchSpotify(finalQuery);
        resultContent.value = {
          "Songs": spTracks,
        };
      } else if (selectedPlatform == MusicSource.amazon) {
        printINFO("Exclusive Amazon Search for: $finalQuery");
        final azTracks = await PlatformSearchService.searchAmazon(finalQuery);
        resultContent.value = {
          "Songs": azTracks,
        };
      } else if (selectedPlatform == MusicSource.youtube) {
        printINFO("Exclusive YouTube Search for: $finalQuery");
        resultContent.value = await musicServices.search(finalQuery);
        if (resultContent.isEmpty && args.toString().contains(" - ")) {
          final fallbackQuery = args.toString().split(" - ").last.trim();
          resultContent.value = await musicServices.search(fallbackQuery);
        }
      } else {
        printINFO("All Platforms Search for: $finalQuery");
        resultContent.value = await musicServices.search(finalQuery);
        if (resultContent.isEmpty && args.toString().contains(" - ")) {
          final fallbackQuery = args.toString().split(" - ").last.trim();
          resultContent.value = await musicServices.search(fallbackQuery);
        }

        // Seamless fallback to SoundCloud if YouTube had 0 results
        final songsList = resultContent["Songs"] as List?;
        if (songsList == null || songsList.isEmpty) {
          final scTracks = await SoundCloudService().searchTracks(finalQuery);
          if (scTracks.isNotEmpty) {
            resultContent["Songs"] = scTracks;
          }
        }
      }

      const preferredOrder = [
        "Artists",
        "Songs",
        "Videos",
        "Albums",
        "Featured playlists",
        "Community playlists"
      ];
      final allKeys = preferredOrder.where((k) => resultContent.containsKey(k));
      railItems.value = List<String>.from(allKeys);

      final len =
          railItems.where((element) => element.contains("playlists")).length;
      final calH = 30 + (railItems.length + 1 - len) * 123 + len * 150.0;
      railitemHeight.value =
          calH >= railitemHeight.value ? calH : railitemHeight.value;

      // ScrollControllers for list Continuation callback implementation
      for (String item in railItems) {
        scrollControllers[item] = ScrollController();
      }

      // Pre-seed separatedResultContent for each tab
      for (var element in railItems) {
        if (resultContent.containsKey(element) &&
            resultContent[element] is List) {
          separatedResultContent[element] = List.from(resultContent[element]);
        } else {
          separatedResultContent[element] = [];
        }
      }

      // Case if bottom nav used
      if (GetPlatform.isDesktop ||
          Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue) {
        // Tab controller for v2
        tabController =
            TabController(length: railItems.length + 1, vsync: this);

        tabController?.animation?.addListener(() {
          int indexChange = tabController!.offset.round();
          int index = tabController!.index + indexChange;

          if (index != navigationRailCurrentIndex.value) {
            onDestinationSelected(index, ignoreTabCommand: true);
          }
        });
      }
      isResultContentFetced.value = true;
    }
  }

  void onSort(SortType sortType, bool isAscending, String title) {
    if (separatedResultContent[title] == null ||
        separatedResultContent[title] is! List) return;

    if (title == "Songs" || title == "Videos") {
      final songList = List.from(separatedResultContent[title]);
      sortSongsNVideos(songList, sortType, isAscending);
      separatedResultContent[title] = songList;
    } else if (title.contains('playlists')) {
      final playlists = List.from(separatedResultContent[title]);
      sortPlayLists(playlists, sortType, isAscending);
      separatedResultContent[title] = playlists;
    } else if (title == "Artists") {
      final artistList = List.from(separatedResultContent[title]);
      sortArtist(artistList, sortType, isAscending);
      separatedResultContent[title] = artistList;
    } else if (title == "Albums") {
      final albumList = List.from(separatedResultContent[title]);
      sortAlbumNSingles(albumList, sortType, isAscending);
      separatedResultContent[title] = albumList;
    }
  }

  @override
  void onClose() {
    for (String item in railItems) {
      scrollControllers[item]?.dispose();
    }
    Get.find<HomeScreenController>().whenHomeScreenOnTop();
    tabController?.dispose();
    super.onClose();
  }
}
