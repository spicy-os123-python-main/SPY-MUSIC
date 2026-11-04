import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CustomAnimationType {
  none,
  fireAndEmbers,
  neonMatrix,
  starfieldWarp,
  auroraBorealis,
  cosmicNebula,
  audioWaves,
  electricStorm,
  cyberEqualizer,
  hexPlasmaGrid,
  meteorShower,
  liquidCaustics,
  sakuraBlossom,
  synthwaveSunset,
  cyberGlitchPulse,
  goldenStardust,
}

String getCustomAnimationName(CustomAnimationType type) {
  switch (type) {
    case CustomAnimationType.none:
      return "Aus / Theme-Standard";
    case CustomAnimationType.fireAndEmbers:
      return "1. Feuer & Funken";
    case CustomAnimationType.neonMatrix:
      return "2. Cyber Matrix (Code Rain)";
    case CustomAnimationType.starfieldWarp:
      return "3. Starfield Hyperdrive";
    case CustomAnimationType.auroraBorealis:
      return "4. Nordlichter (Aurora)";
    case CustomAnimationType.cosmicNebula:
      return "5. Sternennebel (Nebula)";
    case CustomAnimationType.audioWaves:
      return "6. Wellen & Frequenzen";
    case CustomAnimationType.electricStorm:
      return "7. Gewitter & Blitze";
    case CustomAnimationType.cyberEqualizer:
      return "8. Cyber Equalizer";
    case CustomAnimationType.hexPlasmaGrid:
      return "9. Wabengitter Plasma";
    case CustomAnimationType.meteorShower:
      return "10. Sternschnuppen";
    case CustomAnimationType.liquidCaustics:
      return "11. Wasserwellen & Reflektionen";
    case CustomAnimationType.sakuraBlossom:
      return "12. Kirschblütenzauber";
    case CustomAnimationType.synthwaveSunset:
      return "13. 80s Retro Synthwave";
    case CustomAnimationType.cyberGlitchPulse:
      return "14. Hacker Glitch & Scanlines";
    case CustomAnimationType.goldenStardust:
      return "15. Goldstaub & Bokeh";
  }
}

String getCustomAnimationDescription(CustomAnimationType type) {
  switch (type) {
    case CustomAnimationType.none:
      return "Nutzt die standardmäßige Hintergrund-Optik des aktiven Themes";
    case CustomAnimationType.fireAndEmbers:
      return "Aufsteigende Feuerzungen, Hitzewellen und schwebende Funken";
    case CustomAnimationType.neonMatrix:
      return "Herabfallender digitaler Cyber-Code-Regen im Matrix-Stil";
    case CustomAnimationType.starfieldWarp:
      return "Hyperspace-Sternenfeld mit 3D-Lichtgeschwindigkeit";
    case CustomAnimationType.auroraBorealis:
      return "Majestätisch schimmernde Polarlichter-Wellen";
    case CustomAnimationType.cosmicNebula:
      return "Rotierende Weltraum-Gaswolken mit pulsierenden Sternen";
    case CustomAnimationType.audioWaves:
      return "Flüssig pulsierende organische Audio-Sinuswellen";
    case CustomAnimationType.electricStorm:
      return "Verzweigte Plasma-Blitze und energetische Entladungen";
    case CustomAnimationType.cyberEqualizer:
      return "Futuristische Frequenz-Lichttürme mit Schwebespitzen";
    case CustomAnimationType.hexPlasmaGrid:
      return "Pulsierendes futuristisches Nanotech-Wabenmuster";
    case CustomAnimationType.meteorShower:
      return "Leuchtende Sternschnuppen mit glitzernden Schweifen";
    case CustomAnimationType.liquidCaustics:
      return "Sonnenlicht-Wasserreflektionen und sich ausbreitende Tropfen";
    case CustomAnimationType.sakuraBlossom:
      return "Sanft im Wind tanzende Kirschblütenblätter";
    case CustomAnimationType.synthwaveSunset:
      return "80er-Jahre Perspektivgitter mit leuchtender Retro-Sonne";
    case CustomAnimationType.cyberGlitchPulse:
      return "High-Tech Scanlines mit Farbverzerrungen und Signalimpulsen";
    case CustomAnimationType.goldenStardust:
      return "Schwebender Luxus-Goldstaub mit funkelnden Sternen";
  }
}

