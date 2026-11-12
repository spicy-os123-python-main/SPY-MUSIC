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
  static String _lastSentError = '';
  static DateTime? _lastSentTime;

  /// Send error message to Discord Webhook
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

    // Deduplicate identical error messages within 3 seconds to avoid crash loop spam
    final now = DateTime.now();
    if (_lastSentError == errorStr &&
        _lastSentTime != null &&
        now.difference(_lastSentTime!) < const Duration(seconds: 3)) {
      return;
    }
    _lastSentError = errorStr;
    _lastSentTime = now;

    // Sanitize string (truncate and hide potential sensitive tokens)
    var sanitized = errorStr.length > 1800
        ? '${errorStr.substring(0, 1800)}\n... [truncated]'
        : errorStr;
    sanitized = sanitized.replaceAll(
        RegExp(r'(key|token|auth|password|secret)=[a-zA-Z0-9_\-\.]+'), r'$1=***');

    final payload = {
      "username": "SPY MUSIC Error Logger",
      "avatar_url": AppSecrets.discordWebhookAvatarUrl,
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

    if (_queue.length < 25) {
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
          if (targetUrl.isNotEmpty &&
              targetUrl.startsWith(AppSecrets.discordWebhookPrefix)) {
            await _dio.post(
              targetUrl,
              data: payload,
              options: Options(headers: {'Content-Type': 'application/json'}),
            );
          }
        } catch (_) {
          // Strictly swallow errors here to avoid recursive crash loops
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }
    } finally {
      _isProcessing = false;
    }
  }
}
