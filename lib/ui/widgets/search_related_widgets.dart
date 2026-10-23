import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/Search/search_result_screen_controller.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';
import '/ui/widgets/content_list_widget.dart';
import 'separate_tab_item_widget.dart';

class ResultWidget extends StatelessWidget {
  const ResultWidget({super.key, this.isv2Used = false});
  final bool isv2Used;

  @override
  Widget build(BuildContext context) {
    final SearchResultScreenController searchResScrController =
        Get.find<SearchResultScreenController>();
    final topPadding = context.isLandscape ? 50.0 : 80.0;
    return Obx(
      () => Center(
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: SingleChildScrollView(
            padding:
                EdgeInsets.only(bottom: 200, top: isv2Used ? 0 : topPadding),
            child: searchResScrController.isResultContentFetced.value
                ? Column(children: [
                    if (!isv2Used)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "searchRes".tr,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    if (!isv2Used)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "${"for1".tr} \"${searchResScrController.queryString.value}\"",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(
                      height: 10,
                    ),
                    ...generateWidgetList(searchResScrController),
                  ])
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  List<Widget> generateWidgetList(
      SearchResultScreenController searchResScrController) {
    List<Widget> list = [];
    final content = searchResScrController.resultContent;

    // 1. Top Result Artists
    if (content.containsKey("Artists") &&
        content["Artists"] is List &&
        (content["Artists"] as List).isNotEmpty) {
      list.add(SeparateTabItemWidget(
        items: List<Artist>.from(content["Artists"]),
        title: "Artists",
        isCompleteList: false,
      ));
    }

    // 2. Songs
    if (content.containsKey("Songs") &&
        content["Songs"] is List &&
        (content["Songs"] as List).isNotEmpty) {
      list.add(SeparateTabItemWidget(
        items: List<MediaItem>.from(content["Songs"]),
        title: "Songs",
        isCompleteList: false,
      ));
    }

    // 3. Videos
    if (content.containsKey("Videos") &&
        content["Videos"] is List &&
        (content["Videos"] as List).isNotEmpty) {
      list.add(SeparateTabItemWidget(
        items: List<MediaItem>.from(content["Videos"]),
        title: "Videos",
        isCompleteList: false,
      ));
    }

    // 4. Albums
    if (content.containsKey("Albums") &&
        content["Albums"] is List &&
        (content["Albums"] as List).isNotEmpty) {
      list.add(ContentListWidget(
        content: AlbumContent(
            title: "Albums", albumList: List<Album>.from(content["Albums"])),
        isHomeContent: false,
      ));
    }

    // 5. Playlists (Community and Featured)
    for (String key in ["Featured playlists", "Community playlists"]) {
      if (content.containsKey(key) &&
          content[key] is List &&
          (content[key] as List).isNotEmpty) {
        list.add(ContentListWidget(
          content: PlaylistContent(
            title: key,
            playlistList: List<Playlist>.from(content[key]),
          ),
          isHomeContent: false,
        ));
      }
    }

    return list;
  }
}
