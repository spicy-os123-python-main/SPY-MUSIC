import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';
import '../custom_animations/custom_animation_painters.dart';
import '../custom_animations/dino_stalker_widget.dart';

class ThemeBackground extends StatefulWidget {
  final Widget child;
  const ThemeBackground({super.key, required this.child});

  @override
  State<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends State<ThemeBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsedTime = 0.0;
  FragmentProgram? _flameProgram;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _elapsedTime = elapsed.inMicroseconds / 1000000.0;
      });
    })..start();

    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await FragmentProgram.fromAsset('assets/shaders/flame.frag');
      if (mounted) {
        setState(() {
          _flameProgram = program;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;
      final customAnim = settingsController.customAnimationType.value;
      final isLight = Theme.of(context).brightness == Brightness.light;
      final accentColor = config?.accent ??
          (isLight ? const Color(0xFF2F7BFF) : const Color(0xFF00D2FF));
      final bgColor = config?.bg ??
          (isLight ? Theme.of(context).canvasColor : const Color(0xFF07080D));

      if (reduceEffects) {
        return Container(
          color: bgColor,
          child: widget.child,
        );
      }

      Widget bgVisual;

      if (customAnim != CustomAnimationType.none) {
        // Custom animation runs on top of the active theme base!
        bgVisual = Stack(
          fit: StackFit.expand,
          children: [
            Container(color: bgColor),
            if (config?.bgGlow != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, 1.05),
                      radius: 0.9,
                      colors: [
                        config!.bgGlow!.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: _buildCustomAnimation(customAnim, accentColor, bgColor),
            ),
          ],
        );
      } else if (config == null && isLight) {
        bgVisual = Container(color: bgColor);
      } else if (config == null) {
        bgVisual = _buildDefaultBackground();
      } else if (config.isFlame) {
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

  Widget _buildCustomAnimation(
      CustomAnimationType type, Color accent, Color bg) {
    CustomPainter painter;
    switch (type) {
      case CustomAnimationType.fireAndEmbers:
        painter = FireAndEmbersPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.neonMatrix:
        painter = NeonMatrixPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.starfieldWarp:
        painter = StarfieldWarpPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.auroraBorealis:
        painter = AuroraBorealisPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.cosmicNebula:
        painter = CosmicNebulaPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.audioWaves:
        painter = AudioWavesPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.electricStorm:
        painter = ElectricStormPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.cyberEqualizer:
        painter = CyberEqualizerPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.hexPlasmaGrid:
        painter = HexPlasmaGridPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.meteorShower:
        painter = MeteorShowerPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.liquidCaustics:
        painter = LiquidCausticsPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.sakuraBlossom:
        painter = SakuraBlossomPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.synthwaveSunset:
        painter = SynthwaveSunsetPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.cyberGlitchPulse:
        painter = CyberGlitchPulsePainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.goldenStardust:
        painter = GoldenStardustPainter(time: _elapsedTime, accent: accent);
        break;
      case CustomAnimationType.indoraptorHunt:
        return DinoStalkerWidget(time: _elapsedTime, accent: accent);
      case CustomAnimationType.none:
        return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: painter,
      size: Size.infinite,
    );
  }

  Widget _buildDefaultBackground() {
    final angle = _elapsedTime * 0.45;
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
      ],
    );
  }

  Widget _buildFlameBackground(SpyThemeConfig config) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: config.bg),

        // Deep warm or blue glow behind flame
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 1.05),
                radius: 0.85,
                colors: [
                  (config.bgGlow ?? const Color(0xFF5A0F00)).withOpacity(0.40),
                  config.bg.withOpacity(0.0),
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // Flame layer at bottom edge with seamless continuous time
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: _flameProgram != null
              ? CustomPaint(
                  painter: _FlameShaderPainter(
                    program: _flameProgram!,
                    time: _elapsedTime,
                    c1: config.flameOuter ?? const Color(0xFFFF3D00),
                    c2: config.flameMid ?? const Color(0xFFFF8A00),
                    c3: config.flameCore ?? const Color(0xFFFFD000),
                    c4: config.flameHot ?? const Color(0xFFFFFBD0),
                  ),
                )
              : _buildFlameFallback(config),
        ),

        // Rising glowing embers with continuous flow
        Positioned.fill(
          child: CustomPaint(
            painter: _EmbersPainter(
              time: _elapsedTime,
              coreColor: config.flameCore ?? const Color(0xFFFFD000),
              midColor: config.flameMid ?? const Color(0xFFFF8A00),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlameFallback(SpyThemeConfig config) {
    final t = _elapsedTime * 2.5;
    final scaleY = 0.95 + 0.08 * math.sin(t);
    return Transform.scale(
      scaleY: scaleY,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, 1.0),
            radius: 0.8,
            colors: [
              (config.flameHot ?? Colors.white).withOpacity(0.35),
              (config.flameCore ?? Colors.yellow).withOpacity(0.25),
              (config.flameMid ?? Colors.orange).withOpacity(0.15),
              (config.flameOuter ?? Colors.red).withOpacity(0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBackground(SpyThemeConfig config) {
    final blobs = config.glassBlobs ??
        [
          const Color(0xFF2A5BFF),
          const Color(0xFF00C2C7),
          const Color(0xFFC13CFF)
        ];

    final t = _elapsedTime * 0.4;
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
              color: blobs[1 % blobs.length]
                  .withOpacity(config.isLight ? 0.45 : 0.28),
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
              color: blobs[2 % blobs.length]
                  .withOpacity(config.isLight ? 0.40 : 0.25),
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

        // Translucent rising glass spheres with continuous flow
        Positioned.fill(
          child: CustomPaint(
            painter: _GlassSpheresPainter(
              time: _elapsedTime,
              isLight: config.isLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarpBackground(SpyThemeConfig config) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: config.bg),

        // Radial tunnel streaks with continuous rotation
        CustomPaint(
          painter: _WarpTunnelPainter(time: _elapsedTime),
        ),

        // Pulsing center magenta glow
        Center(
          child: Container(
            width: 340 + math.sin(_elapsedTime * 1.5) * 40,
            height: 340 + math.sin(_elapsedTime * 1.5) * 40,
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
  }

  Widget _buildSignalBackground(SpyThemeConfig config) {
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

        // Continuous sweeping light band
        Positioned.fill(
          child: CustomPaint(
            painter: _SignalSweepPainter(
              time: _elapsedTime,
              glowColor: config.accent.withOpacity(0.12),
            ),
          ),
        ),
      ],
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
  bool shouldRepaint(covariant _FlameShaderPainter oldDelegate) => true;
}

class _EmbersPainter extends CustomPainter {
  final double time;
  final Color coreColor;
  final Color midColor;

  _EmbersPainter({
    required this.time,
    required this.coreColor,
    required this.midColor,
  });

  static final List<_EmberSeed> _seeds = List.generate(24, (i) {
    final rand = math.Random(i * 137);
    return _EmberSeed(
      xRatio: rand.nextDouble(),
      speed: 0.12 + rand.nextDouble() * 0.22,
      size: 2.0 + rand.nextDouble() * 3.5,
      drift: (rand.nextDouble() - 0.5) * 80.0,
      phase: rand.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final seed in _seeds) {
      final t = (time * seed.speed + seed.phase) % 1.0;
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
  final double time;
  final bool isLight;

  _GlassSpheresPainter({required this.time, required this.isLight});

  static final List<_SphereSeed> _spheres = List.generate(10, (i) {
    final rand = math.Random(i * 311);
    return _SphereSeed(
      xRatio: rand.nextDouble(),
      radius: 20.0 + rand.nextDouble() * 30.0,
      speed: 0.08 + rand.nextDouble() * 0.14,
      phase: rand.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _spheres) {
      final t = (time * s.speed + s.phase) % 1.0;
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

      final paint = Paint()..shader = gradient.createShader(rect);

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
  final double time;
  _WarpTunnelPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final maxRadius = math.max(size.width, size.height);
    const int numStreaks = 48;

    final baseAngle = time * 0.2;
    final streakPaint = Paint()
      ..color = const Color(0x3800F0FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final startDist = 30.0 + ((time * 25.0) % 50.0);

    for (int i = 0; i < numStreaks; i++) {
      final angle = baseAngle + (i / numStreaks) * 2 * math.pi;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

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
  final double time;
  final Color glowColor;
  _SignalSweepPainter({required this.time, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final progress = (time * 0.2) % 1.0;
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
