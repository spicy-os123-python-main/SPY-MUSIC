// ignore_for_file: avoid_print
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/models/media_Item_builder.dart';
import 'package:spymusic/services/platform_search_service.dart';
import 'package:spymusic/services/utils.dart';

void main() {
  group('Duration Parsing and Sanitization Fix Tests', () {
    test('1. parseDuration calculates seconds accurately (no 3600x multiplier bug)', () {
      // Test seconds-only / short clips
      expect(parseDuration('0:37'), equals(37));
      expect(parseDuration('37'), equals(37));

      // Test standard songs
      expect(parseDuration('3:45'), equals(225));
      expect(parseDuration('2:16'), equals(136));
      expect(parseDuration('4:12'), equals(252));

      // Test hours + minutes + seconds
      expect(parseDuration('1:02:15'), equals(3735));

      // Test edge cases
      expect(parseDuration(''), isNull);
      expect(parseDuration(null), isNull);
    });

    test('2. MediaItemBuilder heals corrupted duration (136440s -> 2:16)', () {
      // Simulating a track that had corrupted duration from previous buggy parseDuration (37:54:00)
      final corruptedJson = {
        'id': 'test_song',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'length': '2:16',
        'duration': 136440, // 37 hours 54 minutes!
        'duration_seconds': 136440,
      };

      final item = MediaItemBuilder.fromJson(corruptedJson);
      expect(item.duration, isNotNull);
      // Must be healed to 2 minutes 16 seconds (136s), NOT 37 hours!
      expect(item.duration!.inSeconds, equals(136));
      expect(item.duration!.inMinutes, equals(2));
      expect(item.duration!.inHours, equals(0));
    });

    test('3. MediaItemBuilder normalizes milliseconds if raw duration was in ms', () {
      final jsonWithMs = {
        'id': 'ms_song',
        'title': 'MS Song',
        'artist': 'MS Artist',
        'duration': 210000, // 210,000 ms = 210s = 3m 30s
      };

      final item = MediaItemBuilder.fromJson(jsonWithMs);
      expect(item.duration, isNotNull);
      expect(item.duration!.inSeconds, equals(210));
      expect(item.duration!.inMinutes, equals(3));
      expect(item.duration!.inHours, equals(0));
    });

    test('4. PlatformSearchService.findBestMatch ignores corrupted >12h durations', () {
      const originalCorrupted = MediaItem(
        id: 'sp_corrupted',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(hours: 37, minutes: 54), // Corrupted 37:54:00
        extras: {
          'length': '3:20',
          'searchQuery': 'The Weeknd Blinding Lights',
        },
      );

      const candidate = MediaItem(
        id: 'real_candidate',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(minutes: 3, seconds: 20),
        extras: {'length': '3:20'},
      );

      final match = PlatformSearchService.findBestMatch(
        [candidate],
        originalCorrupted,
      );

      expect(match, isNotNull);
      expect(match!.id, equals('real_candidate'));
    });
  });
}
