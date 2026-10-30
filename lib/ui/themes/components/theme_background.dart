import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';

class ThemeBackground extends StatefulWidget {
  final Widget child;
  const ThemeBackground({super.key, required this.child});

  @override
  State<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends State<ThemeBackground>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _sweepController;
  FragmentProgram? _flameProgram;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset('assets/shaders/flame.frag');
      if (mounted) {
        setState(() {
          _flameProgram = program;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      if (config == null) {
        return _buildDefaultBackground();
      }

      if (reduceEffects) {
        return Container(
          color: config.bg,
          child: widget.child,
        );
      }

      Widget bgVisual;
      if (config.isFlame) {
        bgVisual = _buildFlameBackground(config);
      } else if (config.isGlass) {
        bgVisual = _buildGlassBackground(config);
      } else if (config.isWarp) {
        bgVisual = _buildWarpBackground(config);
      } else if (config.isSignal) {
        bgVisual = _buildSignalBackground(config);
      } else {
        bgVisual = Container(color: config.bg);
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          bgVisual,
          widget.child,
        ],
      );
    });
  }

  Widget _buildDefaultBackground() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final progress = _animController.value;
        final angle = progress * 2 * math.pi;
        final alignX1 = math.cos(angle) * 0.7;
        final alignY1 = math.sin(angle) * 0.7;
        final alignX2 = math.cos(angle + math.pi) * 0.7;
        final alignY2 = math.sin(angle + math.pi) * 0.7;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF07080D)),
            Positioned(
              left: -80 + (alignX1 * 50),
              top: -80 + (alignY1 * 50),
              width: 320,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D2FF).withOpacity(0.22),
                      const Color(0xFF0051FF).withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -80 + (alignX2 * 50),
              bottom: 40 + (alignY2 * 50),
              width: 340,
              height: 340,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF0055).withOpacity(0.25),
                      const Color(0xFFFF3D00).withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildFlameBackground(SpyThemeConfig config) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid base color
        Container(color: config.bg),

        // Deep warm or blue glow behind flame
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 1.3),
                radius: 1.1,
                colors: [
                  (config.bgGlow ?? const Color(0xFF5A0F00)).withOpacity(0.9),
                  config.bg,
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // Flame layer at bottom edge
        Positioned(
          left: -40,
          right: -40,
          bottom: -30,
          height: 340,
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              if (_flameProgram != null) {
                return CustomPaint(
                  painter: _FlameShaderPainter(
                    program: _flameProgram!,
                    time: _animController.value * 12.0,
                    c1: config.flameOuter ?? const Color(0xFFFF3D00),
                    c2: config.flameMid ?? const Color(0xFFFF8A00),
                    c3: config.flameCore ?? const Color(0xFFFFD000),
                    c4: config.flameHot ?? const Color(0xFFFFFBD0),
                  ),
                );
              } else {
                return _buildFlameFallback(config);
              }
            },
          ),
        ),

        // Rising glowing embers
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _EmbersPainter(
                  progress: _animController.value,
                  coreColor: config.flameCore ?? const Color(0xFFFFD000),
                  midColor: config.flameMid ?? const Color(0xFFFF8A00),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlameFallback(SpyThemeConfig config) {
    final t = _animController.value * 2 * math.pi;
    final scaleY = 0.95 + 0.1 * math.sin(t * 3);
    return Transform.scale(
      scaleY: scaleY,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, 1.0),
            radius: 0.9,
            colors: [
              (config.flameHot ?? Colors.white).withOpacity(0.6),
              (config.flameCore ?? Colors.yellow).withOpacity(0.45),
              (config.flameMid ?? Colors.orange).withOpacity(0.3),
              (config.flameOuter ?? Colors.red).withOpacity(0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBackground(SpyThemeConfig config) {
    final blobs = config.glassBlobs ??
        [const Color(0xFF2A5BFF), const Color(0xFF00C2C7), const Color(0xFFC13CFF)];

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final t = _animController.value * 2 * math.pi;
        final dx1 = math.cos(t) * 70;
        final dy1 = math.sin(t) * 90;
        final dx2 = math.cos(t * 0.7 + 1.5) * 80;
        final dy2 = math.sin(t * 0.7 + 1.5) * 70;
        final dx3 = math.cos(t * 0.5 + 3.0) * 60;
        final dy3 = math.sin(t * 0.5 + 3.0) * 80;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: config.bg),

            // Drifting blurred blob 1
            Positioned(
              left: -70 + dx1,
              top: 30 + dy1,
              width: 300,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blobs[0].withOpacity(config.isLight ? 0.45 : 0.28),
                ),
              ),
            ),

            // Drifting blurred blob 2
            Positioned(
              right: -110 + dx2,
              top: 290 + dy2,
              width: 320,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blobs[1 % blobs.length].withOpacity(config.isLight ? 0.45 : 0.28),
                ),
              ),
            ),

            // Drifting blurred blob 3
            Positioned(
              left: 20 + dx3,
              bottom: -60 + dy3,
              width: 280,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blobs[2 % blobs.length].withOpacity(config.isLight ? 0.40 : 0.25),
                ),
              ),
            ),

            // Backdrop blur to blend blobs
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: const SizedBox.expand(),
              ),
            ),

            // Translucent rising glass spheres
            Positioned.fill(
              child: CustomPaint(
                painter: _GlassSpheresPainter(
                  progress: _animController.value,
                  isLight: config.isLight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarpBackground(SpyThemeConfig config) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: config.bg),

            // Radial tunnel streaks
            CustomPaint(
              painter: _WarpTunnelPainter(progress: _animController.value),
            ),

            // Pulsing center magenta glow
            Center(
              child: Container(
                width: 340 + math.sin(_animController.value * 2 * math.pi) * 40,
                height: 340 + math.sin(_animController.value * 2 * math.pi) * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF2E93).withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignalBackground(SpyThemeConfig config) {
    return AnimatedBuilder(
      animation: _sweepController,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: config.bg),

            // 28px grid lines
            CustomPaint(
              painter: _SignalGridPainter(
                lineColor: config.lineColor ?? const Color(0x29B8FF3C),
              ),
            ),

            // 6-second sweeping light band
            Positioned.fill(
              child: CustomPaint(
                painter: _SignalSweepPainter(
                  progress: _sweepController.value,
                  glowColor: config.accent.withOpacity(0.12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlameShaderPainter extends CustomPainter {
  final FragmentProgram program;
  final double time;
  final Color c1, c2, c3, c4;

  _FlameShaderPainter({
    required this.program,
    required this.time,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.c4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);

    shader.setFloat(3, c1.red / 255.0);
    shader.setFloat(4, c1.green / 255.0);
    shader.setFloat(5, c1.blue / 255.0);
    shader.setFloat(6, c1.alpha / 255.0);

    shader.setFloat(7, c2.red / 255.0);
    shader.setFloat(8, c2.green / 255.0);
    shader.setFloat(9, c2.blue / 255.0);
    shader.setFloat(10, c2.alpha / 255.0);

    shader.setFloat(11, c3.red / 255.0);
    shader.setFloat(12, c3.green / 255.0);
    shader.setFloat(13, c3.blue / 255.0);
    shader.setFloat(14, c3.alpha / 255.0);

    shader.setFloat(15, c4.red / 255.0);
    shader.setFloat(16, c4.green / 255.0);
    shader.setFloat(17, c4.blue / 255.0);
    shader.setFloat(18, c4.alpha / 255.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _FlameShaderPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.c1 != c1;
}

class _EmbersPainter extends CustomPainter {
  final double progress;
  final Color coreColor;
  final Color midColor;

  _EmbersPainter({
    required this.progress,
    required this.coreColor,
    required this.midColor,
  });

  static final List<_EmberSeed> _seeds = List.generate(18, (i) {
    final rand = math.Random(i * 137);
    return _EmberSeed(
      xRatio: rand.nextDouble(),
      speed: 0.6 + rand.nextDouble() * 0.9,
      size: 2.0 + rand.nextDouble() * 3.5,
      drift: (rand.nextDouble() - 0.5) * 80.0,
      phase: rand.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final seed in _seeds) {
      final t = (progress * seed.speed + seed.phase) % 1.0;
      final y = size.height - (t * size.height * 0.95);
      final x = (seed.xRatio * size.width) + math.sin(t * 6.0) * seed.drift;

      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = coreColor.withOpacity(opacity * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      canvas.drawCircle(Offset(x, y), seed.size * (1.0 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersPainter oldDelegate) => true;
}

class _EmberSeed {
  final double xRatio;
  final double speed;
  final double size;
  final double drift;
  final double phase;

  const _EmberSeed({
    required this.xRatio,
    required this.speed,
    required this.size,
    required this.drift,
    required this.phase,
  });
}

class _GlassSpheresPainter extends CustomPainter {
  final double progress;
  final bool isLight;

  _GlassSpheresPainter({required this.progress, required this.isLight});

  static final List<_SphereSeed> _spheres = List.generate(8, (i) {
    final rand = math.Random(i * 311);
    return _SphereSeed(
      xRatio: rand.nextDouble(),
      radius: 20.0 + rand.nextDouble() * 30.0,
      speed: 0.3 + rand.nextDouble() * 0.5,
      phase: rand.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _spheres) {
      final t = (progress * s.speed + s.phase) % 1.0;
      final y = size.height + s.radius - t * (size.height + s.radius * 2);
      final x = s.xRatio * size.width + math.sin(t * 3.0) * 20.0;
      final center = Offset(x, y);

      final rect = Rect.fromCircle(center: center, radius: s.radius);
      final gradient = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [
          Colors.white.withOpacity(isLight ? 0.75 : 0.5),
          Colors.white.withOpacity(isLight ? 0.15 : 0.08),
          Colors.white.withOpacity(isLight ? 0.35 : 0.18),
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect);

      canvas.drawCircle(center, s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassSpheresPainter oldDelegate) => true;
}

class _SphereSeed {
  final double xRatio;
  final double radius;
  final double speed;
  final double phase;

  const _SphereSeed({
    required this.xRatio,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}

class _WarpTunnelPainter extends CustomPainter {
  final double progress;
  _WarpTunnelPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final maxRadius = math.max(size.width, size.height);
    const int numStreaks = 48;

    final baseAngle = progress * 2 * math.pi * 0.3;
    final streakPaint = Paint()
      ..color = const Color(0x3800F0FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < numStreaks; i++) {
      final angle = baseAngle + (i / numStreaks) * 2 * math.pi;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final startDist = 30.0 + (progress * 50.0) % 50.0;
      final p1 = center + Offset(cosA * startDist, sinA * startDist);
      final p2 = center + Offset(cosA * maxRadius, sinA * maxRadius);

      canvas.drawLine(p1, p2, streakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WarpTunnelPainter oldDelegate) => true;
}

class _SignalGridPainter extends CustomPainter {
  final Color lineColor;
  _SignalGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    const double step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _SignalSweepPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  _SignalSweepPainter({required this.progress, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final y = -90.0 + progress * (size.height + 180.0);
    const bandHeight = 90.0;

    final rect = Rect.fromLTWH(0, y, size.width, bandHeight);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          glowColor,
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SignalSweepPainter oldDelegate) => true;
}
