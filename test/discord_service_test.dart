import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:spymusic/services/discord_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('spymusic_discord_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('AppPrefs');
  });

  tearDown(() async {
    final discord = DiscordService();
    discord.clearPresence();
    discord.disconnectGateway();
    discord.gatewayUrlOverride = null;
    discord.externalAssetResolverOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('sanitizes tokens with quotes, Bearer prefix, and whitespace', () {
    final discord = DiscordService();
    discord.toggleStatus(false);
    discord.setToken('  Bearer "abc123.def456.ghi789" \n');
    expect(discord.token, 'abc123.def456.ghi789');
  });

  test('waits for READY before sending op:3 and resolves mp:external assets',
      () async {
    final receivedOps = <Map<String, dynamic>>[];
    final readyCompleter = Completer<void>();
    final presenceCompleter = Completer<Map<String, dynamic>>();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.transform(WebSocketTransformer()).listen((WebSocket ws) {
      ws.add(jsonEncode({
        'op': 10,
        'd': {'heartbeat_interval': 45000},
      }));

      ws.listen((raw) {
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        receivedOps.add(msg);
        if (msg['op'] == 2) {
          expect(receivedOps.where((m) => m['op'] == 3), isEmpty);
          ws.add(jsonEncode({
            'op': 0,
            't': 'READY',
            's': 1,
            'd': {
              'session_id': 'test_sess_123',
              'resume_gateway_url': 'ws://127.0.0.1:${server.port}',
            },
          }));
          if (!readyCompleter.isCompleted) readyCompleter.complete();
        } else if (msg['op'] == 3 && !presenceCompleter.isCompleted) {
          presenceCompleter.complete(msg);
        }
      });
    });

    try {
      final discord = DiscordService();
      discord.gatewayUrlOverride = 'ws://127.0.0.1:${server.port}';
      discord.externalAssetResolverOverride = (url) async =>
          url.contains('cover')
              ? 'mp:external/resolved_cover'
              : 'mp:external/resolved_logo';

      discord.isEnabled = true;
      discord.updatePresence(
        MediaItem(
          id: 'sp_42',
          title: 'X',
          artist: 'Test Artist',
          album: 'Test Album',
          duration: const Duration(minutes: 3),
          artUri: Uri.parse('https://example.com/cover.jpg'),
        ),
        isPlaying: true,
        position: const Duration(seconds: 15),
      );

      discord.setToken('valid_test_token_1234567890');
      await readyCompleter.future.timeout(const Duration(seconds: 3));
      final op3 =
          await presenceCompleter.future.timeout(const Duration(seconds: 3));

      expect(discord.isGatewayConnected, isTrue);
      expect(discord.connectionStatusNotifier.value, 'connected');

      final activities = op3['d']['activities'] as List;
      expect(activities, hasLength(1));
      final act = activities.first as Map<String, dynamic>;
      expect(act['application_id'], '962990036020756480');
      expect(act['type'], 2);
      expect(act['details'], 'X ');
      expect(act['state'], 'Test Artist');
      expect(act['assets']['large_image'], 'mp:external/resolved_cover');
      expect(act['assets']['small_image'], 'mp:external/resolved_logo');
      expect(act['buttons'], ['Listen on SPY Music', 'Get SPY Music']);
    } finally {
      await server.close(force: true);
    }
  });

  test('omits assets when external-assets fails (never sends raw https URL)',
      () async {
    final presenceCompleter = Completer<Map<String, dynamic>>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.transform(WebSocketTransformer()).listen((WebSocket ws) {
      ws.add(jsonEncode({
        'op': 10,
        'd': {'heartbeat_interval': 45000},
      }));
      ws.listen((raw) {
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        if (msg['op'] == 2) {
          ws.add(jsonEncode({
            'op': 0,
            't': 'READY',
            's': 1,
            'd': {
              'session_id': 'test_sess_no_assets',
              'resume_gateway_url': 'ws://127.0.0.1:${server.port}',
            },
          }));
        } else if (msg['op'] == 3 && !presenceCompleter.isCompleted) {
          presenceCompleter.complete(msg);
        }
      });
    });

    try {
      final discord = DiscordService();
      discord.gatewayUrlOverride = 'ws://127.0.0.1:${server.port}';
      discord.externalAssetResolverOverride = (_) async => null;
      discord.isEnabled = true;
      discord.updatePresence(
        MediaItem(
          id: 'yt_abc',
          title: 'Track Without Assets',
          artist: 'Artist',
          duration: const Duration(minutes: 2),
          artUri: Uri.parse('https://example.com/blocked.jpg'),
        ),
        isPlaying: true,
      );
      discord.setToken('valid_test_token_1234567890');

      final op3 =
          await presenceCompleter.future.timeout(const Duration(seconds: 3));
      final act = (op3['d']['activities'] as List).first as Map<String, dynamic>;
      expect(act.containsKey('assets'), isFalse);
      expect(act['application_id'], '962990036020756480');
    } finally {
      await server.close(force: true);
    }
  });

  test('stops reconnect loop on close code 4004 auth_failed', () async {
    int connectionCount = 0;
    final authFailedCompleter = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.transform(WebSocketTransformer()).listen((WebSocket ws) {
      connectionCount++;
      ws.add(jsonEncode({
        'op': 10,
        'd': {'heartbeat_interval': 45000},
      }));
      ws.listen((raw) async {
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        if (msg['op'] == 2) {
          await ws.close(4004, 'Authentication failed');
          if (!authFailedCompleter.isCompleted) authFailedCompleter.complete();
        }
      });
    });

    try {
      final discord = DiscordService();
      discord.gatewayUrlOverride = 'ws://127.0.0.1:${server.port}';
      discord.isEnabled = true;
      discord.setToken('bad_token_123456789012345');

      await authFailedCompleter.future.timeout(const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 250));
      expect(discord.connectionStatusNotifier.value, 'auth_failed');
      expect(connectionCount, 1);
    } finally {
      await server.close(force: true);
    }
  });
}

