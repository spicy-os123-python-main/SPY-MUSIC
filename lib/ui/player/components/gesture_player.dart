import 'dart:math';
import 'dart:ui';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../../widgets/image_widget.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'animated_play_button.dart';
import 'player_mode_switch.dart';
import 'spy_video_player.dart';

class GesturePlayer extends StatelessWidget {
  const GesturePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    final double squareSize = min(size.width - 64, size.height - 360).clamp(180.0, 360.0);

    return Stack(
      children: [
        /// Solid dark background with swipe-down to close
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (DragEndDetails details) {
              final v = details.primaryVelocity ?? 0;
              if (v > 100) {
                playerController.playerPanelController.close();
              }
            },
            child: Container(
              color: const Color(0xFF070913),
            ),
          ),
        ),

        /// Top bar with minimize button and song options
        Padding(
          padding: EdgeInsets.only(
            top: Get.mediaQuery.padding.top + 16,
            left: 12,
            right: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.white),
                onPressed: playerController.playerPanelController.close,
              ),
              Expanded(
                child: Obx(
                  () => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playerController.playinfrom.value.typeString,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      Text(
                        "\"${playerController.playinfrom.value.nameString}\"",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 24, color: Colors.white),
                onPressed: () {
                  final song = playerController.currentSong.value;
                  if (song == null) return;
                  showModalBottomSheet(
                    constraints: const BoxConstraints(maxWidth: 500),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
                    ),
                    isScrollControlled: true,
                    context: playerController.homeScaffoldkey.currentState?.context ?? context,
                    barrierColor: Colors.transparent.withAlpha(100),
                    builder: (context) => SongInfoBottomSheet(
                      song,
                      calledFromPlayer: true,
                    ),
                  ).whenComplete(() => Get.delete<SongInfoController>());
                },
              ),
            ],
          ),
        ),

        /// Centered 4-cornered square box (Kasten 4-eckig) for the song image / video
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PlayerModeSwitch(),
                  GestureDetector(
                    onTap: () {
                      playerController.playPause();
                    },
                    onDoubleTap: () {
                      playerController.playPause();
                    },
                    onHorizontalDragEnd: (DragEndDetails details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v < -120) {
                        playerController.next();
                      } else if (v > 120) {
                        playerController.prev();
                      }
                    },
                    onVerticalDragEnd: (DragEndDetails details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v > 100) {
                        playerController.playerPanelController.close();
                      }
                    },
                    onLongPress: () {
                      final song = playerController.currentSong.value;
                      if (song == null) return;
                      showModalBottomSheet(
                        constraints: const BoxConstraints(maxWidth: 500),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
                        ),
                        isScrollControlled: true,
                        context: playerController.homeScaffoldkey.currentState?.context ?? context,
                        barrierColor: Colors.transparent.withAlpha(100),
                        builder: (context) => SongInfoBottomSheet(
                          song,
                          calledFromPlayer: true,
                        ),
                      ).whenComplete(() => Get.delete<SongInfoController>());
                    },
                    child: Container(
                      width: squareSize,
                      height: squareSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00D2FF).withOpacity(0.40),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withOpacity(0.35),
                            blurRadius: 26,
                            spreadRadius: 2,
                            offset: const Offset(-2, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF0055).withOpacity(0.30),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(2, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Obx(
                          () => (playerController.isVideoMode.isTrue &&
                                  playerController.isYouTubeSong(playerController.currentSong.value))
                              ? SpyVideoPlayer(size: squareSize)
                              : ImageWidget(
                                  size: squareSize,
                                  song: playerController.currentSong.value,
                                  isPlayerArtImage: true,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        /// Transient Play/Pause icon feedback on double-tap
        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Obx(
                () => FadeTransition(
                  opacity: playerController.gesturePlayerStateAnimation!,
                  child: playerController.gesturePlayerVisibleState.value == 2
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playerController.gesturePlayerVisibleState.value == 1
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),

        /// Bottom player controls panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: Get.mediaQuery.padding.bottom != 0
                  ? Get.mediaQuery.padding.bottom + 10
                  : 20,
              left: 20,
              right: 20,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF2080A14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF00D2FF).withOpacity(0.30),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF0055).withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Title & Artist marquee + Favorite button
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() {
                                    return Marquee(
                                      delay: const Duration(milliseconds: 300),
                                      duration: const Duration(seconds: 10),
                                      id: "${playerController.currentSong.value?.id ?? 'idle'}_title",
                                      child: Text(
                                        playerController.currentSong.value?.title ?? "NA",
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 4),
                                  Obx(() {
                                    return Marquee(
                                      delay: const Duration(milliseconds: 300),
                                      duration: const Duration(seconds: 10),
                                      id: "${playerController.currentSong.value?.id ?? 'idle'}_subtitle",
                                      child: Text(
                                        (playerController.currentSong.value?.artist != null &&
                                                playerController.currentSong.value?.artist != 'null' &&
                                                playerController.currentSong.value!.artist!.isNotEmpty)
                                            ? playerController.currentSong.value!.artist!
                                            : (playerController.currentSong.value?.extras?['artist'] ??
                                                playerController.currentSong.value?.extras?['searchQuery'] ??
                                                "unknownArtist".tr),
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            IconButton(
                              iconSize: 22,
                              onPressed: playerController.toggleFavourite,
                              icon: Obx(
                                () => Icon(
                                  playerController.isCurrentSongFav.isFalse
                                      ? Icons.favorite_border
                                      : Icons.favorite,
                                  color: playerController.isCurrentSongFav.isFalse
                                      ? Colors.white70
                                      : const Color(0xFFFF0055),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        /// Progress Bar
                        GetX<PlayerController>(builder: (controller) {
                          return ProgressBar(
                            thumbRadius: 6,
                            barHeight: 4,
                            baseBarColor: Colors.white24,
                            bufferedBarColor: Colors.white38,
                            progressBarColor: const Color(0xFF00D2FF),
                            thumbColor: const Color(0xFF00D2FF),
                            timeLabelTextStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            progress: controller.progressBarStatus.value.current,
                            total: controller.progressBarStatus.value.total,
                            buffered: controller.progressBarStatus.value.buffered,
                            onSeek: controller.seek,
                          );
                        }),

                        const SizedBox(height: 6),

                        /// Controls row with combined Play & Pause Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            /// Shuffle
                            IconButton(
                              iconSize: 20,
                              onPressed: playerController.toggleShuffleMode,
                              icon: Obx(
                                () => Icon(
                                  Ionicons.shuffle,
                                  color: playerController.isShuffleModeEnabled.value
                                      ? const Color(0xFF00D2FF)
                                      : Colors.white30,
                                ),
                              ),
                            ),

                            /// Previous Song
                            IconButton(
                              iconSize: 28,
                              icon: const Icon(Icons.skip_previous, color: Colors.white),
                              onPressed: playerController.prev,
                            ),

                            /// Combined Play & Pause Button in one button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF0055).withOpacity(0.55),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF00D2FF).withOpacity(0.40),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.transparent,
                                child: AnimatedPlayButton(key: Key("gesturePlayButton"), iconSize: 36),
                              ),
                            ),

                            /// Next Song
                            IconButton(
                              iconSize: 28,
                              icon: const Icon(Icons.skip_next, color: Colors.white),
                              onPressed: playerController.next,
                            ),

                            /// Loop (3-State)
                            Obx(() {
                              final isSongLoop = playerController.isLoopModeEnabled.value;
                              final isPlaylistLoop = playerController.isQueueLoopModeEnabled.value;
                              const activeColor = Color(0xFF00D2FF);

                              return IconButton(
                                iconSize: 20,
                                onPressed: playerController.cycleLoopMode,
                                icon: isSongLoop
                                    ? Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(Icons.all_inclusive,
                                              color: activeColor, size: 20),
                                          Positioned(
                                            right: -4,
                                            top: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(1.5),
                                              decoration: const BoxDecoration(
                                                color: activeColor,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                  minWidth: 11, minHeight: 11),
                                              child: const Center(
                                                child: Text(
                                                  '1',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(
                                        Icons.all_inclusive,
                                        color: isPlaylistLoop
                                            ? activeColor
                                            : Colors.white30,
                                        size: 20,
                                      ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        /// Absorb pointer at bottom edge
        Align(
          alignment: Alignment.bottomCenter,
          child: AbsorbPointer(
            child: SizedBox(
              height: Get.mediaQuery.padding.bottom + 10,
              child: Container(),
            ),
          ),
        ),
      ],
    );
  }
}
