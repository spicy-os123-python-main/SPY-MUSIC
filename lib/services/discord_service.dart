import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../utils/helper.dart';
import 'app_secrets.dart';

/// SPY MUSIC Discord Rich Presence & Activity Service
/// Supports:
/// 1. Direct Discord Gateway WebSocket connection with user token (Android & Desktop)
/// 2. Official `mp:external/...` asset resolution via Discord's external-assets endpoint
/// 3. Live progress timestamps (start & end), cover art, and interactive buttons
/// 4. Session readiness guard (never sends op:3 before READY/RESUMED) + Opcode 6 Resume
class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  static String get _applicationId => AppSecrets.discordApplicationId;
  static String get _logoUrl => AppSecrets.discordLogoUrl;
  static const String _gatewayQuery = '?v=10&encoding=json';
  static String get _defaultGatewayUrl => AppSecrets.discordGatewayUrl;
  static const String _failedTokenPrefKey = 'discordFailedTokenSig';
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static final Dio _apiDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    validateStatus: (code) => code != null && code < 500,
    headers: const {
      'User-Agent': mobileUserAgent,
    },
  ));

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
  int _presenceDispatchSeq = 0;

  // Resolved mp:external asset cache (saves requests and prevents raw URLs)
  final Map<String, String> _externalAssetCache = {};
  final Set<String> _failedAssetUrls = {};

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _initialHeartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  Timer? _healthCheckTimer;
  Timer? _pauseGraceTimer;
  bool _isConnecting = false;
  bool _isSessionReady = false;
  bool _authFailed = false;
  bool _heartbeatAckReceived = true;
  int _reconnectAttempts = 0;
  int _heartbeatInterval = 41250;

  // Discord Gateway Session Resumption (Opcode 6)
  String? _sessionId;
  int? _lastSequence;
  String? _resumeGatewayUrl;

  /// Reactive connection state for Settings UI:
  /// 'disconnected' | 'connecting' | 'connected' | 'auth_failed'
  final ValueNotifier<String> connectionStatusNotifier =
      ValueNotifier<String>('disconnected');
  String? lastErrorMessage;

  @visibleForTesting
  String? gatewayUrlOverride;

  @visibleForTesting
  Future<String?> Function(String url)? externalAssetResolverOverride;

  @visibleForTesting
  Future<bool?> Function(String token)? tokenVerifierOverride;

  static final RegExp _standardTokenPattern =
      RegExp(r'^[A-Za-z0-9_-]{18,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{15,}$');
  static final RegExp _mfaTokenPattern = RegExp(r'^mfa\.[A-Za-z0-9_-]{20,}$');

  static String sanitizeToken(String raw) {
    var cleaned = raw.trim();
    if (cleaned.toLowerCase().startsWith('bearer ')) {
      cleaned = cleaned.substring(7).trim();
    }
    while ((cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length >= 2) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'") && cleaned.length >= 2)) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    return cleaned.replaceAll(RegExp(r'[\r\n\s]+'), '');
  }

  /// Checks whether [raw] matches Discord's user/MFA token structure so unrelated
  /// WebView/Webpack strings cannot be mistaken for an auth token.
  static bool looksLikeDiscordToken(String raw) {
    final cleaned = sanitizeToken(raw);
    return _standardTokenPattern.hasMatch(cleaned) ||
        _mfaTokenPattern.hasMatch(cleaned);
  }

  static String _tokenSignature(String value) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final code in value.codeUnits) {
      h1 = ((h1 ^ code) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ (code + 31)) * 0x85ebca6b) & 0xffffffff;
    }
    return '${h1.toRadixString(16)}_${h2.toRadixString(16)}_${value.length}';
  }

  static bool _isTokenMarkedFailed(String t) {
    if (t.isEmpty) return false;
    try {
      final stored = Hive.box('AppPrefs').get(_failedTokenPrefKey);
      return stored == _tokenSignature(t);
    } catch (_) {
      return false;
    }
  }

  static void _markTokenFailed(String t) {
    if (t.isEmpty) return;
    try {
      Hive.box('AppPrefs').put(_failedTokenPrefKey, _tokenSignature(t));
    } catch (_) {}
  }

  static void _clearFailedTokenMarker() {
    try {
      Hive.box('AppPrefs').delete(_failedTokenPrefKey);
    } catch (_) {}
  }

  /// Verifies a Discord token against `/users/@me`.
  /// Returns `true` if accepted, `false` if rejected (401/403), or `null` on
  /// network/rate-limit errors so temporary connectivity issues do not fail auth.
  Future<bool?> verifyToken(String candidate) async {
    final cleaned = sanitizeToken(candidate);
    if (cleaned.isEmpty) return false;

    if (tokenVerifierOverride != null) {
      return await tokenVerifierOverride!(cleaned);
    }

    try {
      final response = await _apiDio.get(
        '${AppSecrets.discordApiBaseUrl}/users/@me',
        options: Options(headers: {
          'Authorization': cleaned,
          'User-Agent': mobileUserAgent,
        }),
      );
      if (response.statusCode == 200) return true;
      if (response.statusCode == 401 || response.statusCode == 403) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  String get token {
    try {
      final raw =
          Hive.box('AppPrefs').get('discordUserToken', defaultValue: '') ?? '';
      return sanitizeToken(raw.toString());
    } catch (_) {
      return '';
    }
  }

  bool get _isSocketOpen =>
      _socket != null && _socket!.readyState == WebSocket.open;

  bool get isGatewayConnected => _isSocketOpen && _isSessionReady;

  void _updateStatusNotifier() {
    if (_authFailed) {
      connectionStatusNotifier.value = 'auth_failed';
    } else if (isGatewayConnected) {
      connectionStatusNotifier.value = 'connected';
    } else if (_isConnecting || (_isSocketOpen && !_isSessionReady)) {
      connectionStatusNotifier.value = 'connecting';
    } else {
      connectionStatusNotifier.value = 'disconnected';
    }
  }

  void _resetSentCache() {
    _lastSentTitle = null;
    _lastSentArtist = null;
    _lastSentArtUri = null;
    _lastSentIsPlaying = null;
  }

  void _clearSessionState() {
    _sessionId = null;
    _lastSequence = null;
    _resumeGatewayUrl = null;
  }

  void init() {
    try {
      final box = Hive.box('AppPrefs');
      isEnabled = box.get('discordRpcEnabled', defaultValue: true);
      final currentToken = token;
      printINFO(
          'Service initialized (enabled: $isEnabled, hasToken: ${currentToken.isNotEmpty})',
          tag: 'Discord');
      _startHealthCheck();
      if (isEnabled && currentToken.isNotEmpty) {
        if (_isTokenMarkedFailed(currentToken)) {
          _authFailed = true;
          lastErrorMessage = 'Discord Token ungültig oder abgelaufen (4004)';
          _updateStatusNotifier();
        } else {
          connectGateway();
        }
      }
    } catch (e) {
      printERROR('Init error: $e', tag: 'Discord');
    }
  }

  void toggleStatus(bool enable) {
    isEnabled = enable;
    try {
      Hive.box('AppPrefs').put('discordRpcEnabled', enable);
    } catch (_) {}

    if (enable) {
      final currentToken = token;
      if (_isTokenMarkedFailed(currentToken)) {
        _authFailed = true;
        lastErrorMessage = 'Discord Token ungültig oder abgelaufen (4004)';
      } else {
        _authFailed = false;
        lastErrorMessage = null;
      }
      _startHealthCheck();
      if (currentToken.isNotEmpty && !_authFailed) {
        connectGateway();
      }
    } else {
      _authFailed = false;
      lastErrorMessage = null;
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      clearPresence();
      disconnectGateway();
    }
    _updateStatusNotifier();
  }

  void setToken(String newToken) {
    final cleaned = sanitizeToken(newToken);
    try {
      Hive.box('AppPrefs').put('discordUserToken', cleaned);
    } catch (_) {}

    _clearFailedTokenMarker();
    _authFailed = false;
    lastErrorMessage = null;
    _reconnectAttempts = 0;
    _externalAssetCache.clear();
    _failedAssetUrls.clear();
    _clearSessionState();
    disconnectGateway();
    if (isEnabled && cleaned.isNotEmpty) {
      connectGateway();
    }
    _updateStatusNotifier();
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!isEnabled || token.isEmpty || _authFailed) return;
      if (!_isSocketOpen && !_isConnecting) {
        printINFO('Health check: Reconnecting inactive gateway...', tag: 'Discord');
        connectGateway();
      } else if (isGatewayConnected &&
          _currentIsPlaying &&
          currentTitle != null &&
          (_lastSentTitle != currentTitle || _lastSentIsPlaying != true)) {
        // Resend only if current state is out of sync (timestamps run client-side)
        _sendPresencePayload(isPlaying: true);
      }
    });
  }

  String _buildResumeUrl() {
    if (gatewayUrlOverride != null && gatewayUrlOverride!.isNotEmpty) {
      return gatewayUrlOverride!;
    }
    if (_sessionId != null &&
        _resumeGatewayUrl != null &&
        _resumeGatewayUrl!.isNotEmpty) {
      var base = _resumeGatewayUrl!.trim();
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      if (base.contains('?')) return base;
      return '$base/$_gatewayQuery';
    }
    return _defaultGatewayUrl;
  }

  /// Connect to Discord Gateway WebSocket
  Future<void> connectGateway() async {
    final currentToken = token;
    if (!isEnabled ||
        currentToken.isEmpty ||
        _isConnecting ||
        _isSocketOpen ||
        _authFailed) {
      return;
    }

    if (_isTokenMarkedFailed(currentToken)) {
      _authFailed = true;
      lastErrorMessage = 'Discord Token ungültig oder abgelaufen (4004)';
      _updateStatusNotifier();
      return;
    }

    _isConnecting = true;
    _isSessionReady = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _updateStatusNotifier();

    try {
      if (gatewayUrlOverride == null || tokenVerifierOverride != null) {
        final verified = await verifyToken(currentToken);
        if (!isEnabled || token != currentToken) {
          _isConnecting = false;
          _updateStatusNotifier();
          return;
        }
        if (verified == false) {
          _markTokenFailed(currentToken);
          _authFailed = true;
          _isConnecting = false;
          lastErrorMessage = 'Discord Token ungültig oder abgelaufen (4004)';
          _clearSessionState();
          _updateStatusNotifier();
          printERROR(
              'Gateway authentication failed (4004). Please re-login in Discord settings.',
              tag: 'Discord');
          return;
        }
      }

      final targetUrl = _buildResumeUrl();
      printINFO('Connecting to Discord Gateway ($targetUrl)...', tag: 'Discord');
      _socket = await WebSocket.connect(targetUrl)
          .timeout(const Duration(seconds: 10));

      _isConnecting = false;
      _heartbeatAckReceived = true;
      _updateStatusNotifier();

      final socketRef = _socket!;
      socketRef.listen(
        (data) => _handleGatewayMessage(data),
        onError: (error) {
          if (_socket != socketRef) return;
          printWarning('Gateway socket error: $error', tag: 'Discord');
          _scheduleReconnect();
        },
        onDone: () {
          if (_socket != socketRef) return;
          final code = socketRef.closeCode;
          final reason = socketRef.closeReason ?? '';
          _handleCloseCode(code, reason);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      _isSessionReady = false;
      printWarning('Gateway connect failed: $e', tag: 'Discord');
      _resumeGatewayUrl = null;
      _updateStatusNotifier();
      _scheduleReconnect();
    }
  }

  void _handleCloseCode(int? code, String reason) {
    if (code == 4004) {
      _markTokenFailed(token);
      _authFailed = true;
      lastErrorMessage = 'Discord Token ungültig oder abgelaufen (4004)';
      printERROR(
          'Gateway authentication failed (4004). Please re-login in Discord settings.',
          tag: 'Discord');
      _clearSessionState();
      _cleanSocket();
      _updateStatusNotifier();
      return;
    }

    if (code == 4007 || code == 4009 || code == 4010 || code == 4012) {
      _clearSessionState();
    }

    if (code != null && code != 1000) {
      printWarning(
          'Gateway closed (code: $code${reason.isNotEmpty ? ', reason: $reason' : ''})',
          tag: 'Discord');
    } else {
      printINFO('Gateway socket closed (code: ${code ?? 1000})', tag: 'Discord');
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _cleanSocket();
    _updateStatusNotifier();
    if (!isEnabled || token.isEmpty || _authFailed) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 1)
        ? 2
        : (_reconnectAttempts == 2 ? 5 : (_reconnectAttempts <= 4 ? 12 : 30));

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
    _clearSessionState();
    _cleanSocket();
    _updateStatusNotifier();
  }

  void _cleanSocket() {
    _initialHeartbeatTimer?.cancel();
    _initialHeartbeatTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final oldSocket = _socket;
    _socket = null;
    _isSessionReady = false;
    _isConnecting = false;
    try {
      oldSocket?.close(1000, 'Closing');
    } catch (_) {}
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

        if (_sessionId != null && _lastSequence != null) {
          _sendResume();
        } else {
          _sendIdentify();
        }
      }
      // Opcode 0: DISPATCH
      else if (op == 0) {
        if (t == 'READY' && d is Map) {
          _sessionId = d['session_id']?.toString();
          _resumeGatewayUrl = d['resume_gateway_url']?.toString();
          _isSessionReady = true;
          _authFailed = false;
          _clearFailedTokenMarker();
          _reconnectAttempts = 0;
          lastErrorMessage = null;
          _resetSentCache();
          _updateStatusNotifier();
          printINFO('Discord Gateway READY (session established)', tag: 'Discord');
          if (_currentIsPlaying && currentTitle != null) {
            _sendPresencePayload(isPlaying: true, force: true);
          }
        } else if (t == 'RESUMED') {
          _isSessionReady = true;
          _authFailed = false;
          _clearFailedTokenMarker();
          _reconnectAttempts = 0;
          lastErrorMessage = null;
          _updateStatusNotifier();
          printINFO('Discord Gateway RESUMED', tag: 'Discord');
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
        _sendHeartbeatNow();
      }
      // Opcode 7: Reconnect request from Gateway
      else if (op == 7) {
        printINFO('Received Opcode 7 Reconnect from Discord', tag: 'Discord');
        _scheduleReconnect();
      }
      // Opcode 9: Invalid session
      else if (op == 9) {
        final bool canResume = d == true;
        _isSessionReady = false;
        _updateStatusNotifier();
        printWarning('Gateway invalid session (canResume: $canResume)',
            tag: 'Discord');
        if (!canResume) {
          _clearSessionState();
        }
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!_isSocketOpen) return;
          if (canResume && _sessionId != null && _lastSequence != null) {
            _sendResume();
          } else {
            _sendIdentify();
          }
        });
      }
    } catch (e) {
      printWarning('Gateway message parse error: $e', tag: 'Discord');
    }
  }

  void _startHeartbeat(int intervalMs) {
    _initialHeartbeatTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatAckReceived = true;

    // Follow Discord jitter recommendation before first heartbeat so IDENTIFY settles cleanly
    final firstDelayMs = (intervalMs * 0.25).round().clamp(1500, 15000);
    _initialHeartbeatTimer = Timer(Duration(milliseconds: firstDelayMs), () {
      _sendHeartbeatWithAckCheck();
      _heartbeatTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _sendHeartbeatWithAckCheck(),
      );
    });
  }

  void _sendHeartbeatNow() {
    if (!_isSocketOpen) return;
    try {
      _socket!.add(jsonEncode({"op": 1, "d": _lastSequence}));
    } catch (_) {}
  }

  void _sendHeartbeatWithAckCheck() {
    if (!_isSocketOpen) return;
    if (!_heartbeatAckReceived) {
      printWarning('Heartbeat ACK missing, reconnecting gateway...', tag: 'Discord');
      _scheduleReconnect();
      return;
    }
    _heartbeatAckReceived = false;
    _sendHeartbeatNow();
  }

  void _sendResume() {
    if (!_isSocketOpen) return;
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
      printINFO('Gateway Resume sent (seq: $_lastSequence)', tag: 'Discord');
    } catch (e) {
      printWarning('Gateway Resume failed: $e', tag: 'Discord');
      _sendIdentify();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> buildIdentifyProperties({
    bool? isAndroidOverride,
    String? osOverride,
    String? localeOverride,
  }) {
    final bool isAndroid = isAndroidOverride ?? Platform.isAndroid;
    final String osName = osOverride ??
        (isAndroid
            ? 'Android'
            : (Platform.isWindows
                ? 'Windows'
                : (Platform.isMacOS ? 'Mac OS X' : 'Linux')));
    final rawLocale = (localeOverride ?? Platform.localeName).replaceAll('_', '-');
    final systemLocale = rawLocale.isNotEmpty ? rawLocale : 'en-US';
    if (isAndroid) {
      return {
        "os": "Android",
        "browser": "Discord Android",
        "device": "Discord Android",
        "system_locale": systemLocale,
      };
    }
    return {
      "os": osName,
      "browser": "Discord Client",
      "device": osName,
      "system_locale": systemLocale,
    };
  }

  void _sendIdentify() {
    if (!_isSocketOpen) return;
    final currentToken = token;
    if (currentToken.isEmpty) return;

    final identifyPayload = {
      "op": 2,
      "d": {
        "token": currentToken,
        "capabilities": 16381,
        "compress": false,
        "large_threshold": 100,
        "properties": buildIdentifyProperties(),
        "presence": _buildPresencePayload(
          title: currentTitle,
          artist: currentArtist,
          album: currentAlbum,
          duration: currentDuration,
          position: currentPosition,
          isPlaying: _currentIsPlaying,
          largeAsset: _lookupCachedAsset(currentArtUri),
          smallAsset: _lookupCachedAsset(_logoUrl),
        ),
      }
    };

    try {
      _socket!.add(jsonEncode(identifyPayload));
      printINFO('Gateway Identify sent', tag: 'Discord');
    } catch (e) {
      printWarning('Gateway Identify failed: $e', tag: 'Discord');
    }
  }

  String? _lookupCachedAsset(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('mp:')) return url;
    return _externalAssetCache[url];
  }

  /// Resolves an external HTTPS image URL into Discord's `mp:external/...` format
  /// via `/applications/<id>/external-assets`. Never returns a raw HTTP/HTTPS URL,
  /// because Discord drops Gateway activities with unresolved external URLs.
  Future<String?> _resolveExternalAsset(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('mp:')) return url;

    final parsed = Uri.tryParse(url);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return null;
    }

    final cached = _externalAssetCache[url];
    if (cached != null) return cached;
    if (_failedAssetUrls.contains(url)) return null;

    if (externalAssetResolverOverride != null) {
      final resolved = await externalAssetResolverOverride!(url);
      if (resolved != null && resolved.startsWith('mp:')) {
        if (_externalAssetCache.length >= 120) {
          _externalAssetCache.remove(_externalAssetCache.keys.first);
        }
        _externalAssetCache[url] = resolved;
        return resolved;
      }
      _rememberFailedAsset(url);
      return null;
    }

    final currentToken = token;
    if (currentToken.isEmpty) return null;

    try {
      final response = await _apiDio.post(
        '${AppSecrets.discordApiBaseUrl}/applications/$_applicationId/external-assets',
        options: Options(headers: {
          'Authorization': currentToken,
          'Content-Type': 'application/json',
        }),
        data: {
          'urls': [url],
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        if (list.isNotEmpty && list.first is Map) {
          final extPath = (list.first as Map)['external_asset_path']?.toString();
          if (extPath != null && extPath.isNotEmpty) {
            final mpAsset = extPath.startsWith('mp:') ? extPath : 'mp:$extPath';
            if (_externalAssetCache.length >= 120) {
              _externalAssetCache.remove(_externalAssetCache.keys.first);
            }
            _externalAssetCache[url] = mpAsset;
            return mpAsset;
          }
        }
      } else {
        _rememberFailedAsset(url);
      }
    } catch (_) {
      _rememberFailedAsset(url);
    }
    return null;
  }

  void _rememberFailedAsset(String url) {
    if (_failedAssetUrls.length >= 120) {
      _failedAssetUrls.remove(_failedAssetUrls.first);
    }
    _failedAssetUrls.add(url);
  }

  static String _clampText(String text, {int maxLen = 128}) {
    var trimmed = text.trim();
    if (trimmed.isEmpty) return 'SPY MUSIC';
    if (trimmed.length == 1) trimmed = '$trimmed ';
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 1)}…';
  }

  Map<String, dynamic> _buildPresencePayload({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? position,
    bool isPlaying = true,
    String? largeAsset,
    String? smallAsset,
  }) {
    if (!isPlaying || title == null || title.isEmpty) {
      return {
        "since": 0,
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

    final safeTitle = _clampText(title);
    final safeArtist =
        _clampText(artist != null && artist.isNotEmpty ? artist : 'SPY MUSIC');
    final safeLargeText = _clampText(
      (album != null && album.isNotEmpty)
          ? '$safeTitle • $album'
          : '$safeTitle - SPY MUSIC',
    );

    final effectiveLarge = largeAsset ?? smallAsset;
    final Map<String, dynamic> assets = {};
    if (effectiveLarge != null) {
      assets['large_image'] = effectiveLarge;
      assets['large_text'] = safeLargeText;
    }
    if (smallAsset != null) {
      assets['small_image'] = smallAsset;
      assets['small_text'] = 'SPY MUSIC';
    }

    final Map<String, dynamic> activity = {
      "application_id": _applicationId,
      "name": "SPY MUSIC",
      "type": 2, // 2 = Listening to
      "details": safeTitle,
      "state": safeArtist,
      "timestamps": timestamps,
      if (assets.isNotEmpty) "assets": assets,
      "buttons": [
        "Listen on SPY MUSIC",
        "Download SPY MUSIC (APK)",
      ],
      "metadata": {
        "button_urls": [
          "https://github.com/spicy-os123-python-main/SPY-MUSIC",
          "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest",
        ]
      }
    };

    return {
      "since": startMs,
      "activities": [activity],
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

    if (songChanged || songStartTime == null || posDiff > 5) {
      final offsetMs =
          position?.inMilliseconds ?? currentPosition?.inMilliseconds ?? 0;
      songStartTime = DateTime.now().subtract(Duration(milliseconds: offsetMs));
    }

    if (isPlaying) {
      _pauseGraceTimer?.cancel();
      _pauseGraceTimer = null;
      _currentIsPlaying = true;

      // Skip redundant sends only if this exact track was ALREADY sent as playing
      if (!songChanged &&
          _lastSentIsPlaying == true &&
          _lastSentTitle == currentTitle &&
          posDiff <= 5) {
        return;
      }

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
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

  Future<void> _sendPresencePayload({
    required bool isPlaying,
    bool force = false,
  }) async {
    if (!isEnabled || token.isEmpty || _authFailed) return;

    if (!isGatewayConnected) {
      if (!_isSocketOpen && !_isConnecting) {
        connectGateway();
      }
      // Once READY / RESUMED arrives, it will automatically push current presence
      return;
    }

    final snapshotTitle = currentTitle;
    final snapshotArtist = currentArtist;
    final snapshotAlbum = currentAlbum;
    final snapshotArtUri = currentArtUri;
    final snapshotDuration = currentDuration;
    final snapshotPosition = currentPosition;

    if (!force &&
        _lastSentIsPlaying == isPlaying &&
        _lastSentTitle == snapshotTitle &&
        _lastSentArtist == snapshotArtist &&
        _lastSentArtUri == snapshotArtUri) {
      return;
    }

    final seq = ++_presenceDispatchSeq;
    String? largeAsset;
    String? smallAsset;

    if (isPlaying && snapshotTitle != null && snapshotTitle.isNotEmpty) {
      final resolved = await Future.wait([
        _resolveExternalAsset(snapshotArtUri),
        _resolveExternalAsset(_logoUrl),
      ]);
      if (seq != _presenceDispatchSeq) return; // Superseded by newer song/state
      largeAsset = resolved[0];
      smallAsset = resolved[1];
    }

    if (!isGatewayConnected) return;

    final payload = {
      "op": 3,
      "d": _buildPresencePayload(
        title: snapshotTitle,
        artist: snapshotArtist,
        album: snapshotAlbum,
        duration: snapshotDuration,
        position: snapshotPosition,
        isPlaying: isPlaying,
        largeAsset: largeAsset,
        smallAsset: smallAsset,
      )
    };

    try {
      _socket!.add(jsonEncode(payload));
      _lastSentTitle = isPlaying ? snapshotTitle : null;
      _lastSentArtist = isPlaying ? snapshotArtist : null;
      _lastSentArtUri = isPlaying ? snapshotArtUri : null;
      _lastSentIsPlaying = isPlaying;
      printINFO(
          'Presence updated: ${isPlaying ? (snapshotTitle ?? 'Cleared') : 'Paused/Cleared'} (artwork: ${largeAsset != null ? 'mp:external' : 'none'})',
          tag: 'Discord');
    } catch (e) {
      printWarning('Send presence error: $e', tag: 'Discord');
      _scheduleReconnect();
    }
  }

  void clearPresence() {
    _presenceDispatchSeq++;
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
    _resetSentCache();

    if (isGatewayConnected) {
      final payload = {
        "op": 3,
        "d": _buildPresencePayload(isPlaying: false),
      };
      try {
        _socket!.add(jsonEncode(payload));
      } catch (_) {}
    }
  }
}
