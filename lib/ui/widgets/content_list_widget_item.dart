import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/album.dart';
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
    final isAlbum = widget.content is Album;
    final Album? album = isAlbum ? (widget.content as Album) : null;
    final Playlist? playlist = widget.content is Playlist ? (widget.content as Playlist) : null;
    final double itemW = widget.customWidth ?? 130.0;
    final double imgSize = (itemW - 10.0).clamp(65.0, 160.0);
    final double itemH = imgSize + 58.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (isAlbum && album != null) {
          Get.toNamed(ScreenNavigationSetup.albumScreen,
              id: ScreenNavigationSetup.id,
              arguments: (album, album.browseId));
          return;
        }
        if (playlist != null) {
          Get.toNamed(ScreenNavigationSetup.playlistScreen,
              id: ScreenNavigationSetup.id,
              arguments: [playlist, playlist.playlistId]);
        }
      },
      onLongPress: () {
        if (!isAlbum) {
          Playlist? p = playlist;
          if (p == null && widget.content != null) {
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
                            album: album,
                          )
                        : (playlist?.isCloudPlaylist ?? false) ||
                                !(playlist?.playlistId == 'LIBRP' ||
                                    playlist?.playlistId == 'LIBFAV' ||
                                    playlist?.playlistId == 'SongsCache' ||
                                    playlist?.playlistId == 'SongDownloads')
                            ? SizedBox.square(
                                dimension: imgSize,
                                child: Stack(
                              children: [
                                ImageWidget(
                                  size: imgSize,
                                  playlist: playlist ?? widget.content,
                                ),
                                if (playlist?.isPipedPlaylist ?? false)
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
                                if (!(playlist?.isCloudPlaylist ?? true))
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
                              playlist?.playlistId == 'LIBRP'
                                  ? Icons.history
                                  : playlist?.playlistId == 'LIBFAV'
                                      ? Icons.favorite
                                      : playlist?.playlistId == 'SongsCache'
                                          ? Icons.flight
                                          : Icons.download,
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.black87
                                  : Colors.white,
                              size: 40,
                            ))),
                  ),
                );
              }),
              const SizedBox(height: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAlbum
                          ? (album?.title ?? "")
                          : (playlist?.title ?? widget.content?.title?.toString() ?? ""),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                    ),
                    if (!widget.isLibraryItem)
                      Text(
                        isAlbum
                            ? "${(album?.artists != null && album!.artists!.isNotEmpty) ? (album.artists![0]['name'] ?? "") : ""} | ${album?.year ?? ""}"
                            : (playlist?.description ?? widget.content?.description?.toString() ?? ""),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 12.5,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color ??
                                      Colors.white60,
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