// -----------------------------------------------------------------------------
// 1. Fire & Embers Painter
// -----------------------------------------------------------------------------
class FireAndEmbersPainter extends CustomPainter {
  final double time;
  final Color accent;
  FireAndEmbersPainter({required this.time, required this.accent});

  static final List<_Ember> _embers = List.generate(32, (i) {
    final r = math.Random(i * 101 + 7);
    return _Ember(
      xRatio: r.nextDouble(),
      speed: 0.15 + r.nextDouble() * 0.25,
      size: 1.5 + r.nextDouble() * 3.5,
      drift: (r.nextDouble() - 0.5) * 60,
      phase: r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Bottom flame glow
    final flameHeight = size.height * 0.28;
    final flameRect = Rect.fromLTWH(0, size.height - flameHeight, size.width, flameHeight);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          accent.withOpacity(0.35),
          const Color(0xFFFF5500).withOpacity(0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(flameRect);
    canvas.drawRect(flameRect, glowPaint);

    // Dynamic flame wave curves
    final wavePath = Path();
    wavePath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 12) {
      final yOffset = math.sin((x * 0.02) + (time * 3.5)) * 18 +
          math.cos((x * 0.04) - (time * 2.2)) * 12;
      wavePath.lineTo(x, size.height - (flameHeight * 0.5) + yOffset);
    }
    wavePath.lineTo(size.width, size.height);
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFCC00).withOpacity(0.28),
          accent.withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(flameRect);
    canvas.drawPath(wavePath, wavePaint);

    // Rising embers
    for (final ember in _embers) {
      final progress = (time * ember.speed + ember.phase) % 1.0;
      final y = size.height - (progress * size.height * 0.88);
      final x = (ember.xRatio * size.width) + math.sin(progress * 8.0 + ember.phase) * ember.drift;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final p = Paint()
        ..color = (progress < 0.5 ? const Color(0xFFFFE066) : accent).withOpacity(opacity * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(x, y), ember.size * (1.0 - progress * 0.4), p);
    }
  }

  @override
  bool shouldRepaint(covariant FireAndEmbersPainter oldDelegate) => true;
}

class _Ember {
  final double xRatio, speed, size, drift, phase;
  const _Ember({required this.xRatio, required this.speed, required this.size, required this.drift, required this.phase});
}

// -----------------------------------------------------------------------------
// 2. Cyber Matrix (Code Rain) Painter
// -----------------------------------------------------------------------------
class NeonMatrixPainter extends CustomPainter {
  final double time;
  final Color accent;
  NeonMatrixPainter({required this.time, required this.accent});

