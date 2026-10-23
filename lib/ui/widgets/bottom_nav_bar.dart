import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();

    final items = [
      {'icon': Icons.home_rounded, 'label': 'home'.tr},
      {'icon': Icons.search_rounded, 'label': 'search'.tr},
      {'icon': Icons.library_music_rounded, 'label': 'library'.tr},
      {'icon': Icons.settings_rounded, 'label': 'settings'.tr},
    ];

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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
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
}
