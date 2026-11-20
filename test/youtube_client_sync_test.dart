import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:spymusic/services/audio_handler.dart';
import 'package:spymusic/services/youtube_client_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('yt_client_sync_test');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen('AppPrefs')) {
      await Hive.openBox('AppPrefs');
    }
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('YoutubeClientSync Unit Tests', () {
    test('1. Built-in fallback clients are valid and convert to YoutubeApiClient', () {
      final clients = YoutubeClientSync.builtInFallbackClients;
      expect(clients.length, greaterThanOrEqualTo(2));

      final visionos = clients.firstWhere((c) => c.key == 'visionos');
      expect(visionos.clientName, 'VISIONOS');
      expect(visionos.isJslessDefault, isTrue);

      final apiObj = visionos.toYoutubeApiClient();
      expect(apiObj.apiUrl, contains('player'));
      expect(apiObj.headers['X-Youtube-Client-Name'], '101');
      expect(apiObj.payload['context']['client']['clientName'], 'VISIONOS');
    });

    test('2. Parser extracts eligible JS-less clients without PO token', () {
      const mockBasePy = '''
INNERTUBE_CLIENTS = {
    'web_music': {
        'INNERTUBE_CONTEXT': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.0'}},
        'GVS_PO_TOKEN_POLICY': {StreamingProtocol.HTTPS: GvsPoTokenPolicy(required=True)},
    },
    'android': {
        'INNERTUBE_CONTEXT': {'client': {'clientName': 'ANDROID', 'clientVersion': '21.0', 'userAgent': 'com.google.android.youtube/21.0 gzip'}},
        'INNERTUBE_CONTEXT_CLIENT_NAME': 3,
        'REQUIRE_JS_PLAYER': False,
        'GVS_PO_TOKEN_POLICY': {StreamingProtocol.HTTPS: GvsPoTokenPolicy(required=True)},
    },
    'ios_producer': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'IOS_PRODUCER',
                'clientVersion': '0.147.945',
                'userAgent': 'com.google.ios.youtubeproducer/0.147.945',
                'deviceMake': 'Apple',
                'deviceModel': 'iPhone16,2',
                'osName': 'iPhone',
                'osVersion': '18.3.2',
            },
        },
        'INNERTUBE_CONTEXT_CLIENT_NAME': 92,
        'REQUIRE_JS_PLAYER': False,
    },
    'visionos': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'VISIONOS',
                'clientVersion': '1.02',
                'userAgent': 'Mozilla/5.0 VisionOS',
            },
        },
        'INNERTUBE_CONTEXT_CLIENT_NAME': 101,
        'REQUIRE_JS_PLAYER': False,
    },
}
class SomeClass:
''';

      const mockVideoPy = '''
    _DEFAULT_JSLESS_CLIENTS = ('visionos',)
''';

      final sync = YoutubeClientSync.instance;
      final parsed = sync.parseClients(mockBasePy, mockVideoPy);
      expect(parsed.length, 2);
      expect(parsed.first.key, 'visionos'); // JS-less default prioritized
      expect(parsed.last.key, 'ios_producer');
    });

    test('3. Self-adapting priority sorts most recent success first and pauses on 3 failures', () {
      final sync = YoutubeClientSync.instance;

      // Reset and test recordSuccess
      sync.recordSuccess('ios_producer');
      var active = sync.getActiveClients();
      expect(active.first.key, 'ios_producer');

      sync.recordSuccess('visionos');
      active = sync.getActiveClients();
      expect(active.first.key, 'visionos');

      // Test consecutive failures triggers cooldown
      sync.recordFailure('visionos');
      sync.recordFailure('visionos');
      sync.recordFailure('visionos');

      active = sync.getActiveClients();
      // visionos should be placed on 30m cooldown, so ios_producer comes first
      expect(active.first.key, isNot('visionos'));
    });

    test('4. Dynamic User-Agent lookup maps c= parameter correctly', () {
      const visionosUrl =
          'https://rr3---sn-2oi5h5-5j.googlevideo.com/videoplayback?itag=140&c=VISIONOS&expire=123';
      const iosProducerUrl =
          'https://rr3---sn-2oi5h5-5j.googlevideo.com/videoplayback?itag=140&c=IOS_PRODUCER&expire=123';
      const androidUrl =
          'https://rr3---sn-2oi5h5-5j.googlevideo.com/videoplayback?itag=140&c=ANDROID&expire=123';
      const iosUrl =
          'https://rr3---sn-2oi5h5-5j.googlevideo.com/videoplayback?itag=140&c=IOS&expire=123';

      final visionosHdr = MyAudioHandler.buildStreamHeaders(visionosUrl);
      expect(visionosHdr?['User-Agent'], contains('Mozilla'));

      final iosProducerHdr = MyAudioHandler.buildStreamHeaders(iosProducerUrl);
      expect(iosProducerHdr?['User-Agent'], contains('com.google.ios.youtubeproducer'));

      final androidHdr = MyAudioHandler.buildStreamHeaders(androidUrl);
      expect(androidHdr?['User-Agent'], contains('com.google.android.youtube'));

      final iosHdr = MyAudioHandler.buildStreamHeaders(iosUrl);
      expect(iosHdr?['User-Agent'], contains('com.google.ios.youtube'));
    });

    test('5. getActiveClients never exceeds 3 clients', () {
      final sync = YoutubeClientSync.instance;
      final active = sync.getActiveClients();
      expect(active.length, lessThanOrEqualTo(3));
      expect(active.length, greaterThanOrEqualTo(1));
    });
  });
}
