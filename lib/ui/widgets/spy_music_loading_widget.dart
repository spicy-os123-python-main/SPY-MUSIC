import 'package:flutter/material.dart';

class SpyMusicLoadingWidget extends StatefulWidget {
  const SpyMusicLoadingWidget({super.key});

  @override
  State<SpyMusicLoadingWidget> createState() => _SpyMusicLoadingWidgetState();
}

class _SpyMusicLoadingWidgetState extends State<SpyMusicLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _barsController;
  late AnimationController _lettersController;

  static const String _title = "SPY MUSIC";

  @override
  void initState() {
    super.initState();
    // Soundwave equalizer bars pulsating smoothly
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Letter-by-letter entrance over 2 seconds
    _lettersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _barsController.dispose();
    _lettersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.75,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soundwave equalizer bars
            AnimatedBuilder(
              animation: _barsController,
              builder: (context, child) {
                final t = _barsController.value;
                final heights = [
                  18.0 + 26.0 * ((t + 0.1) % 1.0),
                  30.0 + 36.0 * ((t + 0.35) % 1.0),
                  46.0 + 30.0 * ((t + 0.6) % 1.0),
                  58.0 + 22.0 * ((t + 0.85) % 1.0),
                  42.0 + 32.0 * ((t + 0.2) % 1.0),
                  26.0 + 34.0 * ((t + 0.45) % 1.0),
                ];

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(heights.length, (index) {
                    final isCyan = index % 2 == 0;
                    final color1 = isCyan
                        ? const Color(0xFF00D2FF)
                        : const Color(0xFFFF0055);
                    final color2 = isCyan
                        ? const Color(0xFF0072FF)
                        : const Color(0xFFFF5252);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 7,
                      height: heights[index],
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color1, color2],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color1.withOpacity(0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 32),

            // Animated Letter-by-Letter "SPY MUSIC"
            AnimatedBuilder(
              animation: _lettersController,
              builder: (context, child) {
                final progress = _lettersController.value;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_title.length, (index) {
                    final char = _title[index];
                    if (char == ' ') {
                      return const SizedBox(width: 14);
                    }

                    // Stagger: letters 0..8 enter sequentially within the first 75% of the 2-second cycle
                    final start = (index / _title.length) * 0.65;
                    final end = (start + 0.18).clamp(0.0, 1.0);

                    double letterProgress = 0.0;
                    if (progress >= start) {
                      letterProgress =
                          ((progress - start) / (end - start)).clamp(0.0, 1.0);
                    }

                    // Opacity: fade in as it enters, then soft fade at the end of 2s loop
                    double opacity = Curves.easeOut.transform(letterProgress);
                    if (progress > 0.90) {
                      opacity *=
                          (1.0 - ((progress - 0.90) / 0.10)).clamp(0.0, 1.0);
                    }

                    // Scale & bounce curve
                    final scale =
                        0.4 + 0.6 * Curves.elasticOut.transform(letterProgress);
                    final translateY = (1.0 - letterProgress) * 16.0;

                    final isSpy = index < 3;
                    final color1 = isSpy
                        ? const Color(0xFF00D2FF)
                        : const Color(0xFFFF0055);
                    final color2 = isSpy
                        ? const Color(0xFF0072FF)
                        : const Color(0xFFFF5252);

                    final clampedOpacity = opacity.clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: clampedOpacity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [color1, color2],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: color1.withOpacity((0.85 * clampedOpacity).clamp(0.0, 1.0)),
                                      blurRadius: 18,
                                    ),
                                    Shadow(
                                      color: color2.withOpacity((0.55 * clampedOpacity).clamp(0.0, 1.0)),
                                      blurRadius: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 14),

            // Pulsing subtle loading indicator dots
            AnimatedBuilder(
              animation: _barsController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.45 + 0.45 * _barsController.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00D2FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF0055),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00D2FF),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
