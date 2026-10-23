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

  Widget _buildButton(PlatformSelectorController controller, MusicSource source) {
    return Obx(() {
      final isSelected = controller.selectedSource.value == source;
      return GestureDetector(
        onTap: () => controller.selectSource(source),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
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
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                source.icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.white70,
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
                    color: isSelected ? Colors.white : Colors.white70,
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
