import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ultra-smooth cybernetic mini equalizer with animated bouncing bars
class MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;
  final int barCount;

  const MiniEqualizer({
    super.key,
    required this.isPlaying,
    this.color = const Color(0xFF00D2FF),
    this.height = 14,
    this.barCount = 4,
  });

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isPlaying && _animController.isAnimating) {
      _animController.stop();
      _animController.animateTo(0.2, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final t = _animController.value * 2 * math.pi;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final phase = i * (math.pi / 2.2);
              final dynamicScale = widget.isPlaying
                  ? 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t + phase))
                  : 0.2;
              final barH = widget.height * dynamicScale;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                width: 2.8,
                height: barH.clamp(2.5, widget.height),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.color,
                      i.isEven ? const Color(0xFFFF0055) : const Color(0xFF00D2FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

