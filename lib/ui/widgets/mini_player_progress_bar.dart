import 'package:flutter/material.dart';
import '/models/durationstate.dart';

class MiniPlayerProgressBar extends StatelessWidget {
  const MiniPlayerProgressBar(
      {super.key,
      required this.progressBarStatus,
      required this.progressBarColor});
  final ProgressBarState progressBarStatus;
  final Color progressBarColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 3),
      painter: ProgressBarPainter(
          current: progressBarStatus.current,
          total: progressBarStatus.total,
          progressBarColor: progressBarColor),
    );
  }
}

class ProgressBarPainter extends CustomPainter {
  ProgressBarPainter(
      {required this.current,
      required this.total,
      required this.progressBarColor});
  final Duration current;
  final Duration total;
  final Color progressBarColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Background subtle rail
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 1.5), Offset(size.width, 1.5), bgPaint);

    final currentWidth = total.inMilliseconds == 0
        ? 0.0
        : (size.width * (current.inMilliseconds / total.inMilliseconds))
            .clamp(0.0, size.width);

    if (currentWidth > 0) {
      final shader = const LinearGradient(
        colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 3));

      final activePaint = Paint()
        ..shader = shader
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(0, 1.5), Offset(currentWidth, 1.5), activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
