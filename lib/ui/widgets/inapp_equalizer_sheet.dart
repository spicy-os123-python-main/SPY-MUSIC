import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../player/player_controller.dart';
import 'snackbar.dart';

class InAppEqualizerSheet extends StatefulWidget {
  const InAppEqualizerSheet({super.key});

  @override
  State<InAppEqualizerSheet> createState() => _InAppEqualizerSheetState();
}

class _InAppEqualizerSheetState extends State<InAppEqualizerSheet> {
  final playerController = Get.find<PlayerController>();

  @override
  void initState() {
    super.initState();
    playerController.fetchEqualizerData();
  }

  static const Map<String, List<double>> _presets = {
    "Normal": [0.0, 0.0, 0.0, 0.0, 0.0],
    "Tiefbass": [5.5, 3.0, -0.5, 0.5, 1.0],
    "Bass & Höhen": [5.0, 2.5, -1.0, 2.5, 4.5],
    "Hip-Hop & Trap": [6.0, 3.5, 0.0, 2.0, 3.0],
    "Elektronisch / EDM": [5.0, 3.0, -1.0, 3.0, 4.5],
    "Rock & Metal": [4.5, 2.5, -0.5, 2.5, 4.0],
    "Pop": [2.0, 3.0, 2.5, 2.0, 1.5],
    "Klar & Stimmen": [-1.0, 0.5, 3.5, 3.0, 2.0],
    "Akustik & Sanft": [2.0, 1.0, 1.5, 2.5, 2.0],
    "Maximaler Druck": [3.5, 2.0, 1.0, 2.5, 3.5],
  };

  String _formatFreq(double freq) {
    if (freq >= 1000) {
      final khz = freq / 1000;
      return khz == khz.roundToDouble()
          ? "${khz.toInt()} kHz"
          : "${khz.toStringAsFixed(1)} kHz";
    }
    return "${freq.toInt()} Hz";
  }

  void _applyQuickBass(double val) {
    if (playerController.eqBands.length >= 2) {
      playerController.setEqBandGain(0, val);
      playerController.setEqBandGain(1, (val * 0.65).clamp(-10.0, 10.0));
    }
  }

