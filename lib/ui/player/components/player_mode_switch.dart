import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../player_controller.dart';

class PlayerModeSwitch extends StatelessWidget {
  const PlayerModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final currentSong = playerController.currentSong.value;
      if (currentSong == null || !playerController.isYouTubeSong(currentSong)) {
        return const SizedBox.shrink();
      }

      final isVideo = playerController.isVideoMode.value;
      final isLoading = playerController.isVideoLoading.value;

      return Container(
        height: 38,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF141724).withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio Mode Tab
            GestureDetector(
              onTap: isVideo ? () => playerController.toggleVideoMode() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: !isVideo
                      ? const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFF0072FF)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !isVideo
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withOpacity(0.45),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 16,
                      color: !isVideo ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Audio',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !isVideo ? FontWeight.w800 : FontWeight.w600,
                        color: !isVideo ? Colors.white : Colors.white60,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Video Mode Tab
            GestureDetector(
              onTap: (!isVideo && !isLoading)
                  ? () => playerController.toggleVideoMode()
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isVideo
                      ? const LinearGradient(
                          colors: [Color(0xFFFF0055), Color(0xFFFF5500)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isVideo
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF0055).withOpacity(0.5),
                            blurRadius: 12,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        Icons.smart_display_rounded,
                        size: 16,
                        color: isVideo ? Colors.white : Colors.white60,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      isLoading ? 'Laden...' : 'Video',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isVideo ? FontWeight.w800 : FontWeight.w600,
                        color: isVideo ? Colors.white : Colors.white60,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

