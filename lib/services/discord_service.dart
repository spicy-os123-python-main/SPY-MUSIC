import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

/// SPY MUSIC Discord Rich Presence & Activity Service
/// Supports:
/// 1. Direct Discord Gateway connection for Android & Mobile (live status)
/// 2. Live progress timestamps (start & end) matching playback
/// 3. Track artwork thumbnail (large_image) & SPY MUSIC badge (small_image)
/// 4. Clickable interactive buttons ("Listen on SPY Music", "Get SPY Music")
/// 5. Resilient Gateway connection with Opcode 6 Resume & rate-limit throttling
class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  bool isEnabled = false;
  String? currentTitle;
  String? currentArtist;
  String? currentAlbum;
  String? currentArtUri;
  Duration? currentDuration;
  Duration? currentPosition;
  DateTime? songStartTime;
  bool _currentIsPlaying = false;

  // Rate-limiting shield and deduplication
  String? _lastSentTitle;
  String? _lastSentArtist;
  String? _lastSentArtUri;
  bool? _lastSentIsPlaying;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  Timer? _healthCheckTimer;
  Timer? _pauseGraceTimer;
  bool _isConnecting = false;
  bool _heartbeatAckReceived = true;
  int _reconnectAttempts = 0;
  int _heartbeatInterval = 41250;

  // Discord Gateway Session Resumption (Opcode 6)
  String? _sessionId;
  int? _lastSequence;
  String? _resumeGatewayUrl;

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

    _sessionId = null;
    _lastSequence = null;
    _resumeGatewayUrl = null;
    disconnectGateway();
    if (isEnabled && newToken.trim().isNotEmpty) {
      connectGateway();
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isEnabled && token.isNotEmpty) {
        if (!isGatewayConnected && !_isConnecting) {
          debugPrint('[SPY MUSIC Discord] Health check: Reconnecting inactive gateway...');
          connectGateway();
        } else if (isGatewayConnected && _currentIsPlaying && currentTitle != null) {
          // Keep presence active and sync progress smoothly (max once every 25s, well within Discord limits)
          _sendPresencePayload(isPlaying: true, force: false);
        }
      }
    });
  }

  /// Connect to Discord Gateway WebSocket
  Future<void> connectGateway() async {
    final currentToken = token;
    if (!isEnabled || currentToken.isEmpty || _isConnecting || isGatewayConnected) return;

    _isConnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final targetUrl = (_sessionId != null && _resumeGatewayUrl != null && _resumeGatewayUrl!.isNotEmpty)
          ? '$_resumeGatewayUrl/?v=10&encoding=json'
          : 'wss://gateway.discord.gg/?v=10&encoding=json';

      debugPrint('[SPY MUSIC Discord] Connecting to Discord Gateway ($targetUrl)...');
      _socket = await WebSocket.connect(targetUrl).timeout(const Duration(seconds: 8));

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
      _resumeGatewayUrl = null;
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
    _pauseGraceTimer?.cancel();
    _pauseGraceTimer = null;
    _sessionId = null;
    _lastSequence = null;
    _resumeGatewayUrl = null;
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
      final int? s = json['s'];
      final String? t = json['t'];

      if (s != null) {
        _lastSequence = s;
      }

      // Opcode 10: HELLO
      if (op == 10 && d is Map) {
        _heartbeatInterval = d['heartbeat_interval'] ?? 41250;
        _startHeartbeat(_heartbeatInterval);

        // Try session resume if possible, otherwise identify
        if (_sessionId != null && _lastSequence != null) {
          _sendResume();
        } else {
          _sendIdentify();
        }
      }
      // Opcode 0: DISPATCH
      else if (op == 0) {
        if (t == 'READY' && d is Map) {
          _sessionId = d['session_id'];
          _resumeGatewayUrl = d['resume_gateway_url'];
          debugPrint('[SPY MUSIC Discord] Session READY (id: $_sessionId)');
          if (_currentIsPlaying && currentTitle != null) {
            _sendPresencePayload(isPlaying: true, force: true);
          }
        } else if (t == 'RESUMED') {
          debugPrint('[SPY MUSIC Discord] Session RESUMED successfully');
          if (_currentIsPlaying && currentTitle != null) {
            _sendPresencePayload(isPlaying: true, force: true);
          }
        }
      }
      // Opcode 11: Heartbeat ACK
      else if (op == 11) {
        _heartbeatAckReceived = true;
      }
      // Opcode 1: Discord requests immediate heartbeat
      else if (op == 1) {
        _sendHeartbeat();
      }
      // Opcode 7: Reconnect request from Gateway
      else if (op == 7) {
        debugPrint('[SPY MUSIC Discord] Received Opcode 7 Reconnect');
        _scheduleReconnect();
      }
      // Opcode 9: Invalid session
      else if (op == 9) {
        final bool canResume = d == true;
        debugPrint('[SPY MUSIC Discord] Invalid session (canResume: $canResume)');
        if (!canResume) {
          _sessionId = null;
          _lastSequence = null;
          _resumeGatewayUrl = null;
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!canResume) {
            _sendIdentify();
          } else {
            _sendResume();
          }
        });
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
      _socket!.add(jsonEncode({"op": 1, "d": _lastSequence}));
    } catch (_) {}
  }

  void _sendResume() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    final currentToken = token;
    if (currentToken.isEmpty || _sessionId == null || _lastSequence == null) {
      _sendIdentify();
      return;
    }

    final resumePayload = {
      "op": 6,
      "d": {
        "token": currentToken,
        "session_id": _sessionId,
        "seq": _lastSequence,
      }
    };

    try {
      _socket!.add(jsonEncode(resumePayload));
      debugPrint('[SPY MUSIC Discord] Resume sent to Gateway (seq: $_lastSequence)');
    } catch (e) {
      debugPrint('[SPY MUSIC Discord] Resume failed: $e');
      _sendIdentify();
    }
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
          album: currentAlbum,
          artUri: currentArtUri,
          duration: currentDuration,
          position: currentPosition,
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
    String? album,
    String? artUri,
    Duration? duration,
    Duration? position,
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final posMs = position?.inMilliseconds ?? 0;
    final startMs = songStartTime?.millisecondsSinceEpoch ?? (nowMs - posMs);

    final Map<String, dynamic> timestamps = {
      "start": startMs,
    };
    if (duration != null && duration.inMilliseconds > 0) {
      timestamps["end"] = startMs + duration.inMilliseconds;
    }

    // Determine large image (album/song artwork or fallback SPY MUSIC logo)
    String largeImage =
        "https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/assets/logo/spy_music_logo.png";
    if (artUri != null && artUri.isNotEmpty) {
      final parsed = Uri.tryParse(artUri);
      if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
        largeImage = artUri;
      }
    }

    const String smallImage =
        "https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/assets/logo/spy_music_logo.png";

    final String largeText = (album != null && album.isNotEmpty)
        ? "$title • $album"
        : "$title - SPY MUSIC";

    return {
      "since": null,
      "activities": [
        {
          "name": "SPY MUSIC",
          "type": 2, // 2 = Listening to
          "details": title,
          "state": artist != null && artist.isNotEmpty ? artist : "SPY MUSIC",
          "timestamps": timestamps,
          "assets": {
            "large_image": largeImage,
            "large_text": largeText,
            "small_image": smallImage,
            "small_text": "SPY MUSIC",
          },
          "buttons": [
            "Listen on SPY Music",
            "Get SPY Music",
          ],
          "metadata": {
            "button_urls": [
              "https://github.com/spicy-os123-python-main/SPY-MUSIC",
              "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/tag/v1.0.0",
            ]
          }
        }
      ],
      "status": "online",
      "afk": false,
    };
  }

  /// Update presence with current song information (debounced to avoid rate limits)
  void updatePresence(
    MediaItem? item, {
    bool isPlaying = true,
    Duration? position,
  }) {
    if (!isEnabled) return;

    if (item == null) {
      clearPresence();
      return;
    }

    final newTitle = item.title;
    final newArtist = item.artist ?? 'SPY MUSIC';
    final newAlbum = item.album ?? '';
    final newArtUri = item.artUri?.toString() ?? '';
    final newDuration = item.duration;

    final songChanged = (newTitle != currentTitle || newArtist != currentArtist);

    final posDiff = (currentPosition != null && position != null)
        ? (currentPosition! - position).abs().inSeconds
        : 0;

    currentTitle = newTitle;
    currentArtist = newArtist;
    currentAlbum = newAlbum;
    currentArtUri = newArtUri;
    currentDuration = newDuration;
    if (position != null) {
      currentPosition = position;
    }

    if (songChanged || songStartTime == null || posDiff > 2) {
      final offsetMs = position?.inMilliseconds ?? currentPosition?.inMilliseconds ?? 0;
      songStartTime = DateTime.now().subtract(Duration(milliseconds: offsetMs));
    }

    if (isPlaying) {
      _pauseGraceTimer?.cancel();
      _pauseGraceTimer = null;
      _currentIsPlaying = true;

      // Skip redundant sends if same song is already playing and no seek occurred
      if (!songChanged && _lastSentIsPlaying == true && _lastSentTitle == currentTitle && posDiff <= 2) {
        return;
      }

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _sendPresencePayload(isPlaying: true);
      });
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = null;

      // Provide a 10-second grace window on pause to prevent presence drops during song switches/buffering
      if (_currentIsPlaying) {
        _pauseGraceTimer?.cancel();
        _pauseGraceTimer = Timer(const Duration(seconds: 10), () {
          _currentIsPlaying = false;
          _sendPresencePayload(isPlaying: false);
        });
      }
    }
  }

  void _sendPresencePayload({required bool isPlaying, bool force = false}) {
    if (!isEnabled || token.isEmpty) return;

    if (isGatewayConnected) {
      // Check if duplicate of last sent presence
      if (!force &&
          _lastSentIsPlaying == isPlaying &&
          _lastSentTitle == currentTitle &&
          _lastSentArtist == currentArtist &&
          _lastSentArtUri == currentArtUri) {
        return;
      }

      final payload = {
        "op": 3,
        "d": _buildPresencePayload(
          title: currentTitle,
          artist: currentArtist,
          album: currentAlbum,
          artUri: currentArtUri,
          duration: currentDuration,
          position: currentPosition,
          isPlaying: isPlaying,
        )
      };

      try {
        _socket!.add(jsonEncode(payload));
        _lastSentTitle = isPlaying ? currentTitle : null;
        _lastSentArtist = isPlaying ? currentArtist : null;
        _lastSentArtUri = isPlaying ? currentArtUri : null;
        _lastSentIsPlaying = isPlaying;
        debugPrint('[SPY MUSIC Discord] Status updated: $currentTitle (playing: $isPlaying)');
      } catch (e) {
        debugPrint('[SPY MUSIC Discord] Send presence error: $e');
        _scheduleReconnect();
      }
    } else if (!_isConnecting) {
      connectGateway();
    }
  }

  void clearPresence() {
    _debounceTimer?.cancel();
    _pauseGraceTimer?.cancel();
    _debounceTimer = null;
    _pauseGraceTimer = null;
    currentTitle = null;
    currentArtist = null;
    currentAlbum = null;
    currentArtUri = null;
    currentDuration = null;
    currentPosition = null;
    songStartTime = null;
    _currentIsPlaying = false;
    _lastSentTitle = null;
    _lastSentArtist = null;
    _lastSentArtUri = null;
    _lastSentIsPlaying = false;
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
