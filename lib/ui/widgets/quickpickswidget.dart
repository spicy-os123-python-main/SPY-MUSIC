import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/quick_picks.dart';
import '../player/player_controller.dart';
import 'image_widget.dart';
import 'mini_equalizer.dart';
import 'songinfo_bottom_sheet.dart';

class QuickPicksWidget extends StatelessWidget {
  const QuickPicksWidget(
      {super.key, required this.content, this.scrollController});
  final QuickPicks content;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 345,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  content.title.startsWith("🟢") ||
                          content.title.startsWith("🔴") ||
                          content.title.startsWith("🟠") ||
                          content.title.startsWith("🔵") ||
                          content.title.startsWith("☁️")
                      ? content.title
                      : content.title.toLowerCase().removeAllWhitespace.tr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                ),
              )),
          const SizedBox(height: 10),
          Expanded(
            child: Scrollbar(
              thickness: GetPlatform.isDesktop ? null : 0,
              controller: scrollController,
              child: GridView.builder(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: content.songList.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: .25 / 1,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, item) {
                  return _QuickPickItem(song: content.songList[item]);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickPickItem extends StatefulWidget {
  final MediaItem song;
  const _QuickPickItem({required this.song});

  @override
  State<_QuickPickItem> createState() => _QuickPickItemState();
}

class _QuickPickItemState extends State<_QuickPickItem> {
  bool _isPressed = false;

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
            builder: (context) => SongInfoBottomSheet(widget.song),
          ).whenComplete(() => Get.delete<SongInfoController>());
        }
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Obx(() {
            final isCurrent =
                playerController.currentSong.value?.id == widget.song.id;
            final isPlaying = isCurrent &&
                playerController.buttonState.value == PlayButtonState.playing;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF00D2FF).withOpacity(0.12)
                    : const Color(0xFF121526).withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF00D2FF).withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: isCurrent ? 1.2 : 0.8,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageWidget(
                      song: widget.song,
                      size: 50,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                              color: isCurrent ? const Color(0xFF00D2FF) : null,
                            ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 4),
                      MiniEqualizer(isPlaying: isPlaying, height: 10),
                    ],
                  ],
                ),
                subtitle: Text(
                  "${widget.song.artist}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                ),
                onTap: () {
                  playerController.pushSongToQueue(widget.song);
                },
                onLongPress: () {
                  showModalBottomSheet(
                    constraints: const BoxConstraints(maxWidth: 500),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10.0)),
                    ),
                    isScrollControlled: true,
                    context:
                        playerController.homeScaffoldkey.currentState!.context,
                    barrierColor: Colors.transparent.withAlpha(100),
                    builder: (context) =>
                        SongInfoBottomSheet(widget.song),
                  ).whenComplete(() => Get.delete<SongInfoController>());
                },
                trailing: isDesktop
                    ? SizedBox(
                        width: 32,
                        child: IconButton(
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
                              builder: (context) =>
                                  SongInfoBottomSheet(widget.song),
                            ).whenComplete(
                                () => Get.delete<SongInfoController>());
                          },
                          icon: const Icon(Icons.more_vert),
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}
