import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_themes.dart';
import '../interaction_animations/interaction_animation_types.dart';
import '../../screens/Settings/settings_screen_controller.dart';

/// Wraps any button, card or icon with an interactive animation
/// according to the active [InteractionAnimationType] selected by the user.
class SpyButtonAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final BorderRadius? borderRadius;
  final bool enableFeedback;

  const SpyButtonAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
    this.enableFeedback = true,
  });

  @override
  State<SpyButtonAnimation> createState() => _SpyButtonAnimationState();
}

class _SpyButtonAnimationState extends State<SpyButtonAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _tapPosition = details.localPosition;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    final settings = Get.isRegistered<SettingsScreenController>()
        ? Get.find<SettingsScreenController>()
        : null;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final type = settings?.interactionAnimationType.value ??
              InteractionAnimationType.standard;
          final value = _animation.value;

          switch (type) {
            case InteractionAnimationType.bookFlip:
              // Book spine flip: tilts slightly along the left edge with 3D perspective
              final angle = -value * 0.18;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(angle),
                alignment: Alignment.centerLeft,
                child: child,
              );

            case InteractionAnimationType.cube3d:
              // 3D Cube depress: scales and shifts with perspective depth
              final scale = 1.0 - (value * 0.09);
              final rotateX = value * 0.12;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..scale(scale, scale)
                  ..rotateX(rotateX),
                alignment: Alignment.center,
                child: child,
              );

            case InteractionAnimationType.cardStack:
              // Card depth: drops down with subtle vertical shift and scale
              final scale = 1.0 - (value * 0.08);
              final offsetY = value * 4.0;
              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );

            case InteractionAnimationType.elasticBounce:
              // Elastic bounce: sharp scale down and spring pop
              final scale = 1.0 - (value * 0.14);
              return Transform.scale(
                scale: scale,
                child: child,
              );

            case InteractionAnimationType.jellySquish:
              // Jelly squash and stretch: expands horizontally while compressing vertically
              final scaleX = 1.0 + (value * 0.12);
              final scaleY = 1.0 - (value * 0.14);
              return Transform(
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                alignment: Alignment.center,
                child: child,
              );

            case InteractionAnimationType.neonGlow:
              // Neon pulse: glowing neon border and halo
              final theme = AppThemes.current;
              final accent = theme?.accent ?? const Color(0xFF00D2FF);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                  boxShadow: value > 0.01
                      ? [
                          BoxShadow(
                            color: accent.withOpacity(value * 0.65),
                            blurRadius: value * 18,
                            spreadRadius: value * 3,
                          ),
                        ]
                      : null,
                ),
                child: Transform.scale(
                  scale: 1.0 - (value * 0.05),
                  child: child,
                ),
              );

            case InteractionAnimationType.tilt3d:
              // 3D Tilt: tilts toward the touch position
              final size = context.size ?? const Size(100, 100);
              final dx = (_tapPosition.dx - (size.width / 2)) / (size.width / 2);
              final dy = (_tapPosition.dy - (size.height / 2)) / (size.height / 2);
              final clampedX = dx.clamp(-1.0, 1.0);
              final clampedY = dy.clamp(-1.0, 1.0);
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(-clampedY * value * 0.22)
                  ..rotateY(clampedX * value * 0.22)
                  ..scale(1.0 - (value * 0.05)),
                alignment: Alignment.center,
                child: child,
              );

            case InteractionAnimationType.zoomPop:
              // Fast crisp zoom pop
              final scale = 1.0 - (value * 0.10);
              return Transform.scale(
                scale: scale,
                child: child,
              );

            case InteractionAnimationType.smoothSlide:
            case InteractionAnimationType.standard:
              // Standard subtle scale
              final scale = 1.0 - (value * 0.05);
              return Transform.scale(
                scale: scale,
                child: child,
              );
          }
        },
        child: widget.child,
      ),
    );
  }
}
