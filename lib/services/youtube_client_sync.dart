import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/helper.dart';

/// Represents a YouTube InnerTube client dynamically parsed from yt-dlp.
class SyncedClient {
  final String key;
  final String clientName;
  final String clientVersion;
  final String userAgent;
  final String? deviceMake;
  final String? deviceModel;
  final String? osName;
  final String? osVersion;
  final int? contextClientName;
  final bool isJslessDefault;

  SyncedClient({
    required this.key,
    required this.clientName,
    required this.clientVersion,
    required this.userAgent,
    this.deviceMake,
    this.deviceModel,
    this.osName,
    this.osVersion,
    this.contextClientName,
    this.isJslessDefault = false,
  });

  /// Constructs a [YoutubeApiClient] from this dynamic client definition.
  YoutubeApiClient toYoutubeApiClient() {
    final clientMap = <String, dynamic>{
      'clientName': clientName,
      'clientVersion': clientVersion,
      'hl': 'en',
      'timeZone': 'UTC',
      'utcOffsetMinutes': 0,
    };
    if (userAgent.isNotEmpty) clientMap['userAgent'] = userAgent;
    if (deviceMake != null && deviceMake!.isNotEmpty) clientMap['deviceMake'] = deviceMake!;
    if (deviceModel != null && deviceModel!.isNotEmpty) clientMap['deviceModel'] = deviceModel!;
    if (osName != null && osName!.isNotEmpty) clientMap['osName'] = osName!;
    if (osVersion != null && osVersion!.isNotEmpty) clientMap['osVersion'] = osVersion!;

    final payload = {
      'context': {
        'client': clientMap,
      }
    };
    const apiUrl = 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';
    final headers = <String, dynamic>{
      if (contextClientName != null) 'X-Youtube-Client-Name': '$contextClientName',
      'X-Youtube-Client-Version': clientVersion,
    };
    return YoutubeApiClient(payload, apiUrl, headers: headers);
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'clientName': clientName,
        'clientVersion': clientVersion,
        'userAgent': userAgent,
        'deviceMake': deviceMake,
        'deviceModel': deviceModel,
        'osName': osName,
        'osVersion': osVersion,
        'contextClientName': contextClientName,
        'isJslessDefault': isJslessDefault,
      };

  factory SyncedClient.fromJson(Map<dynamic, dynamic> json) => SyncedClient(
        key: json['key']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        clientVersion: json['clientVersion']?.toString() ?? '',
        userAgent: json['userAgent']?.toString() ?? '',
        deviceMake: json['deviceMake']?.toString(),
        deviceModel: json['deviceModel']?.toString(),
        osName: json['osName']?.toString(),
        osVersion: json['osVersion']?.toString(),
        contextClientName: json['contextClientName'] != null
            ? int.tryParse(json['contextClientName'].toString())
            : null,
        isJslessDefault: json['isJslessDefault'] == true,
      );
}

/// Statistics for a synced client to support self-adapting priority & cooldowns.
class ClientStats {
  int consecutiveFailures;
  int lastSuccessTimestamp;
  int lastFailureTimestamp;
  int successCount;
  int failureCount;

