import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:spymusic/services/live_config_service.dart';
import 'package:spymusic/ui/widgets/spy_launch_screen.dart';
import 'package:spymusic/utils/get_localization.dart';

class _MockLiveConfigAdapter implements HttpClientAdapter {
  final String jsonPayload;
  _MockLiveConfigAdapter(this.jsonPayload);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonPayload,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUp(() {
    Get.addTranslations(Languages().keys);
    Get.locale = const Locale('en');
  });

  tearDown(Get.reset);

  group('LiveConfig & Launch Screen', () {
    test('LiveConfig enforces splash floor >= 3000ms even if remote sends less',
        () {
      final tooLow = LiveConfig.fromJson(<String, dynamic>{
        'minSplashMs': 500,
        'winterUpdateEnabled': true,
      });
      expect(tooLow.minSplashMs, greaterThanOrEqualTo(3000));

      final negative = LiveConfig.fromJson(<String, dynamic>{
        'minSplashMs': -200,
      });
      expect(negative.minSplashMs, greaterThanOrEqualTo(3000));

      final higher = LiveConfig.fromJson(<String, dynamic>{
        'minSplashMs': 4500,
      });
      expect(higher.minSplashMs, 4500);
    });

    test('LiveConfigService syncs live JSON from remote server without APK update',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockLiveConfigAdapter(
        jsonEncode(<String, dynamic>{
          'configVersion': 2,
          'season': 'spring',
          'winterUpdateEnabled': false,
          'santaHatEnabled': true,
          'snowEnabled': true,
          'minSplashMs': 3500,
          'bannerText': 'Spring Live Drop',
        }),
      );

      final service = LiveConfigService(
        dio: dio,
        configUrl: 'https://example.invalid/live_config.json',
      );
      final synced = await service.fetchAndSync();

      expect(synced.configVersion, 2);
      expect(synced.winterUpdateEnabled, isFalse);
      expect(synced.showSantaHat, isFalse);
      expect(synced.showSnow, isFalse);
      expect(synced.minSplashMs, 3500);
      expect(synced.bannerText, 'Spring Live Drop');
    });

    testWidgets('SpyLaunchScreen shows Santa hat and snow in Winter Update',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: SpyLaunchScreen(
            config: LiveConfig.defaults(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey<String>('spy_santa_hat')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('spy_snow_layer')), findsOneWidget);
      expect(find.text('SPY MUSIC'), findsOneWidget);
      expect(find.text('Winter Update'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SpyLaunchScreen hides Santa hat & snow when live config disables winter',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpyLaunchScreen(
            config: LiveConfig(
              winterUpdateEnabled: false,
              santaHatEnabled: true,
              snowEnabled: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey<String>('spy_santa_hat')), findsNothing);
      expect(find.byKey(const ValueKey<String>('spy_snow_layer')), findsNothing);
      expect(find.text('SPY MUSIC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SpyLaunchGate stays visible for >= 3 seconds before entering Home',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpyLaunchGate(
            enableRemoteFetch: false,
            child: Scaffold(
              body: Center(child: Text('HOME_READY')),
            ),
          ),
        ),
      );

      // Still on launch screen before 3 seconds
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.byKey(const ValueKey<String>('spy_launch_screen')), findsOneWidget);
      expect(find.text('HOME_READY'), findsNothing);

      // Advances past 3.2s minimum duration + fade transition
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('HOME_READY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

