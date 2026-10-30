import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../player/player_controller.dart';
import '../themes/components/themed_heading.dart';
import '../utils/theme_controller.dart';
import 'live_equalizer_widget.dart';

class SpyMusicHeaderWidget extends StatelessWidget {
  const SpyMusicHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              // Glowing App Logo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0055).withOpacity(0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00D2FF).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/icons/icon.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() {
                    final customTheme =
                        Get.find<ThemeController>().activeCustomTheme.value;
                    if (customTheme != null) {
                      return const ThemedHeading(
                        'SPY MUSIC',
                        fontSize: 22,
                      );
                    }
                    return ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF00D2FF),
                          Color(0xFF8A00FF),
                          Color(0xFFFF0055),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'SPY MUSIC',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }),
                  Obx(() {
                    final customTheme =
                        Get.find<ThemeController>().activeCustomTheme.value;
                    return Text(
                      'YT • SPOTIFY • SOUNDCLOUD • AMAZON',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: customTheme != null
                            ? customTheme.muted
                            : Colors.white54,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Live Animated Equalizer
          Obx(() {
            final isPlaying = playerController.buttonState.value == PlayButtonState.playing;
            final customTheme = Get.find<ThemeController>().activeCustomTheme.value;
            final accentColor = customTheme != null ? customTheme.accent : const Color(0xFFFF0055);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: customTheme != null
                    ? (customTheme.cardColor ?? customTheme.bg)
                    : const Color(0xFF10131E).withOpacity(0.7),
                borderRadius: BorderRadius.circular(customTheme != null ? customTheme.radius.clamp(0, 12) : 12),
                border: Border.all(
                  color: isPlaying
                      ? accentColor.withOpacity(0.5)
                      : (customTheme != null ? customTheme.lineColor ?? Colors.white10 : Colors.white10),
                ),
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: LiveEqualizerWidget(
                isPlaying: isPlaying,
                height: 18,
                color: accentColor,
              ),
            );
          }),
        ],
      ),
    );
  }
}

