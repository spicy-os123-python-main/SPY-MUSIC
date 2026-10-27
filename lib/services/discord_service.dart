import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

/// SPY MUSIC Discord Rich Presence & Activity Service
/// Supports:
/// 1. Direct Discord Gateway connection for Android & Mobile (live status)
/// 2. Desktop native MPRIS & MediaSession broadcast for companion apps
class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  bool isEnabled = false;
  String? currentTitle;
  String? currentArtist;
  DateTime? songStartTime;
  bool _currentIsPlaying = false;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  Timer? _healthCheckTimer;
  bool _isConnecting = false;
  bool _heartbeatAckReceived = true;
  int _reconnectAttempts = 0;
  int _heartbeatInterval = 41250;

  String get token {
    try {
      return Hive.box('AppPrefs').get('discordUserToken', defaultValue: '') ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get isGatewayConnected => _socket != null && _socket!.readyState == WebSocket.open;

  void init() {
    try {
      final box = Hive.box('AppPrefs');
      isEnabled = box.get('discordRpcEnabled', defaultValue: true);
      debugPrint('[SPY MUSIC Discord] Service initialized. Enabled: $isEnabled');
      _startHealthCheck();
      if (isEnabled && token.isNotEmpty) {
        connectGateway();
      }
    } catch (e) {
      debugPrint('[SPY MUSIC Discord] Init error: $e');
    }
  }

  void toggleStatus(bool enable) {
    isEnabled = enable;
    try {
      Hive.box('AppPrefs').put('discordRpcEnabled', enable);
    } catch (_) {}

    if (enable) {
      _startHealthCheck();
      if (token.isNotEmpty) {
        connectGateway();
      }
    } else {
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      clearPresence();
      disconnectGateway();
    }
  }

  void setToken(String newToken) {
    try {
      Hive.box('AppPrefs').put('discordUserToken', newToken.trim());
    } catch (_) {}

    disconnectGateway();
    if (isEnabled && newToken.trim().isNotEmpty) {
      connectGateway();
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isEnabled && token.isNotEmpty && _currentIsPlaying) {
        if (!isGatewayConnected && !_isConnecting) {
          debugPrint('[SPY MUSIC Discord] Health check: Reconnecting inactive gateway...');
          connectGateway();
        }
      }
    });
  }

  /// Connect to Discord Gateway WebSocket
  Future<void> connectGateway() async {
    final currentToken = token;
    if (!isEnabled || currentToken.isEmpty || _isConnecting) return;

    _isConnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      debugPrint('[SPY MUSIC Discord] Connecting to Discord Gateway...');
      _socket = await WebSocket.connect(
        'wss://gateway.discord.gg/?v=10&encoding=json',
      ).timeout(const Duration(seconds: 8));

      _isConnecting = false;
      _reconnectAttempts = 0;
      _heartbeatAckReceived = true;
      debugPrint('[SPY MUSIC Discord] Gateway socket connected');

      _socket!.listen(
        (data) => _handleGatewayMessage(data),
        onError: (error) {
          debugPrint('[SPY MUSIC Discord] Gateway socket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[SPY MUSIC Discord] Gateway socket closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[SPY MUSIC Discord] Gateway connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _cleanSocket();
    if (!isEnabled || token.isEmpty) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 1)
        ? 2
        : (_reconnectAttempts == 2 ? 5 : 12);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connectGateway();
    });
  }

  void disconnectGateway() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _cleanSocket();
  }

  void _cleanSocket() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      _socket?.close(1000, 'Closing');
    } catch (_) {}
    _socket = null;
    _isConnecting = false;
  }

  void _handleGatewayMessage(dynamic rawData) {
    try {
      final json = jsonDecode(rawData.toString());
      final int? op = json['op'];
      final d = json['d'];

      // Opcode 10: HELLO
      if (op == 10 && d is Map) {
        _heartbeatInterval = d['heartbeat_interval'] ?? 41250;
        _startHeartbeat(_heartbeatInterval);
        _sendIdentify();
      }
      // Opcode 11: Heartbeat ACK
      else if (op == 11) {
        _heartbeatAckReceived = true;
      }
      // Opcode 1: Discord requests immediate heartbeat
      else if (op == 1) {
        _sendHeartbeat();
      }
      // Opcode 7 or 9: Reconnect / Invalid session
      else if (op == 7 || op == 9) {
        _scheduleReconnect();
      }
    } catch (e) {
      debugPrint('[SPY MUSIC Discord] Message parse error: $e');
    }
  }

  void _startHeartbeat(int intervalMs) {
    _heartbeatTimer?.cancel();
    _heartbeatAckReceived = true;
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _sendHeartbeat(),
    );
    _sendHeartbeat();
  }

  void _sendHeartbeat() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    if (!_heartbeatAckReceived) {
      debugPrint('[SPY MUSIC Discord] Heartbeat ACK missing, connection dead. Reconnecting...');
      _scheduleReconnect();
      return;
    }
    _heartbeatAckReceived = false;
    try {
      _socket!.add(jsonEncode({"op": 1, "d": null}));
    } catch (_) {}
  }

  void _sendIdentify() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    final currentToken = token;
    if (currentToken.isEmpty) return;

    final identifyPayload = {
      "op": 2,
      "d": {
        "token": currentToken,
        "capabilities": 16381,
        "properties": {
          "os": "Android",
          "browser": "SPY MUSIC",
          "device": "SPY MUSIC",
        },
        "presence": _buildPresencePayload(
          title: currentTitle,
          artist: currentArtist,
          isPlaying: _currentIsPlaying,
        ),
      }
    };

    try {
      _socket!.add(jsonEncode(identifyPayload));
      debugPrint('[SPY MUSIC Discord] Identify sent to Gateway');
    } catch (e) {
      debugPrint('[SPY MUSIC Discord] Identify failed: $e');
    }
  }

  Map<String, dynamic> _buildPresencePayload({
    String? title,
    String? artist,
    bool isPlaying = true,
  }) {
    if (!isPlaying || title == null || title.isEmpty) {
      return {
        "since": null,
        "activities": [],
        "status": "online",
        "afk": false,
      };
    }

    final startMs = songStartTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;

    return {
      "since": null,
      "activities": [
        {
          "name": "SPY MUSIC",
          "type": 2, // 2 = Listening to
          "details": title,
          "state": artist ?? "SPY MUSIC",
          "timestamps": {"start": startMs},
          "assets": {
            "large_image": "spy_music_logo",
            "large_text": "SPY MUSIC (Ad-Free Streaming)",
          },
          "buttons": [
            "Download SPY MUSIC"
          ],
          "metadata": {
            "button_urls": [
              "https://github.com/spicy-os123-python-main/SPY-MUSIC"
            ]
          }
        }
      ],
      "status": "online",
      "afk": false,
    };
  }

  /// Update presence with current song information (debounced to avoid rate limits)
  void updatePresence(MediaItem? item, {bool isPlaying = true}) {
    if (!isEnabled) return;

    if (item == null) {
      clearPresence();
      return;
    }

    currentTitle = item.title;
    currentArtist = item.artist ?? 'SPY MUSIC';
    songStartTime = DateTime.now();
    _currentIsPlaying = isPlaying;

    debugPrint('[SPY MUSIC Discord] Scheduling status update: $currentTitle by $currentArtist (playing: $isPlaying)');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _sendPresencePayload(isPlaying: isPlaying);
    });
  }

  void _sendPresencePayload({required bool isPlaying}) {
    if (isGatewayConnected) {
      final payload = {
        "op": 3,
        "d": _buildPresencePayload(
          title: currentTitle,
          artist: currentArtist,
          isPlaying: isPlaying,
        )
      };

      try {
        _socket!.add(jsonEncode(payload));
        debugPrint('[SPY MUSIC Discord] Status updated: $currentTitle (playing: $isPlaying)');
      } catch (e) {
        debugPrint('[SPY MUSIC Discord] Send presence error: $e');
        _scheduleReconnect();
      }
    } else if (token.isNotEmpty && !_isConnecting) {
      connectGateway();
    }
  }

  void clearPresence() {
    _debounceTimer?.cancel();
    currentTitle = null;
    currentArtist = null;
    _currentIsPlaying = false;
    debugPrint('[SPY MUSIC Discord] Presence cleared');

    if (isGatewayConnected) {
      final payload = {
        "op": 3,
        "d": _buildPresencePayload(isPlaying: false)
      };
      try {
        _socket!.add(jsonEncode(payload));
      } catch (_) {}
    }
  }
}
