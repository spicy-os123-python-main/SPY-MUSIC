import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/screens/Settings/settings_screen_controller.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/song_info_dialog.dart';
import '/ui/player/player_controller.dart';
import '/utils/helper.dart';
import '../../widgets/add_to_playlist.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/song_download_btn.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/mini_player_progress_bar.dart';
import 'animated_play_button.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 800;
    final bottomNavEnabled = Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue;
    return Obx(() {
      return Visibility(
        visible: playerController.isPlayerpanelTopVisible.value,
        child: AnimatedOpacity(
          opacity: playerController.playerPaneOpacity.value,
          duration: Duration.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: playerController.playerPanelController.open,
            onHorizontalDragEnd: (DragEndDetails details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -80) {
                playerController.next();
              } else if (v > 80) {
                playerController.prev();
              }
            },
            onVerticalDragEnd: (DragEndDetails details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -80) {
                playerController.playerPanelController.open();
              } else if (v > 80) {
                playerController.dismissPlayer();
              }
            },
            child: Container(
              height: playerController.playerPanelMinHeight.value,
              width: size.width,
            decoration: BoxDecoration(
              color: const Color(0xF2080A14),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF00D2FF).withOpacity(0.40),
                  width: 1.2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D2FF).withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
                BoxShadow(
                  color: const Color(0xFFFF0055).withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  !isWideScreen || bottomNavEnabled
                      ? GetX<PlayerController>(
                          builder: (controller) => Container(
                              height: 3,
                              color: Colors.transparent,
                              child: MiniPlayerProgressBar(
                                  progressBarStatus:
                                      controller.progressBarStatus.value,
                                  progressBarColor: const Color(0xFF00D2FF))),
                        )
                      : GetX<PlayerController>(builder: (controller) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                left: 15.0, top: 8, right: 15, bottom: 0),
                            child: ProgressBar(
                              timeLabelLocation: TimeLabelLocation.sides,
                              thumbRadius: 7,
                              barHeight: 4,
                              thumbGlowRadius: 15,
                              baseBarColor: Theme.of(context)
                                  .sliderTheme
                                  .inactiveTrackColor,
                              bufferedBarColor: Theme.of(context)
                                  .sliderTheme
                                  .valueIndicatorColor,
                              progressBarColor: Theme.of(context)
                                  .sliderTheme
                                  .activeTrackColor,
                              thumbColor:
                                  Theme.of(context).sliderTheme.thumbColor,
                              timeLabelTextStyle:
                                  Theme.of(context).textTheme.titleMedium,
                              progress:
                                  controller.progressBarStatus.value.current,
                              total: controller.progressBarStatus.value.total,
                              buffered:
                                  controller.progressBarStatus.value.buffered,
                              onSeek: controller.seek,
                            ),
                          );
                        }),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            playerController.currentSong.value != null
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00D2FF)
                                              .withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ImageWidget(
                                        size: 50,
                                        song: playerController
                                            .currentSong.value!,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 50,
                                    width: 50,
                                  ),
                          ],
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        playerController.currentSong.value?.title ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 18,
                                  child: Marquee(
                                    id: "${playerController.currentSong.value?.id ?? 'idle'}_mini",
                                    delay: const Duration(milliseconds: 300),
                                    duration: const Duration(seconds: 5),
                                    child: Text(
                                      getSafeSongArtist(playerController.currentSong.value),
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Colors.white60,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        //player control
                        SizedBox(
                          width: isWideScreen && !bottomNavEnabled ? 450 : 135,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (isWideScreen && !bottomNavEnabled)
                                Row(
                                  children: [
                                    IconButton(
                                        iconSize: 20,
                                        onPressed:
                                            playerController.toggleFavourite,
                                        icon: Obx(() => Icon(
                                              playerController
                                                      .isCurrentSongFav.isFalse
                                                  ? Icons.favorite_border
                                                  : Icons.favorite,
                                              color: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.color ??
                                                  Colors.white,
                                            ))),
                                    IconButton(
                                        iconSize: 20,
                                        onPressed:
                                            playerController.toggleShuffleMode,
                                        icon: Obx(() => Icon(
                                              Ionicons.shuffle,
                                              color: playerController
                                                      .isShuffleModeEnabled
                                                      .value
                                                  ? (Theme.of(context)
                                                          .textTheme
                                                          .titleLarge
                                                          ?.color ??
                                                      Colors.white)
                                                  : (Theme.of(context)
                                                              .textTheme
                                                              .titleLarge
                                                              ?.color ??
                                                          Colors.white)
                                                      .withOpacity(0.2),
                                            ))),
                                  ],
                                ),
                              SizedBox(
                                  width: isWideScreen && !bottomNavEnabled ? 40 : 38,
                                  child: InkWell(
                                    onTap: playerController.prev,
                                    child: Icon(
                                      Icons.skip_previous,
                                      color: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.color ??
                                          Colors.white,
                                      size: isWideScreen && !bottomNavEnabled ? 35 : 28,
                                    ),
                                  )),
                              isWideScreen && !bottomNavEnabled
                                  ? Container(
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      width: 58,
                                      height: 58,
                                      child: const Center(
                                          child: AnimatedPlayButton(
                                        iconSize: 43,
                                      )))
                                  : const SizedBox.square(
                                      dimension: 46,
                                      child: Center(
                                          child: AnimatedPlayButton(
                                        iconSize: 32,
                                      ))),
                              SizedBox(
                                  width: isWideScreen && !bottomNavEnabled ? 40 : 38,
                                  child: Obx(() {
                                    final isLastSong =
                                        playerController.currentQueue.isEmpty ||
                                            (!(playerController
                                                        .isShuffleModeEnabled
                                                        .isTrue ||
                                                    playerController
                                                        .isQueueLoopModeEnabled
                                                        .isTrue) &&
                                                (playerController
                                                        .currentQueue.last.id ==
                                                    playerController.currentSong
                                                        .value?.id));
                                    final titleLargeColor = Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.color ??
                                        Colors.white;
                                    final titleMediumColor = Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.color ??
                                        Colors.white;
                                    return InkWell(
                                      onTap: isLastSong
                                          ? null
                                          : playerController.next,
                                      child: Icon(
                                        Icons.skip_next,
                                        color: isLastSong
                                            ? titleLargeColor.withOpacity(0.2)
                                            : titleMediumColor,
                                        size: isWideScreen && !bottomNavEnabled ? 35 : 28,
                                      ),
                                    );
                                  })),
                              if (isWideScreen && !bottomNavEnabled)
                                Row(
                                  children: [
                                    Obx(() {
                                      final isSongLoop = playerController.isLoopModeEnabled.value;
                                      final isPlaylistLoop = playerController.isQueueLoopModeEnabled.value;
                                      const activeColor = Color(0xFF00D2FF);
                                      final inactiveColor = (Theme.of(context).textTheme.titleLarge?.color ??
                                              Colors.white)
                                          .withOpacity(0.2);

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
                                                    : inactiveColor,
                                              ),
                                      );
                                    }),
                                    IconButton(
                                        iconSize: 20,
                                        onPressed: () {
                                          playerController.showLyrics();
                                          showDialog(
                                                  builder: (context) =>
                                                      const LyricsDialog(),
                                                  context: context)
                                              .whenComplete(() {
                                            playerController
                                                    .isDesktopLyricsDialogOpen =
                                                false;
                                            playerController
                                                .showLyricsflag.value = false;
                                          });
                                          playerController
                                              .isDesktopLyricsDialogOpen = true;
                                        },
                                        icon: Icon(Icons.lyrics_outlined,
                                            color: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.color ??
                                                Colors.white)),
                                  ],
                                ),
                              if (isWideScreen && !bottomNavEnabled)
                                const SizedBox(
                                  width: 20,
                                )
                            ],
                          ),
                        ),
                        if (isWideScreen && !bottomNavEnabled)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: size.width < 1004 ? 0 : 30.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                        right: 20, left: 10),
                                    height: 20,
                                    width: (size.width > 860) ? 220 : 180,
                                    child: Obx(() {
                                      final volume =
                                          playerController.volume.value;
                                      return Row(
                                        children: [
                                          SizedBox(
                                              width: 20,
                                              child: InkWell(
                                                onTap: playerController.mute,
                                                child: Icon(
                                                  volume == 0
                                                      ? Icons.volume_off
                                                      : volume > 0 &&
                                                              volume < 50
                                                          ? Icons.volume_down
                                                          : Icons.volume_up,
                                                  size: 20,
                                                ),
                                              )),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 2,
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                        enabledThumbRadius:
                                                            6.0),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                        overlayRadius: 10.0),
                                              ),
                                              child: Slider(
                                                value: playerController
                                                        .volume.value /
                                                    100,
                                                onChanged: (value) {
                                                  playerController.setVolume(
                                                      (value * 100).toInt());
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                  SizedBox(
                                    height: 40,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            playerController
                                                .homeScaffoldkey.currentState!
                                                .openEndDrawer();
                                          },
                                          icon: const Icon(Icons.queue_music),
                                        ),
                                        if (size.width > 860)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 10.0),
                                            child: IconButton(
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 500),
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    10.0)),
                                                  ),
                                                  isScrollControlled: true,
                                                  context: playerController
                                                      .homeScaffoldkey
                                                      .currentState!
                                                      .context,
                                                  barrierColor: Colors
                                                      .transparent
                                                      .withAlpha(100),
                                                  builder: (context) =>
                                                      const SleepTimerBottomSheet(),
                                                );
                                              },
                                              icon: Icon(playerController
                                                      .isSleepTimerActive.isTrue
                                                  ? Icons.timer
                                                  : Icons.timer_outlined),
                                            ),
                                          ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        const SongDownloadButton(
                                          calledFromPlayer: true,
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            final currentSong = playerController
                                                .currentSong.value;
                                            if (currentSong != null) {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AddToPlaylist(
                                                        [currentSong]),
                                              ).whenComplete(() => Get.delete<
                                                  AddToPlaylistController>());
                                            }
                                          },
                                          icon: const Icon(Icons.playlist_add),
                                        ),
                                        if (size.width > 965)
                                          IconButton(
                                            onPressed: () {
                                              final currentSong =
                                                  playerController
                                                      .currentSong.value;
                                              if (currentSong != null) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      SongInfoDialog(
                                                    song: currentSong,
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.info,
                                                size: 22),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
}
}
