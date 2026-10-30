import 'dart:math' as math;
import 'package:flutter/material.dart';

class SignalOscilloscope extends StatefulWidget {
  final double width;
  final double height;
  final Color limeColor;
  final Color tealColor;
  final bool isPlaying;

  const SignalOscilloscope({
    super.key,
    this.width = double.infinity,
    this.height = 70.0,
    this.limeColor = const Color(0xFFB8FF3C),
    this.tealColor = const Color(0xFF2FD6A0),
    this.isPlaying = true,
  });

  @override
  State<SignalOscilloscope> createState() => _SignalOscilloscopeState();
}

class _SignalOscilloscopeState extends State<SignalOscilloscope>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: widget.limeColor.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            painter: _OscilloscopePainter(
              progress: widget.isPlaying ? _animController.value : 0.0,
              limeColor: widget.limeColor,
              tealColor: widget.tealColor,
            ),
          );
        },
      ),
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  final double progress;
  final Color limeColor;
  final Color tealColor;

  _OscilloscopePainter({
    required this.progress,
    required this.limeColor,
    required this.tealColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2.0;

    // Background teal sine wave
    final pathTeal = Path();
    final phaseTeal = progress * 2 * math.pi * 1.5;
    for (double x = 0; x <= size.width; x += 2.0) {
      final y = midY + math.sin((x / 25.0) + phaseTeal) * (size.height * 0.32);
      if (x == 0) {
        pathTeal.moveTo(x, y);
      } else {
        pathTeal.lineTo(x, y);
      }
    }
    final paintTeal = Paint()
      ..color = tealColor.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pathTeal, paintTeal);

    // Foreground lime sine wave
    final pathLime = Path();
    final phaseLime = progress * 2 * math.pi * 2.2;
    for (double x = 0; x <= size.width; x += 2.0) {
      final y = midY + math.sin((x / 35.0) - phaseLime) * (size.height * 0.38);
      if (x == 0) {
        pathLime.moveTo(x, y);
      } else {
        pathLime.lineTo(x, y);
      }
    }
    final paintLime = Paint()
      ..color = limeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(pathLime, paintLime);
  }

  @override
  bool shouldRepaint(covariant _OscilloscopePainter oldDelegate) => true;
}

