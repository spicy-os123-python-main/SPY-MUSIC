import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/playlist.dart';
import '../navigator.dart';
import '../utils/theme_controller.dart';
import 'image_widget.dart';
import 'playlist_options_bottom_sheet.dart';

class ContentListItem extends StatefulWidget {
  const ContentListItem(
      {super.key, required this.content, this.isLibraryItem = false, this.customWidth});

  ///content will be of Type class Album or Playlist
  final dynamic content;
  final bool isLibraryItem;
  final double? customWidth;

  @override
  State<ContentListItem> createState() => _ContentListItemState();
}

class _ContentListItemState extends State<ContentListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isAlbum = widget.content.runtimeType.toString() == "Album";
    final double itemW = widget.customWidth ?? 130.0;
    final double imgSize = (itemW - 10.0).clamp(65.0, 160.0);
    final double itemH = imgSize + 58.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (isAlbum) {
          Get.toNamed(ScreenNavigationSetup.albumScreen,
              id: ScreenNavigationSetup.id,
              arguments: (widget.content, widget.content.browseId));
          return;
        }
        Get.toNamed(ScreenNavigationSetup.playlistScreen,
            id: ScreenNavigationSetup.id,
            arguments: [widget.content, widget.content.playlistId]);
      },
      onLongPress: () {
        if (!isAlbum) {
          Playlist? p;
          if (widget.content is Playlist) {
            p = widget.content as Playlist;
          } else if (widget.content != null) {
            try {
              p = Playlist.fromJson(widget.content);
            } catch (_) {}
          }
          if (p != null) {
            PlaylistOptionsBottomSheet.show(
              context: context,
              playlist: p,
            );
          }
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: itemW,
          height: itemH,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final customTheme =
                    Get.find<ThemeController>().activeCustomTheme.value;

                Decoration decoration;
                BorderRadius radius;

                if (customTheme != null) {
                  radius = customTheme.isSignal
                      ? BorderRadius.zero
                      : BorderRadius.circular(
                          customTheme.radius > 20 ? 24 : customTheme.radius);

                  if (customTheme.isGlass) {
                    decoration = BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: customTheme.glassBorder ?? const Color(0x4DFFFFFF),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: customTheme.glassDropShadow ?? Colors.black26,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    );
                  } else if (customTheme.isFlame) {
                    decoration = BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: customTheme.accent,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: customTheme.accent.withOpacity(0.4),
                          blurRadius: 18,
                        ),
                      ],
                    );
                  } else if (customTheme.isWarp) {
                    decoration = BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: customTheme.accent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: customTheme.accent.withOpacity(0.35),
                          blurRadius: 14,
                        ),
                      ],
                    );
                  } else {
                    decoration = BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: customTheme.lineColor ?? const Color(0x29B8FF3C),
                        width: 1.0,
                      ),
                    );
                  }
                } else {
                  radius = BorderRadius.circular(12);
                  decoration = BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D2FF).withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  );
                }

                return Container(
                  decoration: decoration,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: isAlbum
                        ? ImageWidget(
                            size: imgSize,
                            album: widget.content,
                          )
                        : widget.content.isCloudPlaylist ||
                                !(widget.content.playlistId == 'LIBRP' ||
                                    widget.content.playlistId == 'LIBFAV' ||
                                    widget.content.playlistId == 'SongsCache' ||
                                    widget.content.playlistId == 'SongDownloads')
                            ? SizedBox.square(
                                dimension: imgSize,
                                child: Stack(
                              children: [
                                ImageWidget(
                                  size: imgSize,
                                  playlist: widget.content,
                                ),
                                if (widget.content.isPipedPlaylist)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        height: 18,
                                        width: 18,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(5),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                        child: Center(
                                            child: Text(
                                          "P",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .copyWith(fontSize: 14),
                                        )),
                                      ),
                                    ),
                                  ),
                                if (!widget.content.isCloudPlaylist)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        height: 18,
                                        width: 18,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(5),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                        child: Center(
                                            child: Text(
                                          "L",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .copyWith(fontSize: 14),
                                        )),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          )
                        : Container(
                            height: imgSize,
                            width: imgSize,
                            decoration: BoxDecoration(
                                color: Theme.of(context).primaryColorLight,
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                                child: Icon(
                              widget.content.playlistId == 'LIBRP'
                                  ? Icons.history
                                  : widget.content.playlistId == 'LIBFAV'
                                      ? Icons.favorite
                                      : widget.content.playlistId == 'SongsCache'
                                          ? Icons.flight
                                          : Icons.download,
                              color: Colors.white,
                              size: 40,
                            ))),
                  ),
                );
              }),
              const SizedBox(height: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.content.title,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      isAlbum
                          ? widget.isLibraryItem
                              ? ""
                              : "${widget.content.artists[0]['name'] ?? ""} | ${widget.content.year ?? ""}"
                          : widget.isLibraryItem
                              ? ""
                              : widget.content.description ?? "",
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
