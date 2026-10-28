import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/player/components/animated_play_button.dart';
import '../player_controller.dart';

class PlayerControlWidget extends StatelessWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.transparent
                      ],
                    ).createShader(
                        Rect.fromLTWH(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Obx(() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 10),
                          id: "${playerController.currentSong.value}_title",
                          child: Text(
                            playerController.currentSong.value?.title ?? "NA",
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.labelMedium ??
                                const TextStyle(
                                    fontSize: 23, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Marquee(
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
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      ],
                    );
                  }),
                ),
              ),
              SizedBox(
                width: 45,
                child: IconButton(
                    onPressed: playerController.toggleFavourite,
                    icon: Obx(() => Icon(
                          playerController.isCurrentSongFav.isFalse
                              ? Icons.favorite_border
                              : Icons.favorite,
                          color: Theme.of(context).textTheme.titleMedium?.color ??
                              Colors.white,
                        ))),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          GetX<PlayerController>(builder: (controller) {
            return ProgressBar(
              thumbRadius: 7,
              barHeight: 4.5,
              baseBarColor: Theme.of(context).sliderTheme.inactiveTrackColor,
              bufferedBarColor:
                  Theme.of(context).sliderTheme.valueIndicatorColor,
              progressBarColor: Theme.of(context).sliderTheme.activeTrackColor,
              thumbColor: Theme.of(context).sliderTheme.thumbColor,
              timeLabelTextStyle: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontSize: 14),
              progress: controller.progressBarStatus.value.current,
              total: controller.progressBarStatus.value.total,
              buffered: controller.progressBarStatus.value.buffered,
              onSeek: controller.seek,
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: playerController.toggleShuffleMode,
                  icon: Obx(() => Icon(
                        Ionicons.shuffle,
                        color: playerController.isShuffleModeEnabled.value
                            ? (Theme.of(context).textTheme.titleLarge?.color ??
                                Colors.white)
                            : (Theme.of(context).textTheme.titleLarge?.color ??
                                    Colors.white)
                                .withOpacity(0.2),
                      ))),
              _previousButton(playerController, context),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0055).withOpacity(0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00D2FF).withOpacity(0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.transparent,
                  child: AnimatedPlayButton(key: Key("playButton")),
                ),
              ),
              _nextButton(playerController, context),
              Obx(() {
                final isSongLoop = playerController.isLoopModeEnabled.value;
                final isPlaylistLoop = playerController.isQueueLoopModeEnabled.value;
                const activeColor = Color(0xFF00D2FF);
                final inactiveColor = (Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white)
                    .withOpacity(0.2);

                return IconButton(
                  onPressed: playerController.cycleLoopMode,
                  tooltip: isSongLoop
                      ? "Song unendlich wiederholen"
                      : (isPlaylistLoop
                          ? "Playlist unendlich wiederholen"
                          : "Wiederholen aus"),
                  icon: isSongLoop
                      ? Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.all_inclusive,
                              color: activeColor,
                              size: 26,
                            ),
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
                                    minWidth: 12, minHeight: 12),
                                child: const Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 8.5,
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
                          color: isPlaylistLoop ? activeColor : inactiveColor,
                          size: 26,
                        ),
                );
              }),
            ],
          ),
        ]);
  }


  Widget _previousButton(
      PlayerController playerController, BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous,
        color: Theme.of(context).textTheme.titleMedium?.color ?? Colors.white,
      ),
      iconSize: 30,
      onPressed: playerController.prev,
    );
  }
}

Widget _nextButton(PlayerController playerController, BuildContext context) {
  return Obx(() {
    final isLastSong = playerController.currentQueue.isEmpty ||
        (!(playerController.isShuffleModeEnabled.isTrue ||
                playerController.isQueueLoopModeEnabled.isTrue) &&
            (playerController.currentQueue.last.id ==
                playerController.currentSong.value?.id));
    final titleLargeColor =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final titleMediumColor =
        Theme.of(context).textTheme.titleMedium?.color ?? Colors.white;
    return IconButton(
        icon: Icon(
          Icons.skip_next,
          color: isLastSong
              ? titleLargeColor.withOpacity(0.2)
              : titleMediumColor,
        ),
        iconSize: 30,
        onPressed: isLastSong ? null : playerController.next);
  });
}
