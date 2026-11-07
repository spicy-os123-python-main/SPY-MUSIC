import 'dart:async';
import 'package:dio/dio.dart';
import 'app_secrets.dart';

class DiscordWebhookService {
  static String get webhookUrl => AppSecrets.discordWebhookUrl;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static final List<Map<String, dynamic>> _queue = [];
  static bool _isProcessing = false;

  // Anti-Abuse & Rate-Limiting Protection
  static final List<DateTime> _recentSendTimestamps = [];
  static int _sessionSendCount = 0;
  static const int _maxPerMinute = 3;
  static const int _maxPerSession = 15;
  static final Map<String, DateTime> _sentErrorHashes = {};

  /// Send error message to Discord Webhook with strict rate limiting & anti-abuse guards
  static void sendError(dynamic text, {String tag = 'SPY MUSIC'}) {
    if (text == null) return;
    final errorStr = text.toString().trim();
    if (errorStr.isEmpty) return;

    // Filter out common harmless offline/cancellation errors to avoid unnecessary webhook traffic
    final lower = errorStr.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection aborted') ||
        lower.contains('loading interrupted') ||
        lower.contains('network is unreachable')) {
      return;
    }

    // 1. Session-wide cap protection (prevents infinite loop or runaway crash spam)
    if (_sessionSendCount >= _maxPerSession) {
      return;
    }

    // 2. Sliding-window rate limiter: max 3 requests per 60 seconds
    final now = DateTime.now();
    _recentSendTimestamps.removeWhere(
        (ts) => now.difference(ts) > const Duration(seconds: 60));
    if (_recentSendTimestamps.length >= _maxPerMinute) {
      return;
    }

    // 3. 5-minute deduplication per error signature
    final errorKey = '$tag:$errorStr';
    final lastSent = _sentErrorHashes[errorKey];
    if (lastSent != null && now.difference(lastSent) < const Duration(minutes: 5)) {
      return;
    }
    _sentErrorHashes[errorKey] = now;
    // Clean old hashes periodically
    if (_sentErrorHashes.length > 50) {
      _sentErrorHashes.removeWhere(
          (_, ts) => now.difference(ts) > const Duration(minutes: 10));
    }

    // Sanitize string (truncate and hide potential sensitive tokens)
    var sanitized = errorStr.length > 1500
        ? '${errorStr.substring(0, 1500)}\n... [truncated]'
        : errorStr;
    sanitized = sanitized.replaceAll(
        RegExp(r'(key|token|auth|password|secret)=[a-zA-Z0-9_\-\.]+'), r'$1=***');

    final payload = {
      "username": "SPY MUSIC Error Logger",
      "avatar_url":
          "https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/assets/images/logo.png",
      "embeds": [
        {
          "title": "🚨 $tag",
          "description": "```\n$sanitized\n```",
          "color": 0xE74C3C,
          "timestamp": now.toUtc().toIso8601String(),
          "footer": {
            "text": "SPY MUSIC App Diagnostic Logger"
          }
        }
      ]
    };

    if (_queue.length < 5) {
      _queue.add(payload);
    }
    _processQueue();
  }

  static Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final payload = _queue.removeAt(0);
        try {
          final targetUrl = webhookUrl;
          if (targetUrl.isNotEmpty && targetUrl.startsWith('https://discord.com/api/webhooks/')) {
            await _dio.post(
              targetUrl,
              data: payload,
              options: Options(headers: {'Content-Type': 'application/json'}),
            );
            _recentSendTimestamps.add(DateTime.now());
            _sessionSendCount++;
          }
        } catch (_) {
          // Strictly swallow errors here to avoid recursive crash loops
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } finally {
      _isProcessing = false;
    }
  }
}
