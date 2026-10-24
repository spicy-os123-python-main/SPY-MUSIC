import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/player/player_controller.dart';
import '../../widgets/loader.dart';

/// A combined Play & Pause button that animates between play and pause icons
/// with a glowing neon pulse.
class AnimatedPlayButton extends StatefulWidget {
  final double iconSize;

  const AnimatedPlayButton({super.key, this.iconSize = 40.0});

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final isPlaying =
        Get.find<PlayerController>().buttonState.value == PlayButtonState.playing;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<PlayerController>(builder: (controller) {
      final buttonState = controller.buttonState.value;
      final isPlaying = buttonState == PlayButtonState.playing;
      final isLoading = buttonState == PlayButtonState.loading;

      if (isPlaying && _controller.value < 0.99) {
        _controller.forward();
      } else if (!isPlaying && !isLoading && _controller.value > 0.01) {
        _controller.reverse();
      }

      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withOpacity(0.55),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.40),
                    blurRadius: 10,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.25),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: IconButton(
          iconSize: widget.iconSize,
          onPressed: () {
            if (isLoading) return;
            if (isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          icon: isLoading
              ? const LoadingIndicator(
                  dimension: 22,
                )
              : AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _controller,
                  color: Colors.white,
                ),
        ),
      );
    });
  }
}