  ClientStats({
    this.consecutiveFailures = 0,
    this.lastSuccessTimestamp = 0,
    this.lastFailureTimestamp = 0,
    this.successCount = 0,
    this.failureCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'consecutiveFailures': consecutiveFailures,
        'lastSuccessTimestamp': lastSuccessTimestamp,
        'lastFailureTimestamp': lastFailureTimestamp,
        'successCount': successCount,
        'failureCount': failureCount,
      };

  factory ClientStats.fromJson(Map<dynamic, dynamic> json) => ClientStats(
        consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
        lastSuccessTimestamp: (json['lastSuccessTimestamp'] as num?)?.toInt() ?? 0,
        lastFailureTimestamp: (json['lastFailureTimestamp'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        failureCount: (json['failureCount'] as num?)?.toInt() ?? 0,
      );
}

/// Service that keeps YouTube clients automatically updated without app updates
/// by reading yt-dlp's `_base.py` and `_video.py` definitions every 12 hours
/// or after YouTube outages.
class YoutubeClientSync {
  YoutubeClientSync._internal();
  static final YoutubeClientSync instance = YoutubeClientSync._internal();

  static const String baseUrl =
      'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_base.py';
  static const String videoUrl =
      'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_video.py';

  static const int syncIntervalMs = 12 * 60 * 60 * 1000; // 12 hours
  static const int outageSyncIntervalMs = 60 * 60 * 1000; // 1 hour
  static const int failureCooldownMs = 30 * 60 * 1000; // 30 minutes

  static const String prefsBoxName = 'AppPrefs';
  static const String keySyncedClients = 'yt_synced_clients';
  static const String keyLastSyncTime = 'yt_client_sync_timestamp';
  static const String keySyncStatus = 'yt_client_sync_status';
  static const String keyClientStats = 'yt_client_stats';
  static const String keyClientUserAgents = 'yt_client_user_agents';

  bool _isSyncing = false;
  int _lastOutageSyncAttempt = 0;

  final List<SyncedClient> _clients = [];
  final Map<String, ClientStats> _stats = {};
  final Map<String, String> _userAgents = {};

  String _statusDescription = "Initialisierung...";

  /// Current human-readable status description for the Developer Mode Sheet.
  String get statusDescription => _statusDescription;

  /// Built-in fallback clients kept as resilient baseline and last reserve.
  static final List<SyncedClient> builtInFallbackClients = [
    SyncedClient(
      key: 'visionos',
      clientName: 'VISIONOS',
      clientVersion: '1.02',
      userAgent:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
      deviceMake: 'Apple',
      deviceModel: 'RealityDevice17,1',
      osName: 'visionOS',
      osVersion: '26.5.23O471',
      contextClientName: 101,
      isJslessDefault: true,
    ),
    SyncedClient(
      key: 'ios_producer',
      clientName: 'IOS_PRODUCER',
      clientVersion: '0.147.945',
      userAgent:
          'com.google.ios.youtubeproducer/0.147.945 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      deviceMake: 'Apple',
      deviceModel: 'iPhone16,2',
      osName: 'iPhone',
      osVersion: '18.3.2.22D82',
      contextClientName: 92,
      isJslessDefault: false,
    ),
    SyncedClient(
      key: 'androidSdkless',
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      userAgent:
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      deviceMake: null,
      deviceModel: null,
      osName: 'Android',
      osVersion: '11',
      contextClientName: 3,
      isJslessDefault: false,
    ),
  ];

  /// Initializes cached clients from Hive immediately on app launch (zero network delay),
  /// then triggers a background sync if 12h elapsed or if no clients are cached.
  Future<void> initAndSyncOnLaunch() async {
    _loadFromHive();
    final lastSync = _getLastSyncTimestamp();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_clients.isEmpty || (now - lastSync) >= syncIntervalMs) {
      unawaited(sync());
    }
  }

  /// Loads cached state from Hive without blocking startup.
  void _loadFromHive() {
    try {
      if (!Hive.isBoxOpen(prefsBoxName)) return;
      final box = Hive.box(prefsBoxName);

      // Load User-Agent map
      final rawUas = box.get(keyClientUserAgents);
      if (rawUas is Map) {
        _userAgents.clear();
        rawUas.forEach((k, v) {
          if (k != null && v != null) {
            _userAgents[k.toString().toLowerCase()] = v.toString();
          }
        });
      }

      // Load client stats
      final rawStats = box.get(keyClientStats);
      if (rawStats is Map) {
        _stats.clear();
        rawStats.forEach((k, v) {
          if (k != null && v is Map) {
            _stats[k.toString()] = ClientStats.fromJson(v);
          }
        });
      }

      // Load clients
      final rawClients = box.get(keySyncedClients);
      if (rawClients is List && rawClients.isNotEmpty) {
        _clients.clear();
        for (final item in rawClients) {
          if (item is Map) {
            _clients.add(SyncedClient.fromJson(item));
          }
        }
      }

      final lastTime = _getLastSyncTimestamp();
      final timeStr = lastTime > 0 ? _formatTimestamp(lastTime) : 'Nie';
      if (_clients.isNotEmpty) {
        _statusDescription = "OK, ${_clients.length} Clients, Stand $timeStr";
      } else {
        _clients.addAll(builtInFallbackClients);
        _populateFallbackUserAgents();
        _statusDescription = "Fallback, Stand $timeStr";
      }
    } catch (e) {
      printERROR("Failed to load synced YouTube clients from Hive: $e");
      if (_clients.isEmpty) {
        _clients.addAll(builtInFallbackClients);
        _populateFallbackUserAgents();
      }
      _statusDescription = "Fallback (Fehler beim Laden)";
    }
  }

  void _populateFallbackUserAgents() {
    for (final c in builtInFallbackClients) {
      _userAgents[c.clientName.toLowerCase()] = c.userAgent;
      _userAgents[c.key.toLowerCase()] = c.userAgent;
    }
    _userAgents['android'] = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
    _userAgents['ios'] = 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
    _userAgents['visionos'] =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15';
    _userAgents['ios_producer'] =
        'com.google.ios.youtubeproducer/0.147.945 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  }

  int _getLastSyncTimestamp() {
    try {
      if (Hive.isBoxOpen(prefsBoxName)) {
        final val = Hive.box(prefsBoxName).get(keyLastSyncTime);
        if (val is int) return val;
        if (val is num) return val.toInt();
      }
    } catch (_) {}
    return 0;
  }

  /// Performs client sync from yt-dlp repository.
  /// Strictly reads data via regex, never executes arbitrary code.
  /// Timeout 6s per request.
  Future<bool> sync({bool force = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastSync = _getLastSyncTimestamp();
      if (!force && (now - lastSync) < syncIntervalMs) {
        _isSyncing = false;
        return true;
      }

      printINFO("Starting YouTube client sync from yt-dlp repository...");
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      String basePy = '';
      String videoPy = '';

      try {
        final reqBase = await client.getUrl(Uri.parse(baseUrl)).timeout(const Duration(seconds: 6));
        final respBase = await reqBase.close().timeout(const Duration(seconds: 6));
        if (respBase.statusCode == 200) {
          basePy = await respBase.transform(const Utf8Decoder(allowMalformed: true)).join();
        }

        final reqVideo = await client.getUrl(Uri.parse(videoUrl)).timeout(const Duration(seconds: 6));
        final respVideo = await reqVideo.close().timeout(const Duration(seconds: 6));
        if (respVideo.statusCode == 200) {
          videoPy = await respVideo.transform(const Utf8Decoder(allowMalformed: true)).join();
        }
      } finally {
        client.close(force: true);
      }

      if (basePy.isEmpty) {
        throw Exception("Failed to fetch _base.py from yt-dlp (HTTP error or empty response)");
      }

      final parsedClients = parseClients(basePy, videoPy);
      if (parsedClients.isEmpty) {
        throw Exception("Parser extracted 0 eligible JS-less clients without PO token");
      }

      // Keep maximum 3 clients as requested
      final selectedClients = parsedClients.take(3).toList();

      _clients.clear();
      _clients.addAll(selectedClients);

      // Always ensure fallback User-Agents are preserved
      _populateFallbackUserAgents();
      for (final c in selectedClients) {
        _userAgents[c.clientName.toLowerCase()] = c.userAgent;
        _userAgents[c.key.toLowerCase()] = c.userAgent;
      }

      final timeStr = _formatTimestamp(now);
      _statusDescription = "OK, ${selectedClients.length} Clients, Stand $timeStr";

      // Persist in Hive
      if (Hive.isBoxOpen(prefsBoxName)) {
        final box = Hive.box(prefsBoxName);
        await box.put(keySyncedClients, selectedClients.map((c) => c.toJson()).toList());
        await box.put(keyLastSyncTime, now);
        await box.put(keySyncStatus, _statusDescription);
        await box.put(keyClientUserAgents, _userAgents);
      }

      printINFO(
          "YouTube client sync succeeded: ${selectedClients.map((c) => '${c.key} (${c.clientName} v${c.clientVersion})').join(', ')}");
      _isSyncing = false;
      return true;
    } catch (e) {
      printERROR("YouTube client sync error: $e");
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeStr = _formatTimestamp(now);
      if (_clients.isEmpty) {
        _clients.addAll(builtInFallbackClients);
        _populateFallbackUserAgents();
      }
      _statusDescription = "Fallback, Stand $timeStr";
      _isSyncing = false;
      return false;
    }
  }

  /// Parses `_base.py` and `_video.py` to identify eligible YouTube clients.
  /// Requirements:
  /// (a) REQUIRE_JS_PLAYER is False
  /// (b) GVS_PO_TOKEN_POLICY for HTTPS does not require PO tokens (required != True)
  /// (c) Prioritizes clients listed in _DEFAULT_JSLESS_CLIENTS from _video.py.
  List<SyncedClient> parseClients(String basePy, String videoPy) {
    // 1. Read _DEFAULT_JSLESS_CLIENTS from _video.py
    final jslessClients = <String>[];
    if (videoPy.isNotEmpty) {
      final jslessMatch =
          RegExp(r'_DEFAULT_JSLESS_CLIENTS\s*=\s*\(([^)]*)\)').firstMatch(videoPy);
      if (jslessMatch != null) {
        final rawList = jslessMatch.group(1) ?? '';
        for (final item in rawList.split(',')) {
          final clean = item.trim().replaceAll("'", "").replaceAll('"', '');
          if (clean.isNotEmpty) {
            jslessClients.add(clean);
          }
        }
      }
    }

    // 2. Read INNERTUBE_CLIENTS from _base.py
    final startIdx = basePy.indexOf('INNERTUBE_CLIENTS = {');
    if (startIdx == -1) return [];

    final endIdx = basePy.indexOf('\nclass ', startIdx);
    final innertubeBlock =
        endIdx != -1 ? basePy.substring(startIdx, endIdx) : basePy.substring(startIdx);

    final clientNameMatches =
        RegExp(r"^[ ]{4}'([a-zA-Z0-9_]+)':\s*\{(?!\})", multiLine: true)
            .allMatches(innertubeBlock);

    final eligible = <SyncedClient>[];

    for (final match in clientNameMatches) {
      final key = match.group(1)!;
      final blockRegex = RegExp(
          r"^[ ]{4}'" + key + r"':\s*\{(.*?)\n[ ]{4}\},",
          dotAll: true,
          multiLine: true);
      final blockMatch = blockRegex.firstMatch(innertubeBlock);
      if (blockMatch == null) continue;
      final body = blockMatch.group(1)!;

      // Rule (a): REQUIRE_JS_PLAYER must be False
      final reqJsMatch =
          RegExp(r"'REQUIRE_JS_PLAYER':\s*(True|False)").firstMatch(body);
      if (reqJsMatch == null || reqJsMatch.group(1) != 'False') {
        continue;
      }

      // Rule (b): In GVS_PO_TOKEN_POLICY for HTTPS, required=True must NOT be present
      final httpsPoMatch = RegExp(
              r'StreamingProtocol\.HTTPS\s*:\s*GvsPoTokenPolicy\(([^)]*)\)',
              dotAll: true)
          .firstMatch(body);
      if (httpsPoMatch != null) {
        final poBody = httpsPoMatch.group(1)!;
        if (RegExp(r'required\s*=\s*True').hasMatch(poBody)) {
          continue; // requires PO token
        }
      }

      final clientName =
          RegExp(r"'clientName':\s*'([^']+)'").firstMatch(body)?.group(1);
      final clientVersion =
          RegExp(r"'clientVersion':\s*'([^']+)'").firstMatch(body)?.group(1);
      final userAgent =
          RegExp(r"'userAgent':\s*'([^']+)'").firstMatch(body)?.group(1);
      final deviceMake =
          RegExp(r"'deviceMake':\s*'([^']+)'").firstMatch(body)?.group(1);
      final deviceModel =
          RegExp(r"'deviceModel':\s*'([^']+)'").firstMatch(body)?.group(1);
      final osName =
          RegExp(r"'osName':\s*'([^']+)'").firstMatch(body)?.group(1);
      final osVersion =
          RegExp(r"'osVersion':\s*'([^']+)'").firstMatch(body)?.group(1);
      final contextClientName = RegExp(
              r"'INNERTUBE_CONTEXT_CLIENT_NAME':\s*([0-9]+)")
          .firstMatch(body)
          ?.group(1);

      if (clientName != null && clientVersion != null) {
        eligible.add(SyncedClient(
          key: key,
          clientName: clientName,
          clientVersion: clientVersion,
          userAgent: userAgent ?? '',
          deviceMake: deviceMake,
          deviceModel: deviceModel,
          osName: osName,
          osVersion: osVersion,
          contextClientName: contextClientName != null
              ? int.tryParse(contextClientName)
              : null,
          isJslessDefault: jslessClients.contains(key),
        ));
      }
    }

    // Sort: JS-less defaults first, then others
    eligible.sort((a, b) {
      if (a.isJslessDefault && !b.isJslessDefault) return -1;
      if (!a.isJslessDefault && b.isJslessDefault) return 1;
      return 0;
    });

    return eligible;
  }

  /// Triggers an immediate refresh when a total YouTube outage is detected,
  /// at most once per hour.
  void onYouTubeTotalOutage() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - _lastOutageSyncAttempt) >= outageSyncIntervalMs) {
      _lastOutageSyncAttempt = now;
      printINFO("YouTube total outage reported: triggering immediate background client sync...");
      unawaited(sync(force: true));
    }
  }

