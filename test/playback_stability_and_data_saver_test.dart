// ignore_for_file: avoid_print
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/services/music_service.dart';
import 'package:spymusic/services/platform_search_service.dart';
import 'package:spymusic/services/stream_service.dart';
import 'package:spymusic/ui/widgets/sort_widget.dart';
import 'package:spymusic/utils/helper.dart';

void main() {
  HttpOverrides.global = null;

  group('Playback Stability & Data Saver Tests', () {
    test('1. YouTube Music API searches without HTML scrapers', () async {
      final ms = MusicServices();
      final res = await ms.search('Brand New Car Squish', filter: 'songs', limit: 5);
      final songs = res['Songs'] as List? ?? [];
      expect(songs, isNotEmpty);
      expect(
        songs.any((s) => (s as MediaItem).title.toLowerCase().contains('brand new car')),
        isTrue,
      );
      final match = songs.firstWhere(
        (s) => (s as MediaItem).title.toLowerCase().contains('brand new car'),
      ) as MediaItem;
      print('Found YTM song: ${match.title} by ${match.artist} (${match.id})');
    });

    test('2. Pure audio stream resolution respects data limit (itag 140, 251, 250, 139, 249)', () async {
      final stream = await StreamProvider.fetch('PCWfyw2y8_c');
      expect(stream.playable, isTrue);
      expect(stream.highestQualityAudio, isNotNull);

      // Verify that highest quality audio is pure audio
      final hq = stream.highestQualityAudio!;
      expect(hq.url, isNotEmpty);
      expect([140, 251, 250, 139, 249].contains(hq.itag), isTrue,
          reason: 'Expected pure audio itag (140, 251, 250, 139, 249) but got ${hq.itag}');

      // Verify low quality audio for Data Saver mode
      final lq = stream.lowQualityAudio;
      expect(lq, isNotNull);
      expect([139, 249, 250, 140, 599, 600].contains(lq!.itag), isTrue);

      print('Audio verified: hq itag=${hq.itag}, lq itag=${lq.itag}, size=${hq.size} bytes');
    });

    test('3. Pseudonym/Leak Matching for Brand New Car (Squish -> swisssss)', () {
      const original = MediaItem(
        id: 'sp_brand_new_car',
        title: 'Brand New Car',
        artist: 'Squish',
        duration: Duration(seconds: 183),
        extras: {
          'playlistName': 'Juice wrld xxxtentacion Lil peep',
        },
      );

      final candidates = [
        const MediaItem(
          id: 'PCWfyw2y8_c',
          title: 'Brand New Car',
          artist: 'swisssss',
          duration: Duration(seconds: 183),
        ),
        const MediaItem(
          id: 'Vsczotn7eg4',
          title: 'BRAND NEW CAR',
          artist: 'Brenn!',
          duration: Duration(seconds: 150),
        ),
      ];

      final match = PlatformSearchService.findBestMatch(
        candidates,
        original,
        allowFidelityTitleDurationMatch: true,
      );

      expect(match, isNotNull);
      expect(match!.id, 'PCWfyw2y8_c');
      expect(match.title, 'Brand New Car');
    });

    test('4. Playlist date sorting default (newest first)', () {
      const item1 = MediaItem(
        id: '1',
        title: 'Older Song',
        extras: {'date': 1000},
      );
      const item2 = MediaItem(
        id: '2',
        title: 'Newer Song',
        extras: {'date': 5000},
      );

      final list = [item1, item2];
      // isAscending: false -> newest (highest timestamp) first
      sortSongsNVideos(list, SortType.Date, false);

      expect(list.first.id, '2');
      expect(list.last.id, '1');
    });
  });
}