  void _applyQuickTreble(double val) {
    final len = playerController.eqBands.length;
    if (len >= 5) {
      playerController.setEqBandGain(len - 2, (val * 0.65).clamp(-10.0, 10.0));
      playerController.setEqBandGain(len - 1, val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1420) : theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.equalizer_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SPY Equalizer & Sound",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          "In-App Sound & Frequenzen",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(() {
                    return Switch(
                      value: playerController.eqEnabled.value,
                      activeColor: const Color(0xFF00D2FF),
                      activeTrackColor: const Color(0xFF0072FF).withOpacity(0.4),
                      onChanged: (val) => playerController.setEqEnabled(val),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),

              // Mutual exclusivity badge (In-App vs System Equalizer)
              Obx(() {
                final isEqActive = playerController.eqEnabled.value;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEqActive
                        ? const Color(0xFF00D2FF).withOpacity(0.08)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEqActive
                          ? const Color(0xFF00D2FF).withOpacity(0.25)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEqActive
                            ? Icons.verified_rounded
                            : Icons.phone_android_rounded,
                        size: 18,
                        color: isEqActive
                            ? const Color(0xFF00D2FF)
                            : Colors.white60,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEqActive
                              ? "SPY Equalizer aktiv • System-Equalizer ist entkoppelt (keine Verzerrung)"
                              : "System-Equalizer aktiv • Der Sound wird vom Handy gesteuert",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isEqActive
                                ? const Color(0xFF00D2FF)
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Volume & Audio Reset Action Card (Fixes call/WhatsApp audio lock)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0072FF).withOpacity(0.12),
                      const Color(0xFF00D2FF).withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF00D2FF),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Audio zu leise nach Anruf?",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            "Stellt 100% Lautstärke & Medienfokus wieder her",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF00D2FF).withOpacity(0.15),
                        foregroundColor: const Color(0xFF00D2FF),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await playerController.resetAudioEngine();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            snackbar(
                              context,
                              "✅ Audio-Engine repariert & 100% Lautstärke wiederhergestellt!",
                              size: SanckBarSize.MEDIUM,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        "Reparieren",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. Tiefbass (Punchy & Deep Bass Boost)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF0055).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF0055),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Tiefbass-Verstärkung (Clean & Punchy)",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Obx(() {
                          final currentBass = playerController.eqBands.isNotEmpty
                              ? (playerController.eqBands[0]['gain'] as num).toDouble()
                              : 0.0;
                          final isZero = currentBass <= 0.05;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isZero
                                  ? Colors.white10
                                  : const Color(0xFFFF0055).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isZero ? "0 dB" : "+${currentBass.toStringAsFixed(1)} dB",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isZero
                                    ? Colors.white60
                                    : const Color(0xFFFF0055),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final currentBass = playerController.eqBands.isNotEmpty
                          ? ((playerController.eqBands[0]['gain'] as num).toDouble()).clamp(0.0, 8.0)
                          : 0.0;
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF0055),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFFFF0055),
                          overlayColor: const Color(0xFFFF0055).withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: currentBass,
                          min: 0.0,
                          max: 8.0,
                          divisions: 16,
                          label: "+${currentBass.toStringAsFixed(1)} dB",
                          onChanged: playerController.eqEnabled.value
                              ? (val) => _applyQuickBass(val)
                              : null,
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Sanft (0 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Druckvoll (+4 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Maximal (+8 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Klarheit & Stimmen (Treble / Vocal Clarity)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF00D2FF),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Klarheit & Stimmen (Treble & Vocals)",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Obx(() {
                          final len = playerController.eqBands.length;
                          final currentTreble = len >= 5
                              ? (playerController.eqBands[len - 1]['gain'] as num).toDouble()
                              : 0.0;
                          final isZero = currentTreble <= 0.05;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isZero
                                  ? Colors.white10
                                  : const Color(0xFF00D2FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isZero ? "0 dB" : "+${currentTreble.toStringAsFixed(1)} dB",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isZero
                                    ? Colors.white60
                                    : const Color(0xFF00D2FF),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final len = playerController.eqBands.length;
                      final currentTreble = len >= 5
                          ? ((playerController.eqBands[len - 1]['gain'] as num).toDouble()).clamp(0.0, 6.0)
                          : 0.0;
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF00D2FF),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFF00D2FF),
                          overlayColor: const Color(0xFF00D2FF).withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: currentTreble,
                          min: 0.0,
                          max: 6.0,
                          divisions: 12,
                          label: "+${currentTreble.toStringAsFixed(1)} dB",
                          onChanged: playerController.eqEnabled.value
                              ? (val) => _applyQuickTreble(val)
                              : null,
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Neutral (0 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Klar (+3 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Brillant (+6 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Lautstärke-Maximizer (Preamp Gain)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFAB47BC).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: Color(0xFFAB47BC),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Lautstärke-Verstärker (Preamp Boost)",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Obx(() {
                          final gain = playerController.eqLoudnessGain.value;
                          final isZero = gain <= 0.05;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isZero
                                  ? Colors.white10
                                  : const Color(0xFFAB47BC).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isZero ? "0 dB" : "+${gain.toStringAsFixed(1)} dB",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isZero
                                    ? Colors.white60
                                    : const Color(0xFFAB47BC),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final gain = playerController.eqLoudnessGain.value;
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFAB47BC),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFFAB47BC),
                          overlayColor: const Color(0xFFAB47BC).withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: gain.clamp(0.0, 6.0),
                          min: 0.0,
                          max: 6.0,
                          divisions: 12,
                          label: "+${gain.toStringAsFixed(1)} dB",
                          onChanged: playerController.eqEnabled.value
                              ? (val) => playerController.setEqLoudnessGain(val)
                              : null,
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Standard (0 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Verstärkt (+3 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                        Text("Maximal (+6 dB)",
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
              ),

              // Presets Selection (10 Sound Profiles)
              const Text(
                "Sound-Profile (10 Presets)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _presets.keys.map((presetName) {
                    return Obx(() {
                      final isSelected =
                          playerController.eqPreset.value == presetName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(presetName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              playerController.applyEqPreset(
                                  presetName, _presets[presetName]!);
                            }
                          },
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                          selectedColor: const Color(0xFF00D2FF),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF00D2FF)
                                : Colors.white12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      );
                    });
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // 5-Band Equalizer Sliders
              const Text(
                "Manuelle Frequenz-Bänder",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              Obx(() {
                final bands = playerController.eqBands;
                final isEqActive = playerController.eqEnabled.value;
                final minDb = playerController.eqMinDecibels.value;
                final maxDb = playerController.eqMaxDecibels.value;

                if (bands.isEmpty) {
                  final defaultFreqs = [60.0, 230.0, 910.0, 3600.0, 14000.0];
                  return Container(
                    height: 180,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(defaultFreqs.length, (idx) {
                        return _buildBandSlider(
                          context,
                          index: idx,
                          frequencyLabel: _formatFreq(defaultFreqs[idx]),
                          gain: 0.0,
                          minDecibels: -10.0,
                          maxDecibels: 10.0,
                          enabled: isEqActive,
                        );
                      }),
                    ),
                  );
                }

                return Container(
                  height: 180,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(bands.length, (idx) {
                      final band = bands[idx];
                      final freq = (band['centerFrequency'] as num).toDouble();
                      final gain = (band['gain'] as num).toDouble();

                      return _buildBandSlider(
                        context,
                        index: idx,
                        frequencyLabel: _formatFreq(freq),
                        gain: gain,
                        minDecibels: minDb,
                        maxDecibels: maxDb,
                        enabled: isEqActive,
                      );
                    }),
                  ),
                );
              }),
              const SizedBox(height: 22),

              // External System Equalizer Button
              Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await playerController.openEqualizer();
                  },
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF00D2FF),
                    size: 18,
                  ),
                  label: const Text(
                    "System-Equalizer des Handys öffnen",
                    style: TextStyle(
                      color: Color(0xFF00D2FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color(0xFF00D2FF).withOpacity(0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBandSlider(
    BuildContext context, {
    required int index,
    required String frequencyLabel,
    required double gain,
    required double minDecibels,
    required double maxDecibels,
    required bool enabled,
  }) {
    final gainText = gain > 0
        ? "+${gain.toStringAsFixed(1)}"
        : (gain == 0.0 ? "0.0" : gain.toStringAsFixed(1));

    return Column(
      children: [
        Text(
          "$gainText dB",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: enabled ? const Color(0xFF00D2FF) : Colors.white30,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:
                    enabled ? const Color(0xFF00D2FF) : Colors.white24,
                inactiveTrackColor: Colors.white12,
                thumbColor:
                    enabled ? const Color(0xFF00D2FF) : Colors.white38,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
              ),
              child: Slider(
                value: gain.clamp(minDecibels, maxDecibels),
                min: minDecibels,
                max: maxDecibels,
                divisions: (maxDecibels - minDecibels).toInt() * 2 > 0
                    ? (maxDecibels - minDecibels).toInt() * 2
                    : 20,
                onChanged: enabled
                    ? (val) {
                        playerController.setEqBandGain(index, val);
                      }
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          frequencyLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.65),
          ),
        ),
      ],
    );
  }
}