  /// Records a successful stream extraction for self-adapting priority.
  void recordSuccess(String clientKey) {
    final stat = _stats.putIfAbsent(clientKey, () => ClientStats());
    stat.consecutiveFailures = 0;
    stat.lastSuccessTimestamp = DateTime.now().millisecondsSinceEpoch;
    stat.successCount++;
    _persistStats();
  }

  /// Records a failed stream extraction. After 3 consecutive failures,
  /// the client receives a 30-minute cooldown.
  void recordFailure(String clientKey) {
    final stat = _stats.putIfAbsent(clientKey, () => ClientStats());
    stat.consecutiveFailures++;
    stat.lastFailureTimestamp = DateTime.now().millisecondsSinceEpoch;
    stat.failureCount++;
    _persistStats();
  }

  void _persistStats() {
    try {
      if (Hive.isBoxOpen(prefsBoxName)) {
        final box = Hive.box(prefsBoxName);
        box.put(keyClientStats, _stats.map((k, v) => MapEntry(k, v.toJson())));
      }
    } catch (_) {}
  }

  /// Returns active [SyncedClient] list, self-adapting based on success history
  /// and applying 30-minute cooldown for clients with >= 3 consecutive failures.
  /// Always returns at most 3 clients, ensuring built-in fallback as reserve.
  List<SyncedClient> getActiveClients() {
    if (_clients.isEmpty) {
      _loadFromHive();
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    // Filter out clients in cooldown (>= 3 consecutive failures within last 30m)
    var available = _clients.where((c) {
      final s = _stats[c.key];
      if (s != null && s.consecutiveFailures >= 3) {
        if ((now - s.lastFailureTimestamp) < failureCooldownMs) {
          return false; // In 30m cooldown
        }
      }
      return true;
    }).toList();

    // If all clients got placed in cooldown, release cooldown to prevent starvation
    if (available.isEmpty) {
      available = List.from(_clients.isNotEmpty ? _clients : builtInFallbackClients);
    }

    // Sort order:
    // 1. Most recently successful client comes first
    // 2. JS-less default clients
    // 3. Other clients
    available.sort((a, b) {
      final sa = _stats[a.key]?.lastSuccessTimestamp ?? 0;
      final sb = _stats[b.key]?.lastSuccessTimestamp ?? 0;
      if (sa != sb) return sb.compareTo(sa); // higher timestamp first

      if (a.isJslessDefault && !b.isJslessDefault) return -1;
      if (!a.isJslessDefault && b.isJslessDefault) return 1;
      return 0;
    });

    final result = available.take(3).toList();
    // Guarantee at least 1 client
    if (result.isEmpty) {
      result.add(builtInFallbackClients.first);
    }
    return result;
  }

  /// Returns the matching User-Agent for a stream URL based on its `c=` query param.
  /// If unknown, falls back cleanly according to platform parameter or default Android UA.
  String getUserAgentForStreamUrl(String url) {
    String? clientTag;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.queryParameters.containsKey('c')) {
        clientTag = uri.queryParameters['c']?.toLowerCase();
      }
    } catch (_) {}

    if (clientTag == null || clientTag.isEmpty) {
      final cMatch = RegExp(r'[?&]c=([^&]+)').firstMatch(url);
      if (cMatch != null) {
        clientTag = cMatch.group(1)?.toLowerCase();
      }
    }

    if (clientTag != null && clientTag.isNotEmpty) {
      if (_userAgents.containsKey(clientTag)) {
        return _userAgents[clientTag]!;
      }
      // Check underscore alias (e.g. ios_producer <-> iosproducer)
      final stripped = clientTag.replaceAll('_', '');
      for (final entry in _userAgents.entries) {
        if (entry.key.replaceAll('_', '') == stripped) {
          return entry.value;
        }
      }
    }

    if (url.contains('c=IOS')) {
      return 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
    }
    return 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  }

  /// Generates the appropriate stream headers map with a single 'User-Agent' key.
  Map<String, String>? buildStreamHeaders(String url) {
    if (!url.contains('googlevideo.com') && !url.contains('c=')) {
      return null;
    }
    final ua = getUserAgentForStreamUrl(url);
    if (ua.isNotEmpty) {
      return {'User-Agent': ua};
    }
    return null;
  }

  String _formatTimestamp(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return "$day.$month. $hour:$minute";
  }
}