  static final List<_MatrixCol> _cols = List.generate(36, (i) {
    final r = math.Random(i * 313);
    return _MatrixCol(
      xRatio: (i + 0.5) / 36.0,
      speed: 0.12 + r.nextDouble() * 0.22,
      length: 120 + r.nextDouble() * 160,
      phase: r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final matrixColor = accent == const Color(0xFF00F0FF) ? const Color(0xFF00FF88) : accent;

    for (final col in _cols) {
      final t = (time * col.speed + col.phase) % 1.0;
      final headY = t * (size.height + col.length);
      final x = col.xRatio * size.width;

      final rect = Rect.fromLTWH(x - 1, headY - col.length, 3, col.length);
      final p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            matrixColor.withOpacity(0.18),
            matrixColor.withOpacity(0.65),
            Colors.white,
          ],
          stops: const [0.0, 0.4, 0.85, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, p);
      // Bright head dot
      canvas.drawCircle(
        Offset(x, headY),
        2.2,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NeonMatrixPainter oldDelegate) => true;
}

class _MatrixCol {
  final double xRatio, speed, length, phase;
  const _MatrixCol({required this.xRatio, required this.speed, required this.length, required this.phase});
}

// -----------------------------------------------------------------------------
// 3. Starfield Hyperdrive Painter
// -----------------------------------------------------------------------------
class StarfieldWarpPainter extends CustomPainter {
  final double time;
  final Color accent;
  StarfieldWarpPainter({required this.time, required this.accent});

  static final List<_Star3D> _stars = List.generate(110, (i) {
    final r = math.Random(i * 47);
    return _Star3D(
      angle: r.nextDouble() * 2 * math.pi,
      radiusRatio: 0.05 + r.nextDouble() * 0.95,
      speed: 0.25 + r.nextDouble() * 0.65,
      phase: r.nextDouble(),
      size: 1.2 + r.nextDouble() * 2.2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.44);
    final maxDist = math.max(size.width, size.height) * 0.75;

    for (final s in _stars) {
      final progress = (time * s.speed + s.phase) % 1.0;
      final dist = math.pow(progress, 1.8) * maxDist;
      final prevDist = math.max(0.0, dist - (progress * 28.0));

      final cosA = math.cos(s.angle);
      final sinA = math.sin(s.angle);

      final p1 = center + Offset(cosA * prevDist, sinA * prevDist);
      final p2 = center + Offset(cosA * dist, sinA * dist);

      final opacity = (progress < 0.15 ? progress / 0.15 : (1.0 - progress)).clamp(0.0, 1.0);
      final p = Paint()
        ..color = Color.lerp(Colors.white, accent, progress)!.withOpacity(opacity * 0.8)
        ..strokeWidth = s.size * (0.8 + progress * 1.5)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, p);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldWarpPainter oldDelegate) => true;
}

class _Star3D {
  final double angle, radiusRatio, speed, phase, size;
  const _Star3D({required this.angle, required this.radiusRatio, required this.speed, required this.phase, required this.size});
}

// -----------------------------------------------------------------------------
// 4. Aurora Borealis Painter
// -----------------------------------------------------------------------------
class AuroraBorealisPainter extends CustomPainter {
  final double time;
  final Color accent;
  AuroraBorealisPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF00FFB2),
      accent,
      const Color(0xFF7000FF),
      const Color(0xFF00E5FF),
    ];

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final baseY = size.height * (0.15 + i * 0.12);
      path.moveTo(0, baseY);

      for (double x = 0; x <= size.width; x += 14) {
        final wave1 = math.sin((x * 0.006) + (time * 0.8) + (i * 1.2)) * 40;
        final wave2 = math.cos((x * 0.012) - (time * 0.5) + i) * 25;
        path.lineTo(x, baseY + wave1 + wave2);
      }
      path.lineTo(size.width, size.height * 0.65);
      path.lineTo(0, size.height * 0.65);
      path.close();

      final c = colors[i % colors.length];
      final p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.withOpacity(0.24),
            c.withOpacity(0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, baseY - 50, size.width, size.height * 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18.0);

      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant AuroraBorealisPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 5. Cosmic Nebula Painter
// -----------------------------------------------------------------------------
class CosmicNebulaPainter extends CustomPainter {
  final double time;
  final Color accent;
  CosmicNebulaPainter({required this.time, required this.accent});

  static final List<Offset> _stars = List.generate(45, (i) {
    final r = math.Random(i * 991);
    return Offset(r.nextDouble(), r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Rotating nebula dust cloud 1
    final angle1 = time * 0.1;
    final c1 = Offset(
      size.width * 0.4 + math.cos(angle1) * 45,
      size.height * 0.35 + math.sin(angle1) * 35,
    );
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withOpacity(0.22),
          const Color(0xFF9400D3).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c1, radius: 210));
    canvas.drawCircle(c1, 210, p1);

    // Rotating nebula dust cloud 2
    final angle2 = -time * 0.08 + 1.5;
    final c2 = Offset(
      size.width * 0.65 + math.cos(angle2) * 50,
      size.height * 0.55 + math.sin(angle2) * 40,
    );
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D4FF).withOpacity(0.20),
          accent.withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c2, radius: 240));
    canvas.drawCircle(c2, 240, p2);

    // Twinkling stars
    for (int i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final twinkle = 0.4 + 0.6 * math.sin(time * 3.0 + i * 2.1);
      final p = Paint()..color = Colors.white.withOpacity(twinkle * 0.85);
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 1.2 + twinkle * 0.8, p);
    }
  }

