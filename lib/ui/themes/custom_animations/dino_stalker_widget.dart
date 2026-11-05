import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive background animation of the Indoraptor stalking across the screen.
/// Prowls across the background, halts in the center for ~2.2 seconds to menacingly stare at the user,
/// then continues stalking off-screen and re-enters from the opposite side in alternating cycles.
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

        // Total cycle duration: 13.5 seconds
        const double cycleDuration = 13.5;
        final double t = time % cycleDuration;
        final int cycleIndex = (time / cycleDuration).floor();

        // Alternating directions: cycle 0 = left-to-right, cycle 1 = right-to-left
        final bool walkLeftToRight = (cycleIndex % 2) == 0;

        // Scale dinosaur proportionally to screen size
        final double dinoWidth = (screenWidth * 0.72).clamp(240.0, 420.0);
        final double dinoHeight = dinoWidth * 1.20;

        // Positioned in the lower-middle atmospheric background
        final double baseY = (screenHeight * 0.38).clamp(120.0, screenHeight - dinoHeight - 60.0);

        double x;
        double bobY = 0.0;
        double rotation = 0.0;
        double scale = 1.0;
        double eyeGlow = 0.0;
        double opacity = 0.82;

        if (t < 4.2) {
          // --- Phase 1: Stalking from offscreen into center (0.0s to 4.2s) ---
          final double progress = t / 4.2;
          final double curved = Curves.easeOutCubic.transform(progress);
          final double startX = -dinoWidth;
          final double centerX = (screenWidth - dinoWidth) / 2.0;
          x = startX + (centerX - startX) * curved;

          // Prowling walk cycle (footsteps & predatory head sway)
          bobY = math.sin(t * 7.5) * 6.5;
          rotation = math.sin(t * 7.5) * 0.032;
        } else if (t < 6.4) {
          // --- Phase 2: STOPPED IN THE CENTER, STARING AT THE USER (4.2s to 6.4s = 2.2s) ---
          final double stopT = t - 4.2;
          x = (screenWidth - dinoWidth) / 2.0;

          // Deep, menacing predatory breathing
          final double breath = math.sin(stopT * math.pi / 2.2 * 2.0);
          bobY = breath * 2.2;

          // Subtle dramatic focus zoom towards user
          scale = 1.0 + (math.sin(stopT * math.pi / 2.2) * 0.065);

          // Intense amber/gold eye and jaw glint
          final double pulse = math.sin(stopT * 5.5).abs();
          eyeGlow = 0.35 + (pulse * 0.65);
        } else if (t < 10.4) {
          // --- Phase 3: Resumes prowling forward and exits screen (6.4s to 10.4s) ---
          final double progress = (t - 6.4) / 4.0;
          final double curved = Curves.easeInCubic.transform(progress);
          final double centerX = (screenWidth - dinoWidth) / 2.0;
          final double endX = screenWidth + 60.0;
          x = centerX + (endX - centerX) * curved;

          // Prowling walk cycle
          bobY = math.sin(t * 7.5) * 6.5;
          rotation = math.sin(t * 7.5) * 0.032;
        } else {
          // --- Phase 4: Lurking in the shadows off-screen (10.4s to 13.5s) ---
          x = screenWidth + 400.0;
          opacity = 0.0;
        }

        // Apply direction flip if walking right-to-left in alternating cycle
        final double finalX = walkLeftToRight ? x : (screenWidth - dinoWidth - x);
        final double flipX = walkLeftToRight ? 1.0 : -1.0;

        return Stack(
          children: [
            Positioned(
              left: finalX,
              top: baseY + bobY,
              child: Opacity(
                opacity: opacity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(scale * flipX, scale)
                    ..rotateZ(rotation),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Ground shadow ellipse under the dinosaur
                      Positioned(
                        bottom: -10,
                        left: dinoWidth * 0.15,
                        right: dinoWidth * 0.15,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(dinoWidth * 0.35, 14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.70),
                                blurRadius: 20,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Indoraptor Asset
                      Image.asset(
                        'assets/animations/indoraptor.png',
                        width: dinoWidth,
                        height: dinoHeight,
                        fit: BoxFit.contain,
                      ),

                      // Menacing glowing eye flare when staring at user in the center
                      if (eyeGlow > 0.05)
                        Positioned(
                          top: dinoHeight * 0.38,
                          right: walkLeftToRight ? dinoWidth * 0.22 : null,
                          left: !walkLeftToRight ? dinoWidth * 0.22 : null,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.withOpacity(eyeGlow),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amberAccent.withOpacity(eyeGlow),
                                  blurRadius: 14,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.deepOrangeAccent
                                      .withOpacity(eyeGlow * 0.75),
                                  blurRadius: 22,
                                  spreadRadius: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
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
}

