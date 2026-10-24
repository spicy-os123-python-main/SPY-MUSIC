import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/screens/Settings/settings_screen_controller.dart';
import 'package:spymusic/ui/widgets/new_version_dialog.dart';
import 'package:spymusic/ui/widgets/snackbar.dart';
import 'package:spymusic/utils/helper.dart';

class SpyMusicLoadingWidget extends StatefulWidget {
  const SpyMusicLoadingWidget({super.key});

  @override
  State<SpyMusicLoadingWidget> createState() => _SpyMusicLoadingWidgetState();
}

class _SpyMusicLoadingWidgetState extends State<SpyMusicLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final currentVer = Get.isRegistered<SettingsScreenController>()
          ? Get.find<SettingsScreenController>().currentVersion
          : "v1.0.0";

      final details = await checkAppUpdateDetails(currentVer: currentVer);

      if (!mounted) return;

      if (details['hasUpdate'] == true) {
        showDialog(
          context: context,
          builder: (context) => const NewVersionDialog(),
        );
      } else if (details['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "⚠️ Keine Verbindung zum Update-Server",
            size: SanckBarSize.BIG,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final verName = details['latest'] ?? currentVer;
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "✅ SPY MUSIC ist auf dem neuesten Stand ($verName)",
            size: SanckBarSize.BIG,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "⚠️ Fehler bei der Update-Prüfung",
            size: SanckBarSize.BIG,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: size.height * 0.78,
      width: double.infinity,
      child: Stack(
        children: [
          // Centered voice / equalizer waveform animation
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated soundwave bars
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final t = _animController.value;
                    final heights = [
                      24.0 + 32.0 * ((t + 0.1) % 1.0),
                      38.0 + 44.0 * ((t + 0.35) % 1.0),
                      52.0 + 36.0 * ((t + 0.6) % 1.0),
                      68.0 + 26.0 * ((t + 0.85) % 1.0),
                      50.0 + 38.0 * ((t + 0.2) % 1.0),
                      34.0 + 42.0 * ((t + 0.45) % 1.0),
                    ];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(heights.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.5),
                          width: 8,
                          height: heights[index],
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: index % 2 == 0
                                  ? const [
                                      Color(0xFF00D2FF),
                                      Color(0xFF0072FF),
                                    ]
                                  : const [
                                      Color(0xFFFF0055),
                                      Color(0xFFFF5252),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (index % 2 == 0
                                        ? const Color(0xFF00D2FF)
                                        : const Color(0xFFFF0055))
                                    .withOpacity(0.55),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 28),
                // Glowing SPY MUSIC Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    "SPY MUSIC",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Lade Songs, Playlists & Charts...",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.65),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Center Update Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 20 + bottomPadding),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleCheckUpdate,
                  borderRadius: BorderRadius.circular(25),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D2FF).withOpacity(0.18),
                          const Color(0xFFFF0055).withOpacity(0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _isCheckingUpdate
                            ? const Color(0xFF00D2FF)
                            : const Color(0xFF00D2FF).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(0.22),
                          blurRadius: 14,
                          spreadRadius: 0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isCheckingUpdate)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00D2FF),
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.system_update_alt_rounded,
                            size: 19,
                            color: Color(0xFF00D2FF),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _isCheckingUpdate
                              ? "Prüfe auf Updates..."
                              : "Auf Updates überprüfen",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

