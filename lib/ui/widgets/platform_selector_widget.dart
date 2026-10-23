import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/music_source.dart';
import '../screens/Home/home_screen_controller.dart';

class PlatformSelectorController extends GetxController {
  final selectedSource = MusicSource.all.obs;

  void selectSource(MusicSource source) {
    selectedSource.value = source;
    if (Get.isRegistered<HomeScreenController>()) {
      Get.find<HomeScreenController>().filterByPlatform(source);
    }
  }
}

class PlatformSelectorWidget extends StatelessWidget {
  const PlatformSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlatformSelectorController());

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: MusicSource.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final source = MusicSource.values[index];
          return Obx(() {
            final isSelected = controller.selectedSource.value == source;
            return GestureDetector(
              onTap: () => controller.selectSource(source),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
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
                            const Color(0xFF141724).withOpacity(0.7),
                            const Color(0xFF0C0E17).withOpacity(0.7),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: source.brandColor.withOpacity(0.55),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      source.icon,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      source.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.white70,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }
}