  @override
  bool shouldRepaint(covariant CosmicNebulaPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 6. Audio Visualizer Waves Painter
// -----------------------------------------------------------------------------
class AudioWavesPainter extends CustomPainter {
  final double time;
  final Color accent;
  AudioWavesPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const waveCount = 4;
    final midY = size.height * 0.62;

    for (int w = 0; w < waveCount; w++) {
      final path = Path();
      path.moveTo(0, midY);

      final freq = 0.008 + w * 0.004;
      final speed = (w % 2 == 0 ? 1.0 : -0.8) * (1.8 + w * 0.5);
      final amp = 24.0 + (w * 10.0);

      for (double x = 0; x <= size.width; x += 8) {
        final y = midY +
            math.sin((x * freq) + (time * speed)) * amp *
            math.cos((x * 0.003) + (time * 0.6));
        path.lineTo(x, y);
      }

      final opacity = 0.28 + (w * 0.16);
      final strokePaint = Paint()
        ..color = (w % 2 == 0 ? accent : Colors.white).withOpacity(opacity)
        ..strokeWidth = 1.8 + w * 0.4
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0 + w);

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioWavesPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 7. Electric Storm & Plasma Painter
// -----------------------------------------------------------------------------
class ElectricStormPainter extends CustomPainter {
  final double time;
  final Color accent;
  ElectricStormPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random((time * 4.0).floor());
    final hasFlash = rand.nextDouble() < 0.45;

    if (hasFlash) {
      final start = Offset(rand.nextDouble() * size.width, 0);
      final points = <Offset>[start];
      Offset current = start;

      while (current.dy < size.height * 0.75) {
        final nextX = current.dx + (rand.nextDouble() - 0.5) * 55;
        final nextY = current.dy + 15 + rand.nextDouble() * 35;
        current = Offset(nextX.clamp(10.0, size.width - 10.0), nextY);
        points.add(current);
      }

      final boltPath = Path();
      boltPath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        boltPath.lineTo(points[i].dx, points[i].dy);
      }

      // Outer glow
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = accent.withOpacity(0.55)
          ..strokeWidth = 6.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
      );

      // Core white bolt
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ElectricStormPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 8. Cyber Equalizer Bars Painter
// -----------------------------------------------------------------------------
class CyberEqualizerPainter extends CustomPainter {
  final double time;
  final Color accent;
  CyberEqualizerPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 28;
    final barWidth = (size.width - ((barCount + 1) * 3)) / barCount;
    final bottomY = size.height;
    final maxBarHeight = size.height * 0.32;

    for (int i = 0; i < barCount; i++) {
      final x = 3.0 + i * (barWidth + 3.0);
      final wave = 0.5 +
          0.3 * math.sin(time * 4.0 + i * 0.4) +
          0.2 * math.cos(time * 6.0 + i * 0.7);
      final height = (wave.clamp(0.05, 1.0)) * maxBarHeight;

      final rect = Rect.fromLTWH(x, bottomY - height, barWidth, height);
      final p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accent.withOpacity(0.12),
            accent.withOpacity(0.55),
            Colors.white,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(rect);

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), p);

      // Floating peak cap
      final peakY = bottomY - height - 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, peakY, barWidth, 2.5),
          const Radius.circular(1),
        ),
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberEqualizerPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 9. Cyber Hex Grid (Wabengitter Plasma) Painter
// -----------------------------------------------------------------------------
class HexPlasmaGridPainter extends CustomPainter {
  final double time;
  final Color accent;
  HexPlasmaGridPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 32.0;
    final double hexWidth = math.sqrt(3) * radius;
    const double hexHeight = 2 * radius;
    const double vertSpacing = 48.0;

