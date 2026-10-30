import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../../models/playlist.dart';
import '../../utils/helper.dart';
import '../player/player_controller.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '../utils/theme_controller.dart';
import 'add_to_playlist.dart';
import 'image_widget.dart';
import 'mini_equalizer.dart';
import 'snackbar.dart';
import 'songinfo_bottom_sheet.dart';

class SongListTile extends StatefulWidget {
  const SongListTile(
      {super.key,
      this.onTap,
      required this.song,
      this.playlist,
      this.isPlaylistOrAlbum = false,
      this.thumbReplacementWithIndex = false,
      this.index});

  final Playlist? playlist;
  final MediaItem song;
  final VoidCallback? onTap;
  final bool isPlaylistOrAlbum;

  /// Valid for Album songs
  final bool thumbReplacementWithIndex;
  final int? index;

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile>
    with RemoveSongFromPlaylistMixin {
  bool _isPressed = false;

  String _resolvePlatform(MediaItem song) {
    final p = song.extras?['platform']?.toString();
    if (p != null && p.isNotEmpty && p.toLowerCase() != 'null') {
      final pLow = p.toLowerCase();
      if (pLow == 'yt' || pLow == 'youtube music' || pLow == 'youtube') {
        return 'YouTube';
      }
      if (pLow == 'spotify' || pLow == 'sp') return 'Spotify';
      if (pLow == 'soundcloud' || pLow == 'sc') return 'SoundCloud';
      if (pLow == 'amazon' || pLow == 'amazon music' || pLow == 'az') {
        return 'Amazon Music';
      }
      return p;
    }
    if (song.id.startsWith('sc_') || song.extras?['isSoundCloud'] == true) {
      return 'SoundCloud';
    }
    if (song.id.startsWith('sp_') || song.extras?['isSpotify'] == true) {
      return 'Spotify';
    }
    if (song.id.startsWith('az_') || song.extras?['isAmazon'] == true) {
      return 'Amazon Music';
    }
    return 'YouTube';
  }

  Widget _buildPlatformBadge(String platform) {
    Color badgeColor;
    IconData badgeIcon;

    final lower = platform.toLowerCase();
    if (lower.contains('youtube') || lower == 'yt') {
      badgeColor = const Color(0xFFFF0055);
      badgeIcon = Icons.play_arrow_rounded;
    } else if (lower.contains('soundcloud') || lower == 'sc') {
      badgeColor = const Color(0xFFFF5500);
      badgeIcon = Icons.cloud_rounded;
    } else if (lower.contains('spotify') || lower == 'sp') {
      badgeColor = const Color(0xFF1DB954);
      badgeIcon = Icons.graphic_eq_rounded;
    } else if (lower.contains('amazon') || lower == 'az') {
      badgeColor = const Color(0xFF00A8E1);
      badgeIcon = Icons.music_note_rounded;
    } else {
      badgeColor = const Color(0xFF00D2FF);
      badgeIcon = Icons.music_note_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: badgeColor.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 10, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            platform,
            style: const TextStyle(
              fontSize: 9.5,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final isDesktop = GetPlatform.isDesktop;

    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons == kSecondaryMouseButton) {
          showModalBottomSheet(
            constraints: const BoxConstraints(maxWidth: 500),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
            ),
            isScrollControlled: true,
            context: playerController.homeScaffoldkey.currentState!.context,
            barrierColor: Colors.transparent.withAlpha(100),
            builder: (context) => SongInfoBottomSheet(
              widget.song,
              playlist: widget.playlist,
            ),
          ).whenComplete(() => Get.delete<SongInfoController>());
        }
      },
      child: Slidable(
        enabled:
            Get.find<SettingsScreenController>().slidableActionEnabled.isTrue,
        startActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (context) {
              showDialog(
                context: context,
                builder: (context) => AddToPlaylist([widget.song]),
              ).whenComplete(() => Get.delete<AddToPlaylistController>());
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).textTheme.titleMedium!.color,
            icon: Icons.playlist_add,
          ),
          if (widget.playlist != null && !widget.playlist!.isCloudPlaylist)
            SlidableAction(
              onPressed: (context) {
                removeSongFromPlaylist(widget.song, widget.playlist!);
              },
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).textTheme.titleMedium!.color,
              icon: Icons.delete,
            ),
        ]),
        endActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (context) {
              playerController.enqueueSong(widget.song).whenComplete(() {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(snackbar(
                    context, "songEnqueueAlert".tr,
                    size: SanckBarSize.MEDIUM));
              });
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).textTheme.titleMedium!.color,
            icon: Icons.merge,
          ),
          SlidableAction(
            onPressed: (context) {
              playerController.playNext(widget.song);
              ScaffoldMessenger.of(context).showSnackBar(snackbar(
                  context, "${"playnextMsg".tr} ${(widget.song).title}",
                  size: SanckBarSize.BIG));
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).textTheme.titleMedium!.color,
            icon: Icons.next_plan_outlined,
          ),
        ]),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            child: Obx(() {
              final isCurrent =
                  playerController.currentSong.value?.id == widget.song.id;
              final isPlaying = isCurrent &&
                  playerController.buttonState.value == PlayButtonState.playing;

              final customTheme =
                  Get.find<ThemeController>().activeCustomTheme.value;

              Decoration decoration;
              BorderRadius rowRadius;
              BorderRadius coverRadius;
              bool showLeftAccent = false;

              if (customTheme != null) {
                rowRadius = customTheme.isSignal
                    ? BorderRadius.zero
                    : BorderRadius.circular(
                        customTheme.radius > 20 ? 24 : customTheme.radius);
                coverRadius = customTheme.isSignal
                    ? BorderRadius.zero
                    : BorderRadius.circular(customTheme.radius > 20 ? 18 : 8);
                showLeftAccent = customTheme.isFlame || customTheme.isWarp;

                if (customTheme.isGlass) {
                  decoration = BoxDecoration(
                    color: isCurrent
                        ? customTheme.accent.withOpacity(0.22)
                        : (customTheme.glassFill ?? const Color(0x1AFFFFFF)),
                    borderRadius: rowRadius,
                    border: Border.all(
                      color: isCurrent
                          ? customTheme.accent
                          : (customTheme.glassBorder ?? const Color(0x4DFFFFFF)),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: customTheme.glassDropShadow ?? Colors.black26,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  );
                } else if (customTheme.isFlame) {
                  decoration = BoxDecoration(
                    color: isCurrent
                        ? customTheme.accent.withOpacity(0.2)
                        : (customTheme.cardColor ?? const Color(0xCC1E0A06)),
                    borderRadius: rowRadius,
                    border: Border.all(
                      color: isCurrent
                          ? customTheme.accent
                          : (customTheme.lineColor ?? const Color(0x4DFF6A00)),
                      width: 1.0,
                    ),
                    boxShadow: (_isPressed || isCurrent)
                        ? [
                            BoxShadow(
                              color: customTheme.accent.withOpacity(0.35),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  );
                } else if (customTheme.isWarp) {
                  decoration = BoxDecoration(
                    color: isCurrent
                        ? customTheme.accent.withOpacity(0.2)
                        : (customTheme.cardColor ?? const Color(0xB3081026)),
                    borderRadius: rowRadius,
                    border: Border.all(
                      color: isCurrent
                          ? customTheme.accent
                          : (customTheme.lineColor ?? const Color(0x3800F0FF)),
                      width: 1.0,
                    ),
                    boxShadow: (_isPressed || isCurrent)
                        ? [
                            BoxShadow(
                              color: customTheme.accent.withOpacity(0.35),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  );
                } else {
                  // Signal
                  decoration = BoxDecoration(
                    color: isCurrent
                        ? customTheme.accent.withOpacity(0.18)
                        : (customTheme.cardColor ?? const Color(0xFF0A0D0C)),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: isCurrent || _isPressed
                          ? customTheme.accent
                          : (customTheme.lineColor ?? const Color(0x29B8FF3C)),
                      width: 1.0,
                    ),
                  );
                }
              } else {
                rowRadius = BorderRadius.circular(12);
                coverRadius = BorderRadius.circular(8);
                decoration = BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF00D2FF).withOpacity(0.12)
                      : const Color(0xFF101322).withOpacity(0.55),
                  borderRadius: rowRadius,
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF00D2FF).withOpacity(0.65)
                        : Colors.white.withOpacity(0.06),
                    width: isCurrent ? 1.2 : 0.8,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                );
              }

              Widget tile = Stack(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: decoration,
                    child: ListTile(
                      onTap: widget.onTap,
                      onLongPress: () async {
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 500),
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(10.0)),
                          ),
                          isScrollControlled: true,
                          context: playerController
                              .homeScaffoldkey.currentState!.context,
                          barrierColor: Colors.transparent.withAlpha(100),
                          builder: (context) => SongInfoBottomSheet(
                            widget.song,
                            playlist: widget.playlist,
                          ),
                        ).whenComplete(() => Get.delete<SongInfoController>());
                      },
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: widget.thumbReplacementWithIndex
                          ? SizedBox(
                              width: 28,
                              height: 52,
                              child: Center(
                                child: Text(
                                  "${widget.index}.",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: coverRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: coverRadius,
                                child: ImageWidget(
                                  size: 52,
                                  song: widget.song,
                                ),
                              ),
                            ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 5),
                          id: widget.song.title.hashCode.toString(),
                          child: Text(
                            widget.song.title.length > 50
                                ? widget.song.title.substring(0, 50)
                                : widget.song.title,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? const Color(0xFF00D2FF)
                                      : null,
                                ),
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        MiniEqualizer(isPlaying: isPlaying, height: 12),
                      ],
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      _buildPlatformBadge(_resolvePlatform(widget.song)),
                      Expanded(
                        child: Text(
                          getSafeSongArtist(widget.song),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white60,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: (isDesktop || widget.isPlaylistOrAlbum) ? 80 : 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.song.extras?['length'] != null)
                          Text(
                            widget.song.extras?['length']?.toString() ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                          ),
                        if (isDesktop)
                          IconButton(
                            splashRadius: 16,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            onPressed: () {
                              showModalBottomSheet(
                                constraints:
                                    const BoxConstraints(maxWidth: 500),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10.0)),
                                ),
                                isScrollControlled: true,
                                context: playerController
                                    .homeScaffoldkey.currentState!.context,
                                barrierColor: Colors.transparent.withAlpha(100),
                                builder: (context) => SongInfoBottomSheet(
                                  widget.song,
                                  playlist: widget.playlist,
                                ),
                              ).whenComplete(
                                  () => Get.delete<SongInfoController>());
                            },
                            icon: const Icon(Icons.more_vert),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showLeftAccent && customTheme != null)
                    Positioned(
                      left: 6,
                      top: 3,
                      bottom: 3,
                      width: 3.5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: rowRadius.topLeft,
                          bottomLeft: rowRadius.bottomLeft,
                        ),
                        child: Container(color: customTheme.accent),
                      ),
                    ),
                ],
              );

              if (customTheme != null && customTheme.isWarp && _isPressed) {
                tile = Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..translate(6.0, 0.0, 0.0)
                    ..rotateY(-0.1),
                  child: tile,
                );
              }

              return tile;
            }),
          ),
        ),
      ),
    );
  }
}
