import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/live_config_service.dart';

/// Displays [SpyLaunchScreen] for at least 3 seconds (`minSplashMs >= 3000`)
/// while syncing [LiveConfigService] in the background, then smoothly reveals
/// [child].
class SpyLaunchGate extends StatefulWidget {
  final Widget child;
  final LiveConfigService? liveConfigService;
  final bool enableRemoteFetch;

  const SpyLaunchGate({
    super.key,
    required this.child,
    this.liveConfigService,
    this.enableRemoteFetch = true,
  });

  @override
  State<SpyLaunchGate> createState() => _SpyLaunchGateState();
}

class _SpyLaunchGateState extends State<SpyLaunchGate> {
  late final LiveConfigService _service;
  late LiveConfig _config;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _service = widget.liveConfigService ?? LiveConfigService();
    _config = _service.currentConfig.value;
    _startLaunchSequence();
  }

  Future<void> _startLaunchSequence() async {
    final initialMinMs = math.max(
      LiveConfig.minAllowedSplashMs,
      _config.minSplashMs,
    );

    final minFloorFuture = Future<void>.delayed(
      Duration(milliseconds: initialMinMs),
    );

    LiveConfig synced = _config;
    if (widget.enableRemoteFetch) {
      synced = await _service.fetchAndSync();
      if (!mounted) return;
      setState(() => _config = synced);
    }

    await minFloorFuture;
    if (!mounted) return;

    final targetMinMs = math.max(
      LiveConfig.minAllowedSplashMs,
      synced.minSplashMs,
    );
    if (targetMinMs > initialMinMs) {
      await Future<void>.delayed(
        Duration(milliseconds: targetMinMs - initialMinMs),
      );
      if (!mounted) return;
    }

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready
          ? KeyedSubtree(
              key: const ValueKey<String>('spy_launch_home'),
              child: widget.child,
            )
          : SpyLaunchScreen(
              key: const ValueKey<String>('spy_launch_screen'),
              config: _config,
            ),
    );
  }
}

/// Branded startup loading screen supporting remote-toggled seasonal themes
/// such as the Winter Update (Santa hat on the logo + falling snowfall).
class SpyLaunchScreen extends StatefulWidget {
  final LiveConfig config;

  const SpyLaunchScreen({
    super.key,
    required this.config,
  });

  @override
  State<SpyLaunchScreen> createState() => _SpyLaunchScreenState();
}