    final gridPaint = Paint()
      ..color = accent.withOpacity(0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    int colIndex = 0;
    for (double y = 0; y < size.height + hexHeight; y += vertSpacing) {
      final double xOffset = (colIndex % 2 == 1) ? hexWidth / 2 : 0;
      for (double x = -hexWidth; x < size.width + hexWidth; x += hexWidth) {
        final center = Offset(x + xOffset, y);
        _drawHex(canvas, center, radius, gridPaint);

        // Occasional pulse in hex
        final pulseDist = (center.dx + center.dy) * 0.005 - (time * 1.5);
        final pulse = math.sin(pulseDist);
        if (pulse > 0.85) {
          final intensity = (pulse - 0.85) / 0.15;
          final pulsePaint = Paint()
            ..color = accent.withOpacity(intensity * 0.45)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke;
          _drawHex(canvas, center, radius, pulsePaint);
        }
      }
      colIndex++;
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 + 30) * math.pi / 180;
      final pt = center + Offset(r * math.cos(angle), r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HexPlasmaGridPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 10. Meteor Shower Painter
// -----------------------------------------------------------------------------
class MeteorShowerPainter extends CustomPainter {
  final double time;
  final Color accent;
  MeteorShowerPainter({required this.time, required this.accent});

  static final List<_Meteor> _meteors = List.generate(14, (i) {
    final r = math.Random(i * 773 + 1);
    return _Meteor(
      startXRatio: r.nextDouble(),
      speed: 0.35 + r.nextDouble() * 0.5,
      length: 120 + r.nextDouble() * 140,
      phase: r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in _meteors) {
      final progress = (time * m.speed + m.phase) % 1.0;
      final startX = m.startXRatio * size.width;
      const startY = -40.0;
      final travel = progress * (size.height + 300.0);

      final headX = startX + travel * 0.55;
      final headY = startY + travel;

      final tailX = headX - (m.length * 0.55);
      final tailY = headY - m.length;

      final p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            accent.withOpacity(0.35),
            Colors.white,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromPoints(Offset(tailX, tailY), Offset(headX, headY)))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), p);
      canvas.drawCircle(Offset(headX, headY), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant MeteorShowerPainter oldDelegate) => true;
}

class _Meteor {
  final double startXRatio, speed, length, phase;
  const _Meteor({required this.startXRatio, required this.speed, required this.length, required this.phase});
}

// -----------------------------------------------------------------------------
// 11. Liquid Caustics & Water Ripple Painter
// -----------------------------------------------------------------------------
class LiquidCausticsPainter extends CustomPainter {
  final double time;
  final Color accent;
  LiquidCausticsPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = accent.withOpacity(0.14);
    final p = Paint()
      ..color = c
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // Expanding water ripples
    for (int i = 0; i < 4; i++) {
      final t = (time * 0.25 + (i * 0.25)) % 1.0;
      final r = t * 180.0;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final rippleCenter = Offset(
        size.width * (0.3 + (i % 2) * 0.4),
        size.height * (0.4 + (i ~/ 2) * 0.3),
      );
      canvas.drawCircle(
        rippleCenter,
        r,
        Paint()
          ..color = accent.withOpacity(alpha * 0.25)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
    }

    // Caustic harmonic light webs
    final path = Path();
    for (double y = 0; y < size.height; y += 40) {
      path.moveTo(0, y);
      for (double x = 0; x <= size.width; x += 20) {
        final wave = math.sin((x * 0.015) + (time * 1.4)) * 14 +
            math.cos((y * 0.02) + (time * 1.1)) * 10;
        path.lineTo(x, y + wave);
      }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant LiquidCausticsPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 12. Sakura Blossom Drift Painter
// -----------------------------------------------------------------------------
class SakuraBlossomPainter extends CustomPainter {
  final double time;
  final Color accent;
  SakuraBlossomPainter({required this.time, required this.accent});

  static final List<_SakuraPetal> _petals = List.generate(28, (i) {
    final r = math.Random(i * 541);
    return _SakuraPetal(
      startXRatio: r.nextDouble(),
      speed: 0.12 + r.nextDouble() * 0.18,
      size: 6.0 + r.nextDouble() * 7.0,
      phase: r.nextDouble(),
      rotationSpeed: 1.0 + r.nextDouble() * 2.5,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    const petalPink = Color(0xFFFFB7D5);

    for (final petal in _petals) {
      final t = (time * petal.speed + petal.phase) % 1.0;
      final y = t * (size.height + 60.0) - 30;
      final x = (petal.startXRatio * size.width) + math.sin(t * 6.0 + petal.phase) * 50;

      final angle = time * petal.rotationSpeed + petal.phase;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final p = Paint()
        ..color = petalPink.withOpacity(0.75)
        ..style = PaintingStyle.fill;

      // Draw petal oval
      final rect = Rect.fromCenter(center: Offset.zero, width: petal.size, height: petal.size * 0.55);
      canvas.drawOval(rect, p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SakuraBlossomPainter oldDelegate) => true;
}

class _SakuraPetal {
  final double startXRatio, speed, size, phase, rotationSpeed;
  const _SakuraPetal({required this.startXRatio, required this.speed, required this.size, required this.phase, required this.rotationSpeed});
}

// -----------------------------------------------------------------------------
// 13. 80s Synthwave Grid & Sun Painter
// -----------------------------------------------------------------------------
class SynthwaveSunsetPainter extends CustomPainter {
  final double time;
  final Color accent;
  SynthwaveSunsetPainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * 0.55;

    // Glowing Synthwave Sun
    final sunRadius = size.width * 0.22;
    final sunCenter = Offset(size.width * 0.5, horizonY - sunRadius * 0.4);

    final sunShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFEE55),
        Color(0xFFFF0077),
      ],
    ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    canvas.drawCircle(sunCenter, sunRadius, Paint()..shader = sunShader);

    // Sun horizontal scanline cuts
    for (double sy = sunCenter.dy; sy < sunCenter.dy + sunRadius; sy += 9) {
      canvas.drawLine(
        Offset(sunCenter.dx - sunRadius, sy),
        Offset(sunCenter.dx + sunRadius, sy),
        Paint()
          ..color = const Color(0xFF070312)
          ..strokeWidth = 2.5,
      );
    }

    // Perspective wireframe grid
    final gridPaint = Paint()
      ..color = const Color(0xFFFF00AA).withOpacity(0.4)
      ..strokeWidth = 1.2;

    // Horizontal rolling lines
    final t = (time * 0.6) % 1.0;
    for (int i = 1; i <= 12; i++) {
      final depth = (i + t) / 13.0;
      final y = horizonY + math.pow(depth, 2.4) * (size.height - horizonY);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Perspective vanishing rays
    final vp = Offset(size.width * 0.5, horizonY);
    for (double x = -size.width * 0.5; x <= size.width * 1.5; x += size.width * 0.14) {
      canvas.drawLine(vp, Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SynthwaveSunsetPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 14. Hacker Glitch & Scanlines Painter
// -----------------------------------------------------------------------------
class CyberGlitchPulsePainter extends CustomPainter {
  final double time;
  final Color accent;
  CyberGlitchPulsePainter({required this.time, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle CRT scanlines
    final scanlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // Rolling scan beam
    final beamY = ((time * 0.25) % 1.0) * size.height;
    final beamRect = Rect.fromLTWH(0, beamY - 40, size.width, 80);
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          accent.withOpacity(0.14),
          Colors.transparent,
        ],
      ).createShader(beamRect);
    canvas.drawRect(beamRect, beamPaint);

    // Sporadic horizontal glitch blocks
    final rand = math.Random((time * 6.0).floor());
    if (rand.nextDouble() < 0.35) {
      final gy = rand.nextDouble() * size.height;
      final gh = 4.0 + rand.nextDouble() * 16.0;
      final gw = 40.0 + rand.nextDouble() * (size.width * 0.6);
      final gx = rand.nextDouble() * (size.width - gw);

      final glitchPaint = Paint()
        ..color = (rand.nextBool() ? accent : const Color(0xFFFF0055)).withOpacity(0.35);
      canvas.drawRect(Rect.fromLTWH(gx, gy, gw, gh), glitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberGlitchPulsePainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// 15. Golden Stardust & Bokeh Painter
// -----------------------------------------------------------------------------
class GoldenStardustPainter extends CustomPainter {
  final double time;
  final Color accent;
  GoldenStardustPainter({required this.time, required this.accent});

  static final List<_GoldOrb> _orbs = List.generate(34, (i) {
    final r = math.Random(i * 449);
    return _GoldOrb(
      xRatio: r.nextDouble(),
      speed: 0.08 + r.nextDouble() * 0.15,
      radius: 4.0 + r.nextDouble() * 18.0,
      phase: r.nextDouble(),
      isSparkle: r.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gold1 = Color(0xFFFFDF73);
    const gold2 = Color(0xFFFFB800);

    for (final orb in _orbs) {
      final t = (time * orb.speed + orb.phase) % 1.0;
      final y = size.height - (t * (size.height + 40.0));
      final x = (orb.xRatio * size.width) + math.sin(t * 5.0 + orb.phase) * 35;
      final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0);

      if (orb.isSparkle) {
        // 4-point golden star flare
        final sparklePaint = Paint()
          ..color = gold1.withOpacity(opacity * 0.85)
          ..strokeWidth = 1.4;
        const len = 7.0;
        canvas.drawLine(Offset(x - len, y), Offset(x + len, y), sparklePaint);
        canvas.drawLine(Offset(x, y - len), Offset(x, y + len), sparklePaint);
        canvas.drawCircle(Offset(x, y), 1.8, Paint()..color = Colors.white.withOpacity(opacity));
      } else {
        // Soft glowing bokeh orb
        final p = Paint()
          ..shader = RadialGradient(
            colors: [
              gold2.withOpacity(opacity * 0.5),
              gold1.withOpacity(opacity * 0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: orb.radius));
        canvas.drawCircle(Offset(x, y), orb.radius, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoldenStardustPainter oldDelegate) => true;
}

class _GoldOrb {
  final double xRatio, speed, radius, phase;
  final bool isSparkle;
  const _GoldOrb({required this.xRatio, required this.speed, required this.radius, required this.phase, required this.isSparkle});
}

