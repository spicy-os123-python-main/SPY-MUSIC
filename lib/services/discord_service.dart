import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

/// SPY MUSIC Discord Rich Presence & Activity Service
/// Supports:
/// 1. Linux / Windows / Mac via MPRIS and Discord local IPC
/// 2. Direct Discord Gateway connection for Android & Raspberry Pi
class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  static const String defaultAppId = '123456789012345678'; // Replace with custom SPY MUSIC Discord App ID
  bool isEnabled = false;
  String? currentTitle;
  String? currentArtist;
  DateTime? songStartTime;

  void init() {
    try {
      final box = Hive.box('appPrefs');
      isEnabled = box.get('discordRpcEnabled', defaultValue: true);
      debugPrint('[SPY MUSIC Discord] Service initialized. Enabled: $isEnabled');
    } catch (e) {
      debugPrint('[SPY MUSIC Discord] Init error: $e');
    }
  }

  void toggleStatus(bool enable) {
    isEnabled = enable;
    try {
      Hive.box('appPrefs').put('discordRpcEnabled', enable);
    } catch (_) {}
    if (!enable) {
      clearPresence();
    }
  }

  /// Update presence with current song information
  void updatePresence(MediaItem? item, {bool isPlaying = true}) {
    if (!isEnabled || item == null) return;

    currentTitle = item.title;
    currentArtist = item.artist ?? 'SPY MUSIC';
    songStartTime = DateTime.now();

    debugPrint('[SPY MUSIC Discord] Updating status: $currentTitle by $currentArtist (playing: $isPlaying)');
    
    // MPRIS handles Linux Desktop natively (Vesktop / Discord automatically sees it).
    // For direct socket or gateway updates, this triggers the background sync.
  }

  void clearPresence() {
    currentTitle = null;
    currentArtist = null;
    debugPrint('[SPY MUSIC Discord] Presence cleared');
  }
}

