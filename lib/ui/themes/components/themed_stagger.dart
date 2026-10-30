import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';

class ThemedStagger extends StatefulWidget {
  final int index;
  final Widget child;

  const ThemedStagger({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<ThemedStagger> createState() => _ThemedStaggerState();
}

class _ThemedStaggerState extends State<ThemedStagger>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.2, 0.8, 0.2, 1.0),
    );

    final delayMs = widget.index * 80;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      if (config == null || reduceEffects) {
        return widget.child;
      }

      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final val = _animation.value;

          if (config.isSignal) {
            // Reveal left to right
            return ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: val.clamp(0.001, 1.0),
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: widget.child,
                ),
              ),
            );
          } else if (config.isWarp) {
            // Flies in from depth with 35 degree Y rotation
            final angleY = (1.0 - val) * (35.0 * math.pi / 180.0);
            final translateY = (1.0 - val) * 30.0;
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(0.0, translateY, 0.0)
              ..rotateY(angleY);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: widget.child,
              ),
            );
          } else if (config.isGlass) {
            // Move up 40px, scale from 0.94, blur from 10 to 0
            final translateY = (1.0 - val) * 40.0;
            final scale = 0.94 + (0.06 * val);
            final blur = (1.0 - val) * 10.0;

            Widget result = Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: widget.child,
                ),
              ),
            );

            if (blur > 0.5) {
              result = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: result,
              );
            }
            return result;
          } else {
            // Flame themes: fade in, move up 40px, scale from 0.96 with brief brightness flash
            final translateY = (1.0 - val) * 40.0;
            final scale = 0.96 + (0.04 * val);
            final opacity = val.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: widget.child,
                ),
              ),
            );
          }
        },
      );
    });
  }
}
