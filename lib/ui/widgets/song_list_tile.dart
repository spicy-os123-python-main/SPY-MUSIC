import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../../models/playlist.dart';
import '../../models/music_source.dart';
import 'platform_selector_widget.dart';
import '../player/player_controller.dart';
import '../screens/Settings/settings_screen_controller.dart';
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

  String? _resolvePlatform(MediaItem song) {
    final p = song.extras?['platform']?.toString();
    if (p != null && p.isNotEmpty) {
      if (p.toLowerCase() == 'yt' || p.toLowerCase() == 'youtube music') return 'YouTube';
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
    // If in All-In-One search mode, default tracks without prefix are YouTube
    bool isAllInOne = false;
    try {
      if (Get.isRegistered<PlatformSelectorController>()) {
        isAllInOne = Get.find<PlatformSelectorController>().selectedSource.value ==
            MusicSource.all;
      }
    } catch (_) {}
    if (isAllInOne) {
      return 'YouTube';
    }
    return null;
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

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF00D2FF).withOpacity(0.12)
                      : const Color(0xFF101322).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
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
                ),
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
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                      Builder(builder: (context) {
                        final platform = _resolvePlatform(widget.song);
                        if (platform != null && platform.isNotEmpty) {
                          return _buildPlatformBadge(platform);
                        }
                        return const SizedBox.shrink();
                      }),
                      Expanded(
                        child: Text(
                          "${widget.song.artist}",
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
                          )
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
