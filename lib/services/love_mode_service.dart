import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'app_secrets.dart';

/// Secret Easter Egg theme toggle service.
class LoveModeService {
  static const String prefKey = 'dinoLoveMessageEnabled';

  static bool get isEnabled {
    try {
      final box = Hive.box('AppPrefs');
      return box.get(prefKey, defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  static set isEnabled(bool value) {
    try {
      Hive.box('AppPrefs').put(prefKey, value);
    } catch (_) {}
  }

  static bool isLoveCode(String input) {
    final clean = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final noSpaces = clean.replaceAll(' ', '');
    final codes = AppSecrets.loveSecretKeywords;
    return codes.contains(clean) || codes.contains(noSpaces);
  }

  static void toggleLoveMode(BuildContext? context) {
    final current = isEnabled;
    final newValue = !current;
    isEnabled = newValue;
    final copy = AppSecrets.loveCopy;

    if (context != null || Get.context != null) {
      Get.dialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF280814), Color(0xFF130409)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFF2D55), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2D55).withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "❤️",
                  style: TextStyle(fontSize: 44),
                ),
                const SizedBox(height: 10),
                Text(
                  newValue ? (copy['titleOn'] ?? '') : (copy['titleOff'] ?? ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  newValue ? (copy['bodyOn'] ?? '') : (copy['bodyOff'] ?? ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    newValue ? (copy['btnOn'] ?? 'OK') : "OK",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: true,
      );
    }
  }
}

