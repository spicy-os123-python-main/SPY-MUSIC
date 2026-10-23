import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/player/player_controller.dart';
import '../../widgets/loader.dart';

/// A button that animates between a play and pause icon with glowing neon fire pulse.
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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

      if (isPlaying) {
        _controller.forward();
      } else if (!isLoading) {
        _controller.reverse();
      }

      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withOpacity(0.55),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.35),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: IconButton(
          iconSize: widget.iconSize,
          onPressed: () {
            isPlaying ? controller.pause() : controller.play();
          },
          icon: isLoading
              ? const LoadingIndicator(
                  dimension: 20,
                )
              : AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _controller,
                  color: isPlaying ? const Color(0xFF00D2FF) : Colors.white,
                ),
        ),
      );
    });
  }
}
