import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';

class ThemedCover extends StatefulWidget {
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ThemedCover({
    super.key,
    required this.child,
    required this.size,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ThemedCover> createState() => _ThemedCoverState();
}

class _ThemedCoverState extends State<ThemedCover>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _sweepController;
  late AnimationController _orbitController;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _sweepController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  void _updateTilt(Offset localPosition) {
    final half = widget.size / 2.0;
    final dx = (localPosition.dx - half) / half;
    final dy = (localPosition.dy - half) / half;
    setState(() {
      _tiltY = (dx * 10.0).clamp(-10.0, 10.0) * (math.pi / 180.0);
      _tiltX = (-dy * 10.0).clamp(-10.0, 10.0) * (math.pi / 180.0);
    });
  }

  void _onHover(PointerHoverEvent event) => _updateTilt(event.localPosition);
  void _onPointerMove(PointerMoveEvent event) => _updateTilt(event.localPosition);

  void _onExit(PointerExitEvent event) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      if (config == null || reduceEffects) {
        return GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: widget.child,
          ),
        );
      }

      Widget content = widget.child;

      if (config.isGlass) {
        content = _buildGlassRimCover(config, content);
      } else if (config.isFlame) {
        content = _buildFlameCover(config, content);
      } else if (config.isWarp) {
        content = _buildWarpCover(config, content);
      } else if (config.isSignal) {
        content = _buildSignalCover(config, content);
      }

      return MouseRegion(
        onHover: _onHover,
        onExit: _onExit,
        child: Listener(
          onPointerMove: _onPointerMove,
          onPointerUp: (_) => setState(() {
            _tiltX = 0.0;
            _tiltY = 0.0;
          }),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, _) {
                final floatOffset = math.sin(_floatController.value * math.pi) * -6.0;

                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(0.0, floatOffset, 0.0)
                  ..rotateX(_tiltX)
                  ..rotateY(_tiltY);

                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: content,
                );
              },
            ),
          ),
        ),
      );
    });
  }

  Widget _buildGlassRimCover(SpyThemeConfig config, Widget innerChild) {
    const rim = 7.0;
    final outerRadius = BorderRadius.circular(config.radius + 6.0);
    final innerRadius = BorderRadius.circular(config.radius);

    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(rim),
      decoration: BoxDecoration(
        color: config.glassFill ?? const Color(0x1AFFFFFF),
        borderRadius: outerRadius,
        border: Border.all(
          color: config.glassBorder ?? const Color(0x4DFFFFFF),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: config.glassDropShadow ?? Colors.black38,
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: innerRadius,
            child: innerChild,
          ),

          // 4-second light sweep sheen
          AnimatedBuilder(
            animation: _sweepController,
            builder: (context, _) {
              final sweep = _sweepController.value;
              return ClipRRect(
                borderRadius: innerRadius,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-2.5 + sweep * 5.0, -1.0),
                      end: Alignment(-1.5 + sweep * 5.0, 1.0),
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFlameCover(SpyThemeConfig config, Widget innerChild) {
    final radius = BorderRadius.circular(22.0);
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        final glowIntensity = 0.4 + 0.3 * math.sin(_floatController.value * math.pi * 2);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: config.accent, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: config.accent.withOpacity(glowIntensity),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: (config.flameOuter ?? Colors.red).withOpacity(glowIntensity * 0.7),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: innerChild,
          ),
        );
      },
    );
  }

  Widget _buildWarpCover(SpyThemeConfig config, Widget innerChild) {
    final radius = BorderRadius.circular(config.radius);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 3D cyan orbit ring around the cover
          Positioned(
            left: -widget.size * 0.15,
            top: -widget.size * 0.15,
            width: widget.size * 1.3,
            height: widget.size * 1.3,
            child: AnimatedBuilder(
              animation: _orbitController,
              builder: (context, _) {
                final angleZ = _orbitController.value * 2 * math.pi;
                final ringTransform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(72.0 * math.pi / 180.0)
                  ..rotateZ(angleZ);

                return Transform(
                  transform: ringTransform,
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: config.accent.withOpacity(0.85),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: config.accent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main cover
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: config.accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: config.accent.withOpacity(0.35),
                  blurRadius: 32,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(config.radius - 1.0),
              child: innerChild,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCover(SpyThemeConfig config, Widget innerChild) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: config.accent, width: 1.5),
      ),
      child: innerChild,
    );
  }
}
