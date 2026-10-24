import 'dart:async';
import 'package:dio/dio.dart';

class DiscordWebhookService {
  static const String webhookUrl =
      'https://discord.com/api/webhooks/1563643412119425276/z1FhYNB2fndEuIhNsC64_qSCuaOM3cMaMX3y67p0V5g9z9-FZO_EaTupR7LKZSqzyZf7';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static final List<Map<String, dynamic>> _queue = [];
  static bool _isProcessing = false;
  static String _lastErrorText = '';
  static DateTime? _lastErrorTime;

  /// Send error message to Discord Webhook
  static void sendError(dynamic text, {String tag = 'SPY MUSIC'}) {
    if (text == null) return;
    final errorStr = text.toString().trim();
    if (errorStr.isEmpty) return;

    // Deduplicate identical error messages within 4 seconds
    final now = DateTime.now();
    if (_lastErrorText == errorStr &&
        _lastErrorTime != null &&
        now.difference(_lastErrorTime!) < const Duration(seconds: 4)) {
      return;
    }
    _lastErrorText = errorStr;
    _lastErrorTime = now;

    final truncated = errorStr.length > 1800
        ? '${errorStr.substring(0, 1800)}\n... [gekürzt]'
        : errorStr;

    final payload = {
      "username": "SPY MUSIC Error Logger",
      "avatar_url":
          "https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/assets/images/logo.png",
      "embeds": [
        {
          "title": "🚨 $tag",
          "description": "```\n$truncated\n```",
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
          await _dio.post(
            webhookUrl,
            data: payload,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );
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
