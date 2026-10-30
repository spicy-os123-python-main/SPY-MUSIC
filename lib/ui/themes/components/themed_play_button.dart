import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../player/components/animated_play_button.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';

class ThemedPlayButton extends StatefulWidget {
  final double radius;
  final VoidCallback? onPlayToggle;

  const ThemedPlayButton({
    super.key,
    this.radius = 35.0,
    this.onPlayToggle,
  });

  @override
  State<ThemedPlayButton> createState() => _ThemedPlayButtonState();
}

class _ThemedPlayButtonState extends State<ThemedPlayButton>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _ringController;
  final List<_ConfettiParticle> _confetti = [];
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _ringController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void triggerBurst(SpyThemeConfig config) {
    _confetti.clear();
    final rand = math.Random();
    final colors = [config.c1, config.c2, config.c3];

    for (int i = 0; i < 18; i++) {
      final angle = rand.nextDouble() * 2 * math.pi;
      final dist = 45.0 + rand.nextDouble() * 75.0;
      _confetti.add(_ConfettiParticle(
        targetX: math.cos(angle) * dist,
        targetY: math.sin(angle) * dist,
        color: colors[i % colors.length],
        rotation: rand.nextDouble() * 4 * math.pi,
      ));
    }
    _confettiController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      if (config == null) {
        return _buildDefaultPlayButton();
      }

      Widget buttonCore;
      if (config.isGlass) {
        buttonCore = _buildGlassOrb(config, reduceEffects);
      } else if (config.isFlame) {
        buttonCore = _buildFlameRingButton(config, reduceEffects);
      } else if (config.isSignal) {
        buttonCore = _buildSignalButton(config);
      } else if (config.isWarp) {
        buttonCore = _buildWarpButton(config);
      } else {
        buttonCore = _buildDefaultPlayButton();
      }

      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          buttonCore,

          // Confetti burst
          if (_confetti.isNotEmpty && !reduceEffects)
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                final progress = _confettiController.value;
                if (progress >= 1.0) return const SizedBox.shrink();

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: _confetti.map((c) {
                    final dx = c.targetX * progress;
                    final dy = c.targetY * progress;
                    final opacity = (1.0 - progress).clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.rotate(
                        angle: c.rotation * progress,
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 6,
                            height: 10,
                            decoration: BoxDecoration(
                              color: c.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      );
    });
  }

  Widget _buildDefaultPlayButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0055).withOpacity(0.55),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.4),
            blurRadius: 14,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.transparent,
        child: const AnimatedPlayButton(key: Key("playButton")),
      ),
    );
  }

  Widget _buildGlassOrb(SpyThemeConfig config, bool reduceEffects) {
    Widget orb = Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 0.9,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, config.accent, 0.45)!,
            config.accent,
          ],
          stops: const [0.0, 0.35, 0.85],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 6,
            spreadRadius: -1,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: config.glassDropShadow ?? Colors.black45,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Theme(
          data: ThemeData(
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          child: const AnimatedPlayButton(key: Key("playButton")),
        ),
      ),
    );

    if (reduceEffects) return orb;

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        final floatY = math.sin(_floatController.value * math.pi) * -8.0;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: orb,
        );
      },
    );
  }

  Widget _buildFlameRingButton(SpyThemeConfig config, bool reduceEffects) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, _) {
        final ringProgress = _ringController.value;
        final ringSpread = ringProgress * 22.0;
        final ringOpacity = (1.0 - ringProgress).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                config.flameCore ?? config.accent,
                config.flameMid ?? config.accent,
                config.flameOuter ?? config.accent,
              ],
            ),
            boxShadow: [
              if (!reduceEffects)
                BoxShadow(
                  color: config.accent.withOpacity(ringOpacity * 0.5),
                  blurRadius: 6,
                  spreadRadius: ringSpread,
                ),
              BoxShadow(
                color: config.accent.withOpacity(0.6),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.transparent,
            child: Theme(
              data: ThemeData(
                iconTheme: IconThemeData(color: config.onAccent),
              ),
              child: const AnimatedPlayButton(key: Key("playButton")),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignalButton(SpyThemeConfig config) {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        color: config.accent,
        borderRadius: BorderRadius.zero,
      ),
      child: Center(
        child: Theme(
          data: ThemeData(
            iconTheme: IconThemeData(color: config.onAccent),
          ),
          child: const AnimatedPlayButton(key: Key("playButton")),
        ),
      ),
    );
  }

  Widget _buildWarpButton(SpyThemeConfig config) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: config.accent,
        boxShadow: [
          BoxShadow(
            color: config.accent.withOpacity(0.6),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.transparent,
        child: Theme(
          data: ThemeData(
            iconTheme: IconThemeData(color: config.onAccent),
          ),
          child: const AnimatedPlayButton(key: Key("playButton")),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double targetX;
  final double targetY;
  final Color color;
  final double rotation;

  _ConfettiParticle({
    required this.targetX,
    required this.targetY,
    required this.color,
    required this.rotation,
  });
}

