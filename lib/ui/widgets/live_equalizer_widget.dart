import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiveEqualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final Color? color;
  const LiveEqualizerWidget({
    super.key,
    this.isPlaying = true,
    this.height = 20,
    this.color,
  });

  @override
  State<LiveEqualizerWidget> createState() => _LiveEqualizerWidgetState();
}

class _LiveEqualizerWidgetState extends State<LiveEqualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) => _bar(0.2, i)),
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value * 2 * math.pi;
        final h1 = (math.sin(t) + 1) / 2 * 0.7 + 0.3;
        final h2 = (math.sin(t + 1.2) + 1) / 2 * 0.8 + 0.2;
        final h3 = (math.sin(t + 2.4) + 1) / 2 * 0.9 + 0.1;
        final h4 = (math.sin(t + 3.6) + 1) / 2 * 0.75 + 0.25;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(h1, 0),
            const SizedBox(width: 3),
            _bar(h2, 1),
            const SizedBox(width: 3),
            _bar(h3, 2),
            const SizedBox(width: 3),
            _bar(h4, 3),
          ],
        );
      },
    );
  }

  Widget _bar(double fraction, int index) {
    final colors = [
      const Color(0xFF00D2FF),
      const Color(0xFF5D00FF),
      const Color(0xFFFF0055),
      const Color(0xFFFF4D00),
    ];
    final barColor = widget.color ?? colors[index % colors.length];

    return Container(
      width: 3.5,
      height: widget.height * fraction,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: barColor.withOpacity(0.8),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}

