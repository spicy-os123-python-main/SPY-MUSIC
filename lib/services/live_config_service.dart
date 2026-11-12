import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Remote-controllable seasonal and startup UI configuration.
///
/// Allows toggling seasonal visuals (such as the winter Santa hat and
/// falling snow on the launch screen) without forcing users to install
/// a new APK.
class LiveConfig {
  static const int minAllowedSplashMs = 3000;
  static const int defaultSplashMs = 3200;
  static const int maxAllowedSplashMs = 15000;

  final int configVersion;
  final String season;
  final bool winterUpdateEnabled;
  final bool santaHatEnabled;
  final bool snowEnabled;
  final int minSplashMs;
  final String bannerText;

  const LiveConfig({
    this.configVersion = 1,
    this.season = 'winter',
    this.winterUpdateEnabled = true,
    this.santaHatEnabled = true,
    this.snowEnabled = true,
    this.minSplashMs = defaultSplashMs,
    this.bannerText = '',
  });

  factory LiveConfig.defaults() => const LiveConfig();

  factory LiveConfig.fromJson(Map<String, dynamic> json) {
    final rawSplash = (json['minSplashMs'] as num?)?.toInt() ?? defaultSplashMs;
    final clampedSplash = math.max(
      minAllowedSplashMs,
      math.min(maxAllowedSplashMs, rawSplash),
    );
    return LiveConfig(
      configVersion: (json['configVersion'] as num?)?.toInt() ?? 1,
      season: json['season']?.toString().trim().isNotEmpty == true
          ? json['season'].toString().trim()
          : 'winter',
      winterUpdateEnabled: json['winterUpdateEnabled'] as bool? ?? true,
      santaHatEnabled: json['santaHatEnabled'] as bool? ?? true,
      snowEnabled: json['snowEnabled'] as bool? ?? true,
      minSplashMs: clampedSplash,
      bannerText: json['bannerText']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'configVersion': configVersion,
        'season': season,
        'winterUpdateEnabled': winterUpdateEnabled,
        'santaHatEnabled': santaHatEnabled,
        'snowEnabled': snowEnabled,
        'minSplashMs': minSplashMs,
        'bannerText': bannerText,
      };

  Duration get minSplashDuration => Duration(milliseconds: minSplashMs);

  bool get showSantaHat => winterUpdateEnabled && santaHatEnabled;

  bool get showSnow => winterUpdateEnabled && snowEnabled;
}

/// Fetches and caches [LiveConfig] from the remote endpoint so visual live
/// updates (e.g. Winter Update overlays) roll out automatically on launch.
class LiveConfigService {
  static const String hiveCacheKey = 'liveConfigCache';
  static const String defaultConfigUrl = String.fromEnvironment(
    'LIVE_CONFIG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/live_config.json',
  );

  static final LiveConfigService _instance = LiveConfigService._internal();

  factory LiveConfigService({Dio? dio, String? configUrl}) {
    if (dio == null && configUrl == null) {
      return _instance;
    }
    return LiveConfigService._internal(
      dio: dio,
      configUrl: configUrl ?? defaultConfigUrl,
    );
  }

  LiveConfigService._internal({
    Dio? dio,
    this.configUrl = defaultConfigUrl,
  })  : _dio = dio,
        currentConfig = ValueNotifier<LiveConfig>(_readCachedConfig());

  final Dio? _dio;
  final String configUrl;
  final ValueNotifier<LiveConfig> currentConfig;

  static LiveConfig _readCachedConfig() {
    try {
      if (!Hive.isBoxOpen('AppPrefs')) {
        return LiveConfig.defaults();
      }
      final raw = Hive.box('AppPrefs').get(hiveCacheKey);
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return LiveConfig.fromJson(decoded);
        }
        if (decoded is Map) {
          return LiveConfig.fromJson(Map<String, dynamic>.from(decoded));
        }
      } else if (raw is Map) {
        return LiveConfig.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return LiveConfig.defaults();
  }

  Future<LiveConfig> fetchAndSync({
    Duration timeout = const Duration(milliseconds: 2200),
  }) async {
    try {
      final client = _dio ??
          Dio(
            BaseOptions(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              headers: const <String, String>{
                'Cache-Control': 'no-cache',
                'User-Agent': 'SPY-MUSIC-App/1.0',
              },
            ),
          );

      final response = await client
          .get<dynamic>(configUrl)
          .timeout(timeout);

      final parsed = _parseResponseData(response.data);
      if (parsed != null) {
        currentConfig.value = parsed;
        _persistConfig(parsed);
        return parsed;
      }
    } catch (_) {
      // Offline or rate-limited: keep cached/default live config cleanly.
    }
    return currentConfig.value;
  }

  static LiveConfig? _parseResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return LiveConfig.fromJson(data);
    }
    if (data is Map) {
      return LiveConfig.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return LiveConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return LiveConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    }
    return null;
  }

  static void _persistConfig(LiveConfig config) {
    try {
      if (Hive.isBoxOpen('AppPrefs')) {
        Hive.box('AppPrefs').put(hiveCacheKey, jsonEncode(config.toJson()));
      }
    } catch (_) {}
  }
}
