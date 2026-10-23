import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ultra-Modern Animated Moving Plasma Fire & Ice Background
/// Features smooth continuous moving gradient mesh and glowing neon aura
class GlowingFireBackground extends StatefulWidget {
  final Widget child;
  const GlowingFireBackground({super.key, required this.child});

  @override
  State<GlowingFireBackground> createState() => _GlowingFireBackgroundState();
}

class _GlowingFireBackgroundState extends State<GlowingFireBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final angle = progress * 2 * math.pi;

        final alignX1 = math.cos(angle) * 0.7;
        final alignY1 = math.sin(angle) * 0.7;
        final alignX2 = math.cos(angle + math.pi) * 0.7;
        final alignY2 = math.sin(angle + math.pi) * 0.7;

        return Stack(
          children: [
            // Deep OLED base
            Container(color: const Color(0xFF07080D)),

            // Top-left moving glowing electric blue orb
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

            // Bottom-right moving glowing crimson fire orb
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

            // Center moving purple plasma nexus
            Positioned(
              left: 50 + (alignY1 * 30),
              top: 250 + (alignX1 * 40),
              width: 280,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8A00FF).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            widget.child,
          ],
        );
      },
    );
  }
}

