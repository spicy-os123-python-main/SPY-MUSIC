import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AppLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String tag;

  AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag = 'SPY MUSIC',
  });

  @override
  String toString() {
    final timeStr =
        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
    return "[$timeStr][$level][$tag] $message";
  }
}

class AppLogService {
  static final List<AppLogEntry> _logs = [];
  static const int _maxLogs = 120;

  static void add(String level, dynamic message, {String tag = 'SPY MUSIC'}) {
    if (message == null) return;
    final text = message.toString().trim();
    if (text.isEmpty) return;

    if (_logs.length >= _maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: text,
      tag: tag,
    ));
  }

  static List<AppLogEntry> get logs => List.unmodifiable(_logs);

  static List<AppLogEntry> get errorLogs =>
      _logs.where((e) => e.level == 'ERROR').toList();

  static String getFormattedLogs({bool errorsOnly = false}) {
    final list = errorsOnly ? errorLogs : _logs;
    if (list.isEmpty) {
      return "Keine Diagnose-Logs vorhanden.";
    }
    return list.map((e) => e.toString()).join("\n");
  }

  static Future<bool> copyToClipboard({bool errorsOnly = false}) async {
    try {
      final text = getFormattedLogs(errorsOnly: errorsOnly);
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareLogs({bool errorsOnly = false}) async {
    try {
      final text = getFormattedLogs(errorsOnly: errorsOnly);
      await Share.share(
        text,
        subject: 'SPY MUSIC Diagnostics & Error Log',
      );
    } catch (_) {}
  }

  static void clear() {
    _logs.clear();
  }
}
