import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/music_source.dart';
import '../screens/Home/home_screen_controller.dart';
import '../screens/Search/search_result_screen_controller.dart';
import '../utils/theme_controller.dart';

class PlatformSelectorController extends GetxController {
  final selectedSource = MusicSource.all.obs;

  void selectSource(MusicSource source) {
    selectedSource.value = source;
    if (Get.isRegistered<HomeScreenController>()) {
      Get.find<HomeScreenController>().filterByPlatform(source);
    }
    if (Get.isRegistered<SearchResultScreenController>()) {
      Get.find<SearchResultScreenController>().onPlatformChanged(source);
    }
  }
}

class PlatformSelectorWidget extends StatelessWidget {
  const PlatformSelectorWidget({super.key});

  Widget _buildButton(PlatformSelectorController controller, MusicSource source) {
    return Obx(() {
      final isSelected = controller.selectedSource.value == source;
      final customTheme = Get.find<ThemeController>().activeCustomTheme.value;

      Decoration decoration;
      Color textColor;
      Color iconColor;

      if (customTheme != null) {
        final radius = customTheme.isSignal
            ? BorderRadius.zero
            : BorderRadius.circular(customTheme.radius > 20 ? 99 : 14);
        if (customTheme.isGlass) {
          decoration = BoxDecoration(
            color: isSelected
                ? (customTheme.glassActiveTab ??
                    customTheme.accent.withOpacity(0.4))
                : (customTheme.glassFill ?? const Color(0x1AFFFFFF)),
            borderRadius: radius,
            border: Border.all(
              color: isSelected
                  ? (customTheme.glassHighlight ?? Colors.white)
                  : (customTheme.glassBorder ?? const Color(0x4DFFFFFF)),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: customTheme.glassDropShadow ?? Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          );
          textColor = isSelected ? customTheme.fg : customTheme.muted;
          iconColor = textColor;
        } else if (customTheme.isFlame) {
          decoration = BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      customTheme.flameCore ?? customTheme.accent,
                      customTheme.flameMid ?? customTheme.accent,
                      customTheme.flameOuter ?? customTheme.accent,
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : (customTheme.cardColor ?? const Color(0xCC1E0A06)),
            borderRadius: radius,
            border: Border.all(
              color: isSelected
                  ? customTheme.accent
                  : (customTheme.lineColor ?? Colors.white12),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: customTheme.accent.withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          );
          textColor = isSelected ? customTheme.onAccent : customTheme.muted;
          iconColor = textColor;
        } else {
          decoration = BoxDecoration(
            color: isSelected
                ? customTheme.accent
                : (customTheme.cardColor ?? customTheme.bg),
            borderRadius: radius,
            border: Border.all(
              color: isSelected
                  ? customTheme.accent
                  : (customTheme.lineColor ?? Colors.white12),
              width: 1.0,
            ),
            boxShadow: isSelected && !customTheme.isSignal
                ? [
                    BoxShadow(
                      color: customTheme.accent.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          );
          textColor = isSelected ? customTheme.onAccent : customTheme.muted;
          iconColor = textColor;
        }
      } else {
        decoration = BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    source.brandColor.withOpacity(0.9),
                    source == MusicSource.all
                        ? const Color(0xFF00D2FF)
                        : source.brandColor.withOpacity(0.6),
                  ],
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF141724).withOpacity(0.75),
                    const Color(0xFF0C0E17).withOpacity(0.75),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.85)
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: source.brandColor.withOpacity(0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        );
        textColor = isSelected ? Colors.white : Colors.white70;
        iconColor = textColor;
      }

      return GestureDetector(
        onTap: () => controller.selectSource(source),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: decoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                source.icon,
                size: 15,
                color: iconColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  source.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlatformSelectorController());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildButton(controller, MusicSource.all)),
              const SizedBox(width: 6),
              Expanded(child: _buildButton(controller, MusicSource.youtube)),
              const SizedBox(width: 6),
              Expanded(child: _buildButton(controller, MusicSource.spotify)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildButton(controller, MusicSource.soundcloud)),
              const SizedBox(width: 6),
              Expanded(child: _buildButton(controller, MusicSource.amazon)),
            ],
          ),
        ],
      ),
    );
  }
}
