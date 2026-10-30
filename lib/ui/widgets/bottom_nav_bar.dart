import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/Home/home_screen_controller.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '../themes/app_themes.dart';
import '../utils/theme_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    final items = [
      {'icon': Icons.home_rounded, 'label': 'home'.tr},
      {'icon': Icons.search_rounded, 'label': 'search'.tr},
      {'icon': Icons.library_music_rounded, 'label': 'library'.tr},
      {'icon': Icons.settings_rounded, 'label': 'settings'.tr},
    ];

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      if (config == null) {
        return _buildDefaultNavBar(context, homeScreenController, items);
      }

      if (config.isGlass) {
        return _buildGlassNavBar(
            context, homeScreenController, items, config, reduceEffects);
      } else {
        return _buildThemedNavBar(
            context, homeScreenController, items, config, reduceEffects);
      }
    });
  }

  Widget _buildDefaultNavBar(
    BuildContext context,
    HomeScreenController homeScreenController,
    List<Map<String, dynamic>> items,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE00A0C14),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF00D2FF).withOpacity(0.25),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D2FF).withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Obx(() {
                final currentIndex = homeScreenController.tabIndex.toInt();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = currentIndex == index;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => homeScreenController.onBottonBarTabSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFF00D2FF).withOpacity(0.22),
                                    const Color(0xFFFF0055).withOpacity(0.22),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFFFF0055).withOpacity(0.5),
                                  width: 1.0,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF0055).withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 24,
                              color: isSelected
                                  ? const Color(0xFF00D2FF)
                                  : Colors.white54,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : Colors.white54,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassNavBar(
    BuildContext context,
    HomeScreenController homeScreenController,
    List<Map<String, dynamic>> items,
    SpyThemeConfig config,
    bool reduceEffects,
  ) {
    final borderColor = config.glassBorder ?? const Color(0x4DFFFFFF);
    final fillColor = config.glassFill ?? const Color(0x1AFFFFFF);
    final bubbleColor = config.glassActiveTab ?? const Color(0x3DFFFFFF);
    final highlightColor = config.glassHighlight ?? Colors.white70;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / items.length;

            Widget navContent = SizedBox(
              height: 58,
              child: Stack(
                children: [
                  // Sliding glass bubble indicator with overshoot curve
                  Obx(() {
                    final currentIndex = homeScreenController.tabIndex.toInt().clamp(0, 3);
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: const Cubic(0.6, 1.4, 0.4, 1.0),
                      left: currentIndex * tabWidth + 4,
                      top: 4,
                      width: tabWidth - 8,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: bubbleColor,
                          border: Border.all(
                            color: highlightColor.withOpacity(0.5),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: config.glassDropShadow ?? Colors.black26,
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Tab items
                  Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      return Expanded(
                        child: Obx(() {
                          final isSelected =
                              homeScreenController.tabIndex.toInt() == index;
                          return InkWell(
                            borderRadius: BorderRadius.circular(99),
                            onTap: () => homeScreenController
                                .onBottonBarTabSelected(index),
                            child: SizedBox(
                              height: 58,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 22,
                                    color: isSelected ? config.fg : config.muted,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected ? config.fg : config.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ],
              ),
            );

            if (reduceEffects) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: fillColor,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: navContent,
              );
            }

            return RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: fillColor,
                      border: Border.all(color: borderColor, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: config.glassDropShadow ?? Colors.black26,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: navContent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemedNavBar(
    BuildContext context,
    HomeScreenController homeScreenController,
    List<Map<String, dynamic>> items,
    SpyThemeConfig config,
    bool reduceEffects,
  ) {
    final navRadius = BorderRadius.circular(config.radius);
    final cardColor = config.cardColor ?? config.bg;
    final lineColor = config.lineColor ?? config.accent.withOpacity(0.3);

    return SafeArea(
      top: false,
      child: Container(
        margin: config.isSignal
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: config.isSignal ? BorderRadius.zero : navRadius,
          border: Border.all(color: lineColor, width: 1.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / items.length;

            return SizedBox(
              height: 58,
              child: Stack(
                children: [
                  // Active indicator bar
                  Obx(() {
                    final currentIndex =
                        homeScreenController.tabIndex.toInt().clamp(0, 3);

                    Widget indicatorWidget;
                    if (config.isFlame) {
                      indicatorWidget = Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              config.flameCore ?? config.accent,
                              config.flameOuter ?? config.accent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: config.accent.withOpacity(0.8),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      );
                    } else if (config.isWarp) {
                      indicatorWidget = Container(
                        decoration: BoxDecoration(
                          color: config.accent,
                          boxShadow: [
                            BoxShadow(
                              color: config.accent.withOpacity(0.7),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Signal: 0-radius green line at bottom
                      indicatorWidget = Container(
                        color: config.accent,
                      );
                    }

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: const Cubic(0.6, 1.4, 0.4, 1.0),
                      left: currentIndex * tabWidth,
                      top: config.isSignal ? null : 0,
                      bottom: config.isSignal ? 0 : null,
                      width: tabWidth,
                      height: 3.0,
                      child: indicatorWidget,
                    );
                  }),

                  // Tab Buttons
                  Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      return Expanded(
                        child: Obx(() {
                          final isSelected =
                              homeScreenController.tabIndex.toInt() == index;
                          return InkWell(
                            borderRadius: config.isSignal
                                ? BorderRadius.zero
                                : BorderRadius.circular(config.radius),
                            onTap: () => homeScreenController
                                .onBottonBarTabSelected(index),
                            child: SizedBox(
                              height: 58,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 22,
                                    color: isSelected ? config.accent : config.muted,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color:
                                          isSelected ? config.fg : config.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