class _SpyLaunchScreenState extends State<SpyLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final showSnow = config.showSnow;
    final showHat = config.showSantaHat;
    final primaryGlow =
        showSnow ? const Color(0xFF38BDF8) : const Color(0xFFFF5A1F);
    final secondaryGlow =
        showSnow ? const Color(0xFF818CF8) : const Color(0xFFFF9800);

    final banner = config.bannerText.isNotEmpty
        ? config.bannerText
        : (config.winterUpdateEnabled ? 'winterEdition'.tr : '');

    return Material(
      color: const Color(0xFF070910),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Deep atmospheric gradient backdrop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.18),
                radius: 0.95,
                colors: [
                  primaryGlow.withOpacity(0.18),
                  secondaryGlow.withOpacity(0.08),
                  const Color(0xFF070910),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Live falling snow animation layer
          if (showSnow)
            Positioned.fill(
              child: IgnorePointer(
                key: const ValueKey<String>('spy_snow_layer'),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: SnowfallPainter(progress: _controller.value),
                    isComplex: true,
                    willChange: true,
                  ),
                ),
              ),
            ),

          // Centered logo + festive Santa hat + loading bar
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final bob = math.sin(_controller.value * math.pi * 4) *
                            3.0;
                        return Transform.translate(
                          offset: Offset(0, bob),
                          child: child,
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: const Color(0xFF101524),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.16),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGlow.withOpacity(0.32),
                                  blurRadius: 34,
                                  spreadRadius: 2,
                                ),
                                const BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26.5),
                              child: Image.asset(
                                'assets/icons/icon.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 52,
                                    color: primaryGlow,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showHat)
                            Positioned(
                              key: const ValueKey<String>('spy_santa_hat'),
                              top: -42,
                              left: 8,
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  final sway = math.sin(
                                          _controller.value * math.pi * 2) *
                                      0.035;
                                  return Transform.rotate(
                                    angle: -0.05 + sway,
                                    alignment: const Alignment(-0.2, 0.7),
                                    child: child,
                                  );
                                },
                                child: const CustomPaint(
                                  size: Size(96, 76),
                                  painter: SantaHatPainter(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'SPY MUSIC',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    if (banner.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGlow.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryGlow.withOpacity(0.38),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showSnow) ...[
                              const Icon(
                                Icons.ac_unit_rounded,
                                size: 13,
                                color: Color(0xFFBAE6FD),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                banner,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE0F2FE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 148,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 3.5,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(primaryGlow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'loadingApp'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Snowflake {
  final double xRatio;
  final double yOffset;
  final int speedMultiplier;
  final double radius;
  final double swayAmplitude;
  final double swayPhase;
  final double opacity;

  const _Snowflake({
    required this.xRatio,
    required this.yOffset,
    required this.speedMultiplier,
    required this.radius,
    required this.swayAmplitude,
    required this.swayPhase,
    required this.opacity,
  });
}

/// Renders continuous, multi-depth falling snowflakes across the launch screen.
class SnowfallPainter extends CustomPainter {
  final double progress;

  SnowfallPainter({required this.progress});

  static final List<_Snowflake> _flakes = List<_Snowflake>.generate(60, (i) {
    final rng = math.Random(i * 7919 + 42);
    return _Snowflake(
      xRatio: rng.nextDouble(),
      yOffset: rng.nextDouble(),
      speedMultiplier: 1 + rng.nextInt(3), // integer multiple keeps loop seamless
      radius: 1.6 + rng.nextDouble() * 3.6,
      swayAmplitude: 8.0 + rng.nextDouble() * 18.0,
      swayPhase: rng.nextDouble() * math.pi * 2,
      opacity: 0.28 + rng.nextDouble() * 0.62,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final flakePaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final flake in _flakes) {
      final yNorm =
          (flake.yOffset + progress * flake.speedMultiplier) % 1.0;
      final y = -12.0 + yNorm * (size.height + 24.0);
      final sway = math.sin(progress * math.pi * 2 + flake.swayPhase) *
          flake.swayAmplitude;
      final x = (flake.xRatio * size.width + sway) % size.width;
      final center = Offset(x < 0 ? x + size.width : x, y);

      glowPaint.color =
          const Color(0xFFBAE6FD).withOpacity(flake.opacity * 0.28);
      canvas.drawCircle(center, flake.radius * 1.9, glowPaint);

      flakePaint.color = Colors.white.withOpacity(flake.opacity);
      canvas.drawCircle(center, flake.radius, flakePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowfallPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Draws a festive Santa hat sitting snugly atop the app icon.
class SantaHatPainter extends CustomPainter {
  const SantaHatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Red velvet hat body curving smoothly toward right tip
    final hatPath = Path()
      ..moveTo(w * 0.10, h * 0.72)
      ..quadraticBezierTo(w * 0.18, h * 0.28, w * 0.38, h * 0.08)
      ..quadraticBezierTo(w * 0.58, h * 0.07, w * 0.76, h * 0.20)
      ..quadraticBezierTo(w * 0.94, h * 0.30, w * 0.93, h * 0.48)
      ..quadraticBezierTo(w * 0.80, h * 0.40, w * 0.72, h * 0.72)
      ..close();

    final hatPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEF4444),
          Color(0xFFDC2626),
          Color(0xFF991B1B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawShadow(hatPath, Colors.black.withOpacity(0.42), 4.0, true);
    canvas.drawPath(hatPath, hatPaint);

    // Subtle fabric highlight curve along the crown
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final highlightPath = Path()
      ..moveTo(w * 0.22, h * 0.48)
      ..quadraticBezierTo(w * 0.34, h * 0.18, w * 0.60, h * 0.16);
    canvas.drawPath(highlightPath, highlightPaint);

    // Fluffy white fur trim along brim resting on the icon's top edge
    final brimPaint = Paint()..color = const Color(0xFFF8FAFC);
    final brimShadowPaint = Paint()..color = const Color(0xFFCBD5E1);
    final brimRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.66, w * 0.70, h * 0.24),
      const Radius.circular(12),
    );
    canvas.drawRRect(brimRect.shift(const Offset(0, 2)), brimShadowPaint);
    canvas.drawRRect(brimRect, brimPaint);

    // Fluffy puffs along the fur brim for soft silhouette
    const int puffCount = 6;
    for (int i = 0; i < puffCount; i++) {
      final px = w * (0.11 + i * 0.12);
      final py = h * (i.isEven ? 0.77 : 0.80);
      canvas.drawCircle(Offset(px, py), h * 0.105, brimPaint);
    }

    // Fluffy white pom-pom at hat tip
    final pomCenter = Offset(w * 0.92, h * 0.50);
    canvas.drawCircle(
      pomCenter.translate(0, 2),
      w * 0.11,
      brimShadowPaint,
    );
    canvas.drawCircle(pomCenter, w * 0.11, brimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
