import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fully animated procedural & 3D Indoraptor simulation.
///
/// Features:
/// - Full theropod digitigrade leg locomotion (thigh, knee, shin, raised ankle, foot, toes, and sickle claw).
/// - Articulated 8-segment serpentine whip tail with counterbalancing wave dynamics.
/// - Heavy muscular ribcage with dynamic breathing and dorsal spines.
/// - Iconic Indoraptor obsidian scale shading with the signature golden-amber lateral stripe.
/// - Full 3D perspective turn when halting in the center:
///   The head, neck, and chest twist toward the viewer, staring directly out of the screen
///   with glowing amber slit-pupil eyes, unhinging its jaws in a terrifying snarl with razor teeth,
///   breathing deeply with chest heaves and misty breath vapor before turning back and stalking off.
/// - Alternating cycle: reverses direction and walks from the opposite side every cycle.
class DinoStalkerWidget extends StatelessWidget {
  final double time;
  final Color accent;

  const DinoStalkerWidget({
    super.key,
    required this.time,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        if (screenWidth <= 0 || screenHeight <= 0) {
          return const SizedBox.shrink();
        }

        // Total cycle duration: 14.5 seconds
        const double cycleDuration = 14.5;
        final double t = time % cycleDuration;
        final int cycleIndex = (time / cycleDuration).floor();

        // Alternating walking direction: Even = Left-to-Right, Odd = Right-to-Left
        final bool walkLeftToRight = (cycleIndex % 2) == 0;

        // Proportional sizing: dinosaur spans ~440px wide in profile
        final double baseDinoWidth = (screenWidth * 0.95).clamp(320.0, 520.0);
        final double scale = baseDinoWidth / 440.0;
        final double dinoHeight = 310.0 * scale;

        // Position in the lower portion of the screen (ground line)
        final double groundY = (screenHeight * 0.65).clamp(180.0, screenHeight - 90.0);
        final double dinoY = groundY - (220.0 * scale);

        // Movement timeline
        double dinoX;
        double walkVelocity = 0.0;
        double turn3D = 0.0; // 0.0 = profile, 1.0 = fully facing user
        double jawOpen = 0.0; // 0.0 = closed, 1.0 = open snarl
        double opacity = 0.92;

        if (t < 4.8) {
          // --- Phase 1: Stalking from offscreen into center (0.0s - 4.8s) ---
          final double p = t / 4.8;
          final double curved = Curves.easeOutQuad.transform(p);
          final double startX = -baseDinoWidth * 0.9;
          final double centerX = (screenWidth - baseDinoWidth) / 2.0;
          dinoX = startX + (centerX - startX) * curved;

          // Velocity for leg stride
          walkVelocity = (1.0 - p * 0.75).clamp(0.2, 1.0);
        } else if (t < 7.5) {
          // --- Phase 2: HALTED IN CENTER - 3D TURN & MENACING CONFRONTATION (4.8s - 7.5s = 2.7s) ---
          dinoX = (screenWidth - baseDinoWidth) / 2.0;
          walkVelocity = 0.0; // Standing stationary

          final double confrontationT = t - 4.8; // 0.0 to 2.7s

          if (confrontationT < 0.7) {
            // Turning in 3D from profile towards user
            final double tp = confrontationT / 0.7;
            turn3D = Curves.easeInOutCubic.transform(tp);
            jawOpen = Curves.easeOutBack.transform(tp) * 0.85;
          } else if (confrontationT < 2.0) {
            // Locked onto user: Breathing, snarl, pulsing glare
            turn3D = 1.0;
            final double snarlWave = math.sin((confrontationT - 0.7) * 4.5).abs();
            jawOpen = 0.65 + (snarlWave * 0.35);
          } else {
            // Turning back in 3D from user to walking direction
            final double tp = (confrontationT - 2.0) / 0.7;
            turn3D = 1.0 - Curves.easeInOutCubic.transform(tp);
            jawOpen = (1.0 - tp) * 0.65;
          }
        } else if (t < 11.5) {
          // --- Phase 3: Resumes stalking forward and exits screen (7.5s - 11.5s) ---
          final double p = (t - 7.5) / 4.0;
          final double curved = Curves.easeInQuad.transform(p);
          final double centerX = (screenWidth - baseDinoWidth) / 2.0;
          final double endX = screenWidth + 80.0;
          dinoX = centerX + (endX - centerX) * curved;

          walkVelocity = (p * 0.8 + 0.2).clamp(0.2, 1.0);
        } else {
          // --- Phase 4: Lurking in darkness off-screen (11.5s - 14.5s) ---
          dinoX = screenWidth + 500.0;
          walkVelocity = 0.0;
          opacity = 0.0;
        }

        // Mirrored coordinate when walking right-to-left
        final double finalX = walkLeftToRight ? dinoX : (screenWidth - baseDinoWidth - dinoX);
        final double flipX = walkLeftToRight ? 1.0 : -1.0;

        return Positioned(
          left: finalX,
          top: dinoY,
          width: baseDinoWidth,
          height: dinoHeight,
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(flipX, 1.0),
              child: CustomPaint(
                size: Size(baseDinoWidth, dinoHeight),
                painter: Indoraptor3DPainter(
                  time: time,
                  walkVelocity: walkVelocity,
                  turn3D: turn3D,
                  jawOpen: jawOpen,
                  scale: scale,
                  accentColor: accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that renders the fully articulated 3D Indoraptor.
class Indoraptor3DPainter extends CustomPainter {
  final double time;
  final double walkVelocity;
  final double turn3D; // 0.0 = Profile, 1.0 = Facing user in 3D
  final double jawOpen; // 0.0 = Closed, 1.0 = Fully open
  final double scale;
  final Color accentColor;

  Indoraptor3DPainter({
    required this.time,
    required this.walkVelocity,
    required this.turn3D,
    required this.jawOpen,
    required this.scale,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);

    // Anatomical base coordinates (in 440 x 310 reference space)
    const double groundY = 270.0;

    // Breathing rhythm: expands chest, raises shoulders
    final double breath = math.sin(time * 3.2) * (turn3D > 0.5 ? 3.5 : 1.8);

    // Stride walk cycle phase
    final double walkPhase = time * 7.2 * (walkVelocity > 0 ? 1.0 : 0.0);
    final double bodyBob = (walkVelocity > 0 ? math.sin(walkPhase * 2.0).abs() * 5.5 : 0.0) + breath;

    // Pelvis (Hip) and Chest locations
    final Offset hip = Offset(170.0, 140.0 + bodyBob);
    final Offset chest = Offset(245.0, 130.0 + (bodyBob * 0.7) - breath);
    final Offset neckBase = Offset(275.0, 118.0 + (bodyBob * 0.5) - breath);

    // 1. Dynamic ground shadow
    _drawGroundShadow(canvas, hip, chest, groundY, walkPhase);

    // 2. Far limbs (rendered behind torso with dark ambient occlusion)
    _drawLeg(
      canvas: canvas,
      hip: Offset(hip.dx - 8.0, hip.dy - 4.0),
      groundY: groundY,
      phase: walkPhase + math.pi, // 180 deg out of phase with near leg
      isFar: true,
    );

    _drawArm(
      canvas: canvas,
      shoulder: Offset(chest.dx - 6.0, chest.dy + 12.0),
      phase: walkPhase + math.pi,
      isFar: true,
    );

    // 3. Tail: 8-segment articulated vertebral chain with counter-swaying wave physics
    _drawArticulatedTail(canvas, hip, walkPhase);

    // 4. Torso, Pelvis, Muscular Flank & Signature Golden Flank Stripe
    _drawTorso(canvas, hip, chest, breath);

    // 5. Near Leg (foreground: full muscle definition, specular shine & sickle claw)
    _drawLeg(
      canvas: canvas,
      hip: hip,
      groundY: groundY,
      phase: walkPhase,
      isFar: false,
    );

    // 6. Near Arm (foreground: reaching grasping raptor claws)
    _drawArm(
      canvas: canvas,
      shoulder: Offset(chest.dx + 4.0, chest.dy + 14.0),
      phase: walkPhase,
      isFar: false,
    );

    // 7. Neck & 3D Skull (Profile to 3D Confrontation with User)
    _drawArticulatedHeadAndNeck(canvas, neckBase, breath);

    canvas.restore();
  }

  /// Ground shadow with dynamic contact ellipses matching footsteps.
  void _drawGroundShadow(Canvas canvas, Offset hip, Offset chest, double groundY, double phase) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Main ambient body shadow
    final bodyShadowRect = Rect.fromCenter(
      center: Offset(210.0, groundY + 8.0),
      width: 260.0,
      height: 22.0,
    );
    canvas.drawOval(bodyShadowRect, shadowPaint);

    // Dynamic foot contact shadows
    final contactPaint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final leftFootX = hip.dx + math.sin(phase) * 35.0;
    final rightFootX = hip.dx + math.sin(phase + math.pi) * 35.0;

    canvas.drawOval(Rect.fromCenter(center: Offset(leftFootX, groundY + 4), width: 36, height: 10), contactPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rightFootX, groundY + 4), width: 36, height: 10), contactPaint);
  }

  /// Digitigrade theropod leg (Hip -> Knee -> Shin -> Raised Ankle -> Metatarsus -> Toes + Sickle Claw).
  void _drawLeg({
    required Canvas canvas,
    required Offset hip,
    required double groundY,
    required double phase,
    required bool isFar,
  }) {
    final double normPhase = (phase % (math.pi * 2));
    final bool isStance = normPhase < math.pi;

    double footX;
    double footY;
    double sickleClawAngle;

    if (isStance) {
      // Stance phase: Foot firmly on ground pushing backward
      final double progress = normPhase / math.pi;
      footX = hip.dx + 38.0 - (progress * 76.0);
      footY = groundY;
      sickleClawAngle = -0.15; // Tense, ready on ground
    } else {
      // Swing phase: Foot lifts, flexes knee, steps forward in arc
      final double progress = (normPhase - math.pi) / math.pi;
      final double arc = math.sin(progress * math.pi);
      footX = hip.dx - 38.0 + (progress * 76.0);
      footY = groundY - (arc * 34.0);
      sickleClawAngle = -0.55 - (arc * 0.4); // Raised high in the air
    }

    // Kinematic joint calculations (Analytical theropod leg angles)
    final Offset knee = Offset(
      hip.dx + (isStance ? 18.0 : 28.0),
      hip.dy + 42.0 - (isStance ? 0.0 : 12.0),
    );

    final Offset ankle = Offset(
      footX - (isStance ? 14.0 : 22.0),
      footY - 26.0,
    );

    final Offset footBall = Offset(footX, footY);

    // Color palette based on depth
    final Color baseDark = isFar ? const Color(0xFF0A0C0E) : const Color(0xFF14181F);
    final Color midDark = isFar ? const Color(0xFF13171D) : const Color(0xFF222834);
    final Color highlight = isFar ? const Color(0xFF1A1F27) : const Color(0xFF333C4E);

    final legPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [highlight, midDark, baseDark],
      ).createShader(Rect.fromPoints(hip, footBall));

    // 1. Thigh (Muscular, rounded contour)
    final thighPath = Path()
      ..moveTo(hip.dx - 18, hip.dy - 8)
      ..cubicTo(hip.dx + 26, hip.dy - 10, hip.dx + 30, knee.dy - 14, knee.dx + 8, knee.dy)
      ..lineTo(knee.dx - 10, knee.dy + 4)
      ..cubicTo(hip.dx - 12, knee.dy - 12, hip.dx - 28, hip.dy + 14, hip.dx - 18, hip.dy - 8)
      ..close();
    canvas.drawPath(thighPath, legPaint);

    // 2. Shin / Calf (Tibia & Gastrocnemius muscle)
    final shinPath = Path()
      ..moveTo(knee.dx - 8, knee.dy)
      ..lineTo(knee.dx + 6, knee.dy - 2)
      ..cubicTo(knee.dx + 12, knee.dy + 18, ankle.dx + 6, ankle.dy - 10, ankle.dx + 4, ankle.dy)
      ..lineTo(ankle.dx - 5, ankle.dy)
      ..cubicTo(knee.dx - 14, knee.dy + 24, knee.dx - 16, knee.dy + 10, knee.dx - 8, knee.dy)
      ..close();
    canvas.drawPath(shinPath, legPaint);

    // 3. Metatarsus (Slender theropod ankle down to ball of foot)
    final metatarsusPath = Path()
      ..moveTo(ankle.dx - 4, ankle.dy)
      ..lineTo(ankle.dx + 4, ankle.dy)
      ..lineTo(footBall.dx + 3, footBall.dy - 5)
      ..lineTo(footBall.dx - 6, footBall.dy - 5)
      ..close();
    canvas.drawPath(metatarsusPath, legPaint);

    // 4. Ground Toes & Claws
    final toePaint = Paint()..color = isFar ? const Color(0xFF08090C) : const Color(0xFF0F1216);
    final clawPaint = Paint()..color = isFar ? const Color(0xFF1A1C20) : const Color(0xFF2C323D);

    // Main forward toes
    for (int i = 0; i < 3; i++) {
      final double toeOffset = (i - 1) * 4.5;
      final toeTip = Offset(footBall.dx + 18.0 + (i == 1 ? 4.0 : 0.0), footBall.dy + (i == 1 ? 0.0 : -1.0));

      final toePath = Path()
        ..moveTo(footBall.dx - 4, footBall.dy - 4 + toeOffset)
        ..lineTo(toeTip.dx - 4, toeTip.dy - 1)
        ..lineTo(toeTip.dx, toeTip.dy)
        ..lineTo(toeTip.dx - 5, toeTip.dy + 2)
        ..close();
      canvas.drawPath(toePath, toePaint);

      // Sharp toe claw
      final clawPath = Path()
        ..moveTo(toeTip.dx - 3, toeTip.dy - 1.5)
        ..lineTo(toeTip.dx + 6, toeTip.dy + 1.0)
        ..lineTo(toeTip.dx - 2, toeTip.dy + 2.5)
        ..close();
      canvas.drawPath(clawPath, clawPaint);
    }

    // 5. THE DEADLY SICKLE CLAW (Digit II)
    // Famous curved raptor killing claw, held elevated off the ground
    canvas.save();
    canvas.translate(footBall.dx - 2.0, footBall.dy - 8.0);
    canvas.rotate(sickleClawAngle);

    final sickleClawPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(4, -8, 12, -18, 18, -12) // Outer curve of curved sickle
      ..cubicTo(20, -10, 14, -4, 10, 2)
      ..lineTo(2, 2)
      ..close();

    final sickleShader = LinearGradient(
      colors: isFar
          ? [const Color(0xFF1F2228), const Color(0xFF0B0D10)]
          : [const Color(0xFFE5DDD0), const Color(0xFF3A4250), const Color(0xFF13171F)],
    ).createShader(const Rect.fromLTWH(0, -20, 24, 24));

    canvas.drawPath(sickleClawPath, Paint()..shader = sickleShader);
    canvas.restore();
  }

  /// Prowling forelimbs / arms with long, grasping predatory claws.
  void _drawArm({
    required Canvas canvas,
    required Offset shoulder,
    required double phase,
    required bool isFar,
  }) {
    // Arm swings in predatory counter-phase to legs
    final double armAngle = math.sin(phase) * 0.28 + (turn3D > 0.5 ? 0.15 : 0.0);

    final Offset elbow = Offset(
      shoulder.dx + math.cos(0.9 + armAngle) * 28.0,
      shoulder.dy + math.sin(0.9 + armAngle) * 28.0,
    );

    final Offset wrist = Offset(
      elbow.dx + math.cos(-0.35 + armAngle) * 26.0,
      elbow.dy + math.sin(-0.35 + armAngle) * 26.0,
    );

    final armPaint = Paint()
      ..shader = LinearGradient(
        colors: isFar
            ? [const Color(0xFF11141A), const Color(0xFF090A0E)]
            : [const Color(0xFF2B3342), const Color(0xFF161A22), const Color(0xFF0E1015)],
      ).createShader(Rect.fromPoints(shoulder, wrist));

    // Upper arm
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx - 6, shoulder.dy - 3)
        ..lineTo(elbow.dx + 4, elbow.dy - 3)
        ..lineTo(elbow.dx - 3, elbow.dy + 4)
        ..lineTo(shoulder.dx - 4, shoulder.dy + 8)
        ..close(),
      armPaint,
    );

    // Forearm
    canvas.drawPath(
      Path()
        ..moveTo(elbow.dx - 3, elbow.dy + 2)
        ..lineTo(elbow.dx + 4, elbow.dy - 3)
        ..lineTo(wrist.dx + 3, wrist.dy - 2)
        ..lineTo(wrist.dx - 3, wrist.dy + 3)
        ..close(),
      armPaint,
    );

    // 4 Long hooked raptor finger claws
    final clawPaint = Paint()..color = isFar ? const Color(0xFF14171E) : const Color(0xFF3A4456);
    for (int i = 0; i < 4; i++) {
      final double fingerAngle = 0.2 + (i * 0.22);
      final fingerTip = Offset(
        wrist.dx + math.cos(fingerAngle) * (14.0 + (i == 1 ? 4.0 : 0.0)),
        wrist.dy + math.sin(fingerAngle) * (14.0 + (i == 1 ? 4.0 : 0.0)),
      );

      final fingerPath = Path()
        ..moveTo(wrist.dx - 1.5, wrist.dy + (i * 1.8))
        ..lineTo(fingerTip.dx, fingerTip.dy)
        ..lineTo(fingerTip.dx + 4.0, fingerTip.dy + 3.0) // Curved hooked talon tip
        ..lineTo(wrist.dx + 1.5, wrist.dy + (i * 1.8))
        ..close();
      canvas.drawPath(fingerPath, clawPaint);
    }
  }

