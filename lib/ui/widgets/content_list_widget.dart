import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/Search/search_result_screen_controller.dart';
import '/ui/widgets/content_list_widget_item.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';

class ContentListWidget extends StatelessWidget {
  ///ContentListWidget is used to render a section of Content like a list of Albums or Playlists in HomeScreen
  const ContentListWidget(
      {super.key,
      this.content,
      this.isHomeContent = true,
      this.scrollController});

  ///content will be of class Type AlbumContent or PlaylistContent
  final dynamic content;
  final bool isHomeContent;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final AlbumContent? albumContent =
        content is AlbumContent ? content as AlbumContent : null;
    final PlaylistContent? playlistContent =
        content is PlaylistContent ? content as PlaylistContent : null;

    final String contentTitle = albumContent?.title ??
        playlistContent?.title ??
        (content != null ? (content.title?.toString() ?? "") : "");

    final int listLength = albumContent?.albumList.length ??
        playlistContent?.playlistList.length ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  !isHomeContent && contentTitle.length > 12
                      ? "${contentTitle.substring(0, 12)}..."
                      : contentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              !isHomeContent
                  ? TextButton(
                      onPressed: () {
                        final scrresController =
                            Get.find<SearchResultScreenController>();
                        scrresController.viewAllCallback(contentTitle);
                      },
                      child: Text("viewAll".tr,
                          style: Theme.of(Get.context!).textTheme.titleSmall))
                  : const SizedBox.shrink()
            ],
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 200,
          //color: Colors.blueAccent,
          child: Scrollbar(
            thickness: GetPlatform.isDesktop ? null : 0,
            controller: scrollController,
            child: ListView.separated(
                controller: scrollController,
                addAutomaticKeepAlives: false, //Testing going
                addRepaintBoundaries: false, //on this
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (context, index) => const SizedBox(
                      width: 15,
                    ),
                scrollDirection: Axis.horizontal,
                itemCount: listLength,
                itemBuilder: (_, index) {
                  if (albumContent != null) {
                    final album = albumContent.albumList[index];
                    return ContentListItem(content: album);
                  }
                  if (playlistContent != null) {
                    final playlist = playlistContent.playlistList[index];
                    return ContentListItem(content: playlist);
                  }
                  return const SizedBox.shrink();
                }),
          ),
        ),
      ],
    );
  }
}
