import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../player_controller.dart';
import 'fullscreen_video_screen.dart';

class SpyVideoPlayer extends StatelessWidget {
  const SpyVideoPlayer({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final current = playerController.currentSong.value;
      if (!playerController.isYouTubeSong(current)) {
        return const SizedBox.shrink();
      }
      final isLoading = playerController.isVideoLoading.value;
      final controller = playerController.videoController;

      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF0055).withOpacity(0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF0055).withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xFF00D2FF).withOpacity(0.2),
              blurRadius: 14,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: isLoading || controller == null
            ? Container(
                color: const Color(0xFF0C0E1A),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF00D2FF)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Video wird geladen...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  MaterialVideoControlsTheme(
                    normal: const MaterialVideoControlsThemeData(
                      displaySeekBar: false,
                      automaticallyImplySkipNextButton: false,
                      automaticallyImplySkipPreviousButton: false,
                    ),
                    fullscreen: const MaterialVideoControlsThemeData(),
                    child: Video(
                      controller: controller,
                      controls: AdaptiveVideoControls,
                    ),
                  ),

                  // Floating Fullscreen Button in top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_rounded,
                            color: Colors.white, size: 22),
                        tooltip: "Vollbildmodus",
                        onPressed: () {
                          Get.to(() => const FullScreenVideoScreen(),
                              transition: Transition.fadeIn,
                              duration: const Duration(milliseconds: 250));
                        },
                      ),
                    ),
                  ),
                ],
              ),
      );
    });
  }
}

