import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:spymusic/services/nav_parser.dart';
import 'package:spymusic/services/continuations.dart';
import 'package:spymusic/services/soundcloud_service.dart';
import 'package:spymusic/utils/helper.dart';
import 'package:spymusic/ui/widgets/sort_widget.dart';
import 'package:spymusic/models/media_Item_builder.dart';

// Simulated obfuscated release class (like GPA / CNa) without containsKey or title
class ObfuscatedGPA {
  final int id = 42;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AOT Obfuscation & Malformed Model Resilience (GPA / CNa scenario)', () {
    test('parseMixedContent handles rows containing non-Map or empty items safely', () {
      final rows = [
        ObfuscatedGPA(), // Class without containsKey or first
        null,
        'random string',
        123,
        <String, dynamic>{},
        {
          'musicCarouselShelfRenderer': {
            'header': null,
            'contents': [
              ObfuscatedGPA(),
              null,
              {'musicTwoRowItemRenderer': null},
            ]
          }
        }
      ];

      expect(() => parseMixedContent(rows), returnsNormally);
      final result = parseMixedContent(rows);
      expect(result, isA<List<Map<String, dynamic>>>());
    });

    test('parseVideo safely handles missing or empty subtitle runs', () {
      expect(() => parseVideo(null), returnsNormally);
      expect(() => parseVideo(ObfuscatedGPA()), returnsNormally);
      expect(() => parseVideo({'subtitle': null}), returnsNormally);
      expect(() => parseVideo({'subtitle': {'runs': []}}), returnsNormally);
      expect(() => parseVideo({'subtitle': {'runs': ['not a map']}}), returnsNormally);
    });

    test('parseSingle safely handles missing runs or non-integer year', () {
      expect(() => parseSingle(null), returnsNormally);
      expect(() => parseSingle({'subtitle': null}), returnsNormally);
      expect(() => parseSingle({'subtitle': {'runs': null}}), returnsNormally);
    });

    test('parseSongRuns handles null, empty, or non-Map run entries safely', () {
      expect(parseSongRuns(null), equals({'artists': []}));
      expect(parseSongRuns([]), equals({'artists': []}));
      expect(parseSongRuns([null, 'bad', ObfuscatedGPA()]), equals({'artists': []}));
      final runsWithData = [
        {'text': 'Artist 1', 'navigationEndpoint': {'browseEndpoint': {'browseId': 'UC123'}}},
        {'text': ' • '},
        {'text': '2025'}
      ];
      final parsed = parseSongRuns(runsWithData);
      expect(parsed['artists'], isNotEmpty);
      expect(parsed['year'], equals('2025'));
    });

    test('getTabBrowseId safely handles null or non-Map watchNextRenderer without TypeError', () {
      expect(getTabBrowseId(null, 1), isNull);
      expect(getTabBrowseId(ObfuscatedGPA(), 1), isNull);
      expect(getTabBrowseId('not a map', 2), isNull);
      expect(getTabBrowseId({}, 1), isNull);
    });

    test('parseWatchPlaylist safely skips unplayable or malformed wrapper renders', () {
      final results = [
        ObfuscatedGPA(),
        null,
        {'playlistPanelVideoWrapperRenderer': {'counterpart': []}},
        {'playlistPanelVideoRenderer': {'unplayableText': 'blocked'}},
      ];
      expect(() => parseWatchPlaylist(results), returnsNormally);
      expect(parseWatchPlaylist(results), isEmpty);
    });

    test('parseChartsItem handles nulls or unexpected categories safely', () {
      expect(parseChartsItem(null), equals({}));
      expect(parseChartsItem(ObfuscatedGPA()), equals({}));
      expect(parseChartsItem({'musicCarouselShelfRenderer': null}), equals({}));
    });
  });

  group('Continuations Resiliency', () {
    test('getContinuationContents handles non-Map or empty continuation object safely', () {
      expect(getContinuationContents(null, (x) => x), equals([]));
      expect(getContinuationContents(ObfuscatedGPA(), (x) => x), equals([]));
      expect(getContinuationContents('not a map', (x) => x), equals([]));
      expect(getContinuationContents({}, (x) => x), equals([]));
    });
  });

  group('SoundCloud Client ID & Network Resilience', () {
    test('SoundCloudService provides valid client ID with public fallback', () async {
      final service = SoundCloudService();
      final cid = await service.getClientId();
      expect(cid, isNotEmpty);
      expect(cid.length, greaterThanOrEqualTo(10));
    });
  });

  group('Playlist & Download Date Sorting and Persistence', () {
    test('sortSongsNVideos sorts by date correctly (ascending and descending)', () {
      const songOld = MediaItem(
        id: '1',
        title: 'Old Song',
        extras: {'date': 1000},
      );
      const songMid = MediaItem(
        id: '2',
        title: 'Mid Song',
        extras: {'date': 2000},
      );
      const songNew = MediaItem(
        id: '3',
        title: 'New Song',
        extras: {'date': 3000},
      );

      final list = [songMid, songOld, songNew];

      // Ascending: oldest first
      sortSongsNVideos(list, SortType.Date, true);
      expect(list.map((s) => s.id).toList(), equals(['1', '2', '3']));

      // Descending: newest first
      sortSongsNVideos(list, SortType.Date, false);
      expect(list.map((s) => s.id).toList(), equals(['3', '2', '1']));
    });

    test('sortSongsNVideos handles diverse timestamp formats (int, String, DateTime, missing)', () {
      const s1 = MediaItem(
        id: '1',
        title: 'String Date',
        extras: {'date': '1700000000000'},
      );
      const s2 = MediaItem(
        id: '2',
        title: 'Int Date',
        extras: {'date': 1710000000000},
      );
      const s3 = MediaItem(
        id: '3',
        title: 'Missing Date',
        extras: {},
      );

      final list = [s2, s3, s1];
      expect(() => sortSongsNVideos(list, SortType.Date, false), returnsNormally);
      expect(list.first.id, equals('2')); // newest
      expect(list.last.id, equals('3')); // timestamp 0 (missing)
    });

    test('MediaItemBuilder serialization preserves date and dateAdded', () {
      const item = MediaItem(
        id: 'test_song',
        title: 'Test Song',
        artist: 'Artist',
        extras: {
          'date': 1731500000000,
          'dateAdded': 1731500000000,
        },
      );

      final json = MediaItemBuilder.toJson(item);
      expect(json['date'], equals(1731500000000));
      expect(json['dateAdded'], equals(1731500000000));

      final restored = MediaItemBuilder.fromJson(json);
      expect(restored.extras?['date'], equals(1731500000000));
      expect(restored.extras?['dateAdded'], equals(1731500000000));
    });

    test('MediaItemBuilder generates timestamp if missing on toJson', () {
      const item = MediaItem(
        id: 'undated_song',
        title: 'Undated Song',
        artist: 'Artist',
      );

      final json = MediaItemBuilder.toJson(item);
      expect(json['date'], isA<int>());
      expect(json['date'], greaterThan(1700000000000));
    });
  });
}