  /// 8-Segment articulated serpentine whip tail with realistic balancing wave physics.
  void _drawArticulatedTail(Canvas canvas, Offset hip, double phase) {
    const int segments = 8;
    const double segLength = 22.0;

    final List<Offset> points = [Offset(hip.dx - 12.0, hip.dy - 4.0)];
    double currentAngle = math.pi * 0.96; // Base tail slope backwards

    for (int i = 0; i < segments; i++) {
      // Hydrodynamic serpentine counter-sway
      final double wave = math.sin((phase * 0.6) - (i * 0.42)) * (0.08 + (i * 0.022));
      currentAngle += wave;

      final prev = points[i];
      final next = Offset(
        prev.dx + math.cos(currentAngle) * segLength,
        prev.dy + math.sin(currentAngle) * segLength,
      );
      points.add(next);
    }

    // Build upper and lower contoured outline of tapering tail
    final upperPath = Path()..moveTo(points.first.dx, points.first.dy - 16.0);
    final lowerPath = Path()..moveTo(points.first.dx, points.first.dy + 14.0);

    for (int i = 1; i <= segments; i++) {
      final double thickness = (1.0 - (i / segments)) * 14.0 + 2.5;
      final pt = points[i];
      final normal = Offset(
        -math.sin(currentAngle) * thickness,
        math.cos(currentAngle) * thickness,
      );

      upperPath.lineTo(pt.dx + normal.dx, pt.dy + normal.dy);
      lowerPath.lineTo(pt.dx - normal.dx, pt.dy - normal.dy);
    }

    // Connect into solid tail polygon
    final tailPoly = Path()
      ..addPath(upperPath, Offset.zero)
      ..lineTo(points.last.dx, points.last.dy)
      ..extendWithPath(lowerPath, Offset.zero)
      ..close();

    final tailPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF0C0E12), Color(0xFF1B202A), Color(0xFF0F1218)],
      ).createShader(Rect.fromPoints(points.first, points.last));

    canvas.drawPath(tailPoly, tailPaint);

    // Tail golden stripe segment
    final tailStripePath = Path()..moveTo(points.first.dx, points.first.dy - 2.0);
    for (int i = 1; i <= segments; i++) {
      tailStripePath.lineTo(points[i].dx, points[i].dy - 1.0);
    }
    final tailStripePaint = Paint()
      ..color = const Color(0xFFE5A93B).withOpacity(0.65)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);
    canvas.drawPath(tailStripePath, tailStripePaint);

    // Dorsal osteoderm spines along upper tail
    final spinePaint = Paint()..color = const Color(0xFF262C38);
    for (int i = 0; i < 5; i++) {
      final pt = points[i];
      final spinePath = Path()
        ..moveTo(pt.dx - 2, pt.dy - 12)
        ..lineTo(pt.dx + 4, pt.dy - 20 - (4 - i))
        ..lineTo(pt.dx + 8, pt.dy - 10)
        ..close();
      canvas.drawPath(spinePath, spinePaint);
    }
  }

  /// Muscular Torso, Pelvis, Dorsal Scutes & Signature Golden Flank Stripe.
  void _drawTorso(Canvas canvas, Offset hip, Offset chest, double breath) {
    // Torso mass
    final torsoPath = Path()
      ..moveTo(hip.dx - 18, hip.dy - 12)
      ..cubicTo(hip.dx + 20, hip.dy - 24, chest.dx - 20, chest.dy - 20, chest.dx + 18, chest.dy - 12) // Arched back
      ..cubicTo(chest.dx + 30, chest.dy + 8, chest.dx + 20, chest.dy + 38 + breath, chest.dx - 12, chest.dy + 34 + breath) // Deep ribcage
      ..cubicTo(hip.dx + 35, hip.dy + 26, hip.dx + 10, hip.dy + 22, hip.dx - 14, hip.dy + 12) // Belly line
      ..close();

    final torsoPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.2, -0.2),
        radius: 0.9,
        colors: [Color(0xFF2F3646), Color(0xFF1A1F29), Color(0xFF0C0E12)],
      ).createShader(Rect.fromPoints(hip, Offset(chest.dx + 30, chest.dy + 40)));

    canvas.drawPath(torsoPath, torsoPaint);

    // Serrated dorsal spikes along the back
    final spinePaint = Paint()..color = const Color(0xFF282F3D);
    for (int i = 0; i < 6; i++) {
      final double x = hip.dx + 10.0 + (i * 14.0);
      final double y = hip.dy - 16.0 - (math.sin(i * 0.5) * 6.0);
      final spike = Path()
        ..moveTo(x - 4, y + 2)
        ..lineTo(x + 2, y - 10 - (i % 2 * 3))
        ..lineTo(x + 7, y + 3)
        ..close();
      canvas.drawPath(spike, spinePaint);
    }

    // THE ICONIC GOLDEN-AMBER LATERAL STRIPE (Indoraptor's signature mark)
    final stripePath = Path()
      ..moveTo(chest.dx + 24, chest.dy)
      ..cubicTo(chest.dx - 10, chest.dy + 2, hip.dx + 25, hip.dy - 4, hip.dx - 16, hip.dy - 2);

    final stripeGlowPaint = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.4)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(stripePath, stripeGlowPaint);

    final stripeCorePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD54F), Color(0xFFFF9800), Color(0xFFB26A00)],
      ).createShader(Rect.fromPoints(hip, chest))
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(stripePath, stripeCorePaint);
  }

  /// Neck and Head with seamless 3D perspective rotation towards the user!
  void _drawArticulatedHeadAndNeck(Canvas canvas, Offset neckBase, double breath) {
    if (turn3D < 0.05) {
      // 100% Profile View
      _drawHeadProfile(canvas, neckBase, jawOpen, 1.0);
    } else if (turn3D > 0.95) {
      // 100% Frontal 3D View staring directly at user
      _drawHead3DFrontal(canvas, neckBase, jawOpen, breath);
    } else {
      // Smooth 3D Interpolation transition between Profile and Frontal
      canvas.saveLayer(null, Paint());
      _drawHeadProfile(canvas, neckBase, jawOpen, 1.0 - turn3D);
      _drawHead3DFrontal(canvas, neckBase, jawOpen, breath, opacity: turn3D);
      canvas.restore();
    }
  }

  /// Profile view of the ferocious Indoraptor skull.
  void _drawHeadProfile(Canvas canvas, Offset neckBase, double jaw, double opacity) {
    final skullOrigin = Offset(neckBase.dx + 48.0, neckBase.dy - 8.0);

    // Neck curvature
    final neckPath = Path()
      ..moveTo(neckBase.dx - 8, neckBase.dy - 12)
      ..cubicTo(neckBase.dx + 16, neckBase.dy - 22, skullOrigin.dx - 20, skullOrigin.dy - 14, skullOrigin.dx - 6, skullOrigin.dy - 10)
      ..lineTo(skullOrigin.dx, skullOrigin.dy + 12)
      ..cubicTo(skullOrigin.dx - 18, skullOrigin.dy + 18, neckBase.dx + 22, neckBase.dy + 16, neckBase.dx - 6, neckBase.dy + 14)
      ..close();

    final neckPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF282F3B), Color(0xFF141820), Color(0xFF0B0D11)],
      ).createShader(Rect.fromPoints(neckBase, skullOrigin))
      ..color = Colors.white.withOpacity(opacity);
    canvas.drawPath(neckPath, neckPaint);

    // Quills along the nape of the neck
    final quillPaint = Paint()
      ..color = const Color(0xFF384355).withOpacity(opacity)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 9; i++) {
      final double qx = neckBase.dx + (i * 5.5);
      final double qy = neckBase.dy - 14.0 - (i * 0.8);
      canvas.drawLine(Offset(qx, qy), Offset(qx - 14.0 - (i * 1.5), qy - 12.0 - (i * 1.2)), quillPaint);
    }

    // Upper Skull (Maxilla, nasal bridge, brow ridge)
    final upperSkullPath = Path()
      ..moveTo(skullOrigin.dx - 10, skullOrigin.dy - 8)
      ..lineTo(skullOrigin.dx + 14, skullOrigin.dy - 10) // Brow ridge
      ..lineTo(skullOrigin.dx + 52, skullOrigin.dy + 6) // Snout bridge down to tip
      ..lineTo(skullOrigin.dx + 54, skullOrigin.dy + 14) // Tip of snout
      ..lineTo(skullOrigin.dx + 18, skullOrigin.dy + 14) // Maxilla tooth line
      ..lineTo(skullOrigin.dx + 8, skullOrigin.dy + 6)
      ..close();

    final skullPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF323B4A), Color(0xFF1B202A), Color(0xFF0C0E12)],
      ).createShader(Rect.fromLTWH(skullOrigin.dx - 10, skullOrigin.dy - 10, 68, 30))
      ..color = Colors.white.withOpacity(opacity);
    canvas.drawPath(upperSkullPath, skullPaint);

    // Upper Teeth (Razor-sharp serrated ivory)
    final toothPaint = Paint()..color = const Color(0xFFF3EEDD).withOpacity(opacity);
    for (int i = 0; i < 7; i++) {
      final double tx = skullOrigin.dx + 22.0 + (i * 4.4);
      final double toothLen = (i == 2 || i == 3) ? 7.0 : 4.5;
      final tooth = Path()
        ..moveTo(tx - 1.5, skullOrigin.dy + 13)
        ..lineTo(tx, skullOrigin.dy + 13 + toothLen)
        ..lineTo(tx + 1.5, skullOrigin.dy + 13)
        ..close();
      canvas.drawPath(tooth, toothPaint);
    }

    // Articulated Lower Jaw (Mandible) - Drops down during snarl
    final double jawAngle = jaw * 0.42; // Up to ~24 degrees open
    canvas.save();
    canvas.translate(skullOrigin.dx + 4.0, skullOrigin.dy + 10.0);
    canvas.rotate(jawAngle);

    final lowerJawPath = Path()
      ..moveTo(0, 0)
      ..lineTo(44, 4) // Jaw tip
      ..lineTo(42, 10)
      ..lineTo(2, 6)
      ..close();
    canvas.drawPath(lowerJawPath, skullPaint);

    // Lower Teeth
    for (int i = 0; i < 6; i++) {
      final double tx = 8.0 + (i * 5.5);
      final double toothLen = (i == 1 || i == 2) ? 6.5 : 4.0;
      final tooth = Path()
        ..moveTo(tx - 1.5, 2)
        ..lineTo(tx, 2 - toothLen)
        ..lineTo(tx + 1.5, 2)
        ..close();
      canvas.drawPath(tooth, toothPaint);
    }
    canvas.restore();

    // Eye: Glowing amber iris with vertical slit pupil
    final eyeCenter = Offset(skullOrigin.dx + 12.0, skullOrigin.dy - 1.0);

    // Eye glow
    canvas.drawCircle(
      eyeCenter,
      7.0,
      Paint()
        ..color = const Color(0xFFFF9800).withOpacity(0.45 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Amber iris
    canvas.drawCircle(eyeCenter, 3.8, Paint()..color = const Color(0xFFFFB300).withOpacity(opacity));

    // Slit pupil
    canvas.drawOval(
      Rect.fromCenter(center: eyeCenter, width: 1.4, height: 5.2),
      Paint()..color = Colors.black.withOpacity(opacity),
    );

    // Specular eye reflection dot
    canvas.drawCircle(
      Offset(eyeCenter.dx - 1.0, eyeCenter.dy - 1.0),
      0.9,
      Paint()..color = Colors.white.withOpacity(opacity),
    );
  }

  /// Frontal 3D view: The Indoraptor turns directly toward the user,
  /// staring right out of the screen with both glowing eyes, unhinging jaws,
  /// razor teeth, and misty breath vapor!
  void _drawHead3DFrontal(Canvas canvas, Offset neckBase, double jaw, double breath, {double opacity = 1.0}) {
    final center = Offset(neckBase.dx + 25.0, neckBase.dy - 4.0);

    // 1. Symmetrical 3D Neck & Bristling Quills
    final neck3DPath = Path()
      ..moveTo(center.dx - 36, center.dy + 32)
      ..lineTo(center.dx - 28, center.dy - 12)
      ..lineTo(center.dx + 28, center.dy - 12)
      ..lineTo(center.dx + 36, center.dy + 32)
      ..close();

    final neck3DPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF2E3644), Color(0xFF141820), Color(0xFF08090C)],
      ).createShader(Rect.fromCenter(center: center, width: 80, height: 60))
      ..color = Colors.white.withOpacity(opacity);
    canvas.drawPath(neck3DPath, neck3DPaint);

    // Quills fanning out menacingly on both sides
    final quillPaint = Paint()
      ..color = const Color(0xFF424F64).withOpacity(opacity)
      ..strokeWidth = 1.6;
    for (int i = 0; i < 6; i++) {
      final double y = center.dy - 10.0 + (i * 6.0);
      // Left quills
      canvas.drawLine(Offset(center.dx - 26, y), Offset(center.dx - 48 - (i * 2), y - 10), quillPaint);
      // Right quills
      canvas.drawLine(Offset(center.dx + 26, y), Offset(center.dx + 48 + (i * 2), y - 10), quillPaint);
    }

    // 2. Foreshortened 3D Snout & Brow Ridges
    final snoutPath = Path()
      ..moveTo(center.dx - 24, center.dy - 14) // Left brow
      ..lineTo(center.dx, center.dy - 18) // Central skull crest
      ..lineTo(center.dx + 24, center.dy - 14) // Right brow
      ..lineTo(center.dx + 16, center.dy + 12) // Right snout ridge
      ..lineTo(center.dx, center.dy + 20) // Tip of snout pointing at camera
      ..lineTo(center.dx - 16, center.dy + 12) // Left snout ridge
      ..close();

    final skull3DPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 0.8,
        colors: [Color(0xFF384355), Color(0xFF1B202A), Color(0xFF0B0D11)],
      ).createShader(Rect.fromCenter(center: center, width: 56, height: 46))
      ..color = Colors.white.withOpacity(opacity);
    canvas.drawPath(snoutPath, skull3DPaint);

    // Nostrils on 3D snout tip
    final nostrilPaint = Paint()..color = Colors.black.withOpacity(opacity);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx - 5.5, center.dy + 16), width: 3.2, height: 2.2), nostrilPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx + 5.5, center.dy + 16), width: 3.2, height: 2.2), nostrilPaint);

    // 3. Unhinged Lower Jaw (Wide open snarling towards the user)
    final double jawDrop = jaw * 26.0;
    if (jawDrop > 2.0) {
      // Dark red interior mouth cavity & tongue
      final mouthPath = Path()
        ..moveTo(center.dx - 18, center.dy + 16)
        ..lineTo(center.dx + 18, center.dy + 16)
        ..lineTo(center.dx + 14, center.dy + 16 + jawDrop)
        ..lineTo(center.dx - 14, center.dy + 16 + jawDrop)
        ..close();

      final mouthPaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A1010), Color(0xFF220505), Color(0xFF0A0202)],
        ).createShader(Rect.fromCenter(center: Offset(center.dx, center.dy + 16 + jawDrop / 2), width: 36, height: jawDrop))
        ..color = Colors.white.withOpacity(opacity);
      canvas.drawPath(mouthPath, mouthPaint);

      // Deep menacing 3D Teeth lining the upper and lower jaws
      final toothPaint = Paint()..color = const Color(0xFFF6F2E2).withOpacity(opacity);
      for (int i = 0; i < 7; i++) {
        final double x = center.dx - 15.0 + (i * 5.0);
        // Top teeth pointing down
        final topTooth = Path()
          ..moveTo(x - 1.4, center.dy + 16)
          ..lineTo(x, center.dy + 22)
          ..lineTo(x + 1.4, center.dy + 16)
          ..close();
        canvas.drawPath(topTooth, toothPaint);

        // Bottom teeth pointing up
        final bottomTooth = Path()
          ..moveTo(x - 1.4, center.dy + 16 + jawDrop)
          ..lineTo(x, center.dy + 10 + jawDrop)
          ..lineTo(x + 1.4, center.dy + 16 + jawDrop)
          ..close();
        canvas.drawPath(bottomTooth, toothPaint);
      }

      // 4. Breath vapor / heat mist drifting from the roaring jaw
      final mistPaint = Paint()
        ..color = Colors.white.withOpacity((0.15 + (math.sin(time * 6.0).abs() * 0.15)) * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(center.dx, center.dy + 22 + jawDrop), 12.0 + breath, mistPaint);
      canvas.drawCircle(Offset(center.dx - 10, center.dy + 28 + jawDrop), 9.0, mistPaint);
      canvas.drawCircle(Offset(center.dx + 10, center.dy + 28 + jawDrop), 9.0, mistPaint);
    }

    // 5. BOTH EYES GLARING DIRECTLY AT THE USER
    // Left eye at (-18, -8), Right eye at (+18, -8)
    _draw3DGlowingEye(canvas, Offset(center.dx - 18.0, center.dy - 8.0), opacity);
    _draw3DGlowingEye(canvas, Offset(center.dx + 18.0, center.dy - 8.0), opacity);
  }

  /// Individual 3D glowing amber eye staring straight ahead.
  void _draw3DGlowingEye(Canvas canvas, Offset eyeCenter, double opacity) {
    // Powerful ambient amber flare
    canvas.drawCircle(
      eyeCenter,
      12.0,
      Paint()
        ..color = const Color(0xFFFF9800).withOpacity(0.55 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Deep burning amber iris
    canvas.drawCircle(
      eyeCenter,
      4.6,
      Paint()..color = const Color(0xFFFFB300).withOpacity(opacity),
    );

    // Narrowed predatory vertical slit pupil (focused intently on the user)
    canvas.drawOval(
      Rect.fromCenter(center: eyeCenter, width: 1.6, height: 6.5),
      Paint()..color = Colors.black.withOpacity(opacity),
    );

    // Specular light reflection
    canvas.drawCircle(
      Offset(eyeCenter.dx - 1.2, eyeCenter.dy - 1.4),
      1.1,
      Paint()..color = Colors.white.withOpacity(opacity),
    );
  }

  @override
  bool shouldRepaint(covariant Indoraptor3DPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.walkVelocity != walkVelocity ||
        oldDelegate.turn3D != turn3D ||
        oldDelegate.jawOpen != jawOpen;
  }
}
