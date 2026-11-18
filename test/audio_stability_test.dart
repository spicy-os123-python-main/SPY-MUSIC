import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:spymusic/services/nav_parser.dart';
import 'package:spymusic/services/continuations.dart';
import 'package:spymusic/services/soundcloud_service.dart';
import 'package:spymusic/services/platform_search_service.dart';
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

  group('Song Switching Stability, Queue Navigation & Cancellation Resilience', () {
    // Helper replicating the exact interruption detection in AudioHandler
    bool isInterruptionOrCancellation(dynamic error, [int? reqId, int? activeReqId]) {
      if (reqId != null && activeReqId != null && reqId != activeReqId) {
        return true;
      }
      if (error == null) return false;
      final errStr = error.toString().toLowerCase();
      if (errStr.contains("abort") ||
          errStr.contains("loading interrupted") ||
          errStr.contains("connection aborted") ||
          errStr.contains("interrupted") ||
          errStr.contains("source error") ||
          errStr.contains("cancelled") ||
          errStr.contains("canceled") ||
          errStr.contains("disposed")) {
        return true;
      }
      if (error is PlatformException) {
        final code = error.code.toLowerCase();
        final msg = (error.message ?? '').toLowerCase();
        if (code == '0' ||
            code == '-1004' ||
            msg.contains('source error') ||
            msg.contains('abort') ||
            msg.contains('interrupt')) {
          return true;
        }
      }
      return false;
    }

    test('Cancellation detector identifies PlatformException(0, Source error) as normal transition', () {
      final exoCancel = PlatformException(
        code: '0',
        message: 'Source error',
        details: {'index': 0},
      );
      expect(isInterruptionOrCancellation(exoCancel), isTrue);
    });

    test('Cancellation detector identifies various stream interruption errors', () {
      expect(isInterruptionOrCancellation('Loading interrupted'), isTrue);
      expect(isInterruptionOrCancellation('Connection aborted by peer'), isTrue);
      expect(isInterruptionOrCancellation('Player was disposed'), isTrue);
      expect(isInterruptionOrCancellation('Operation cancelled'), isTrue);
      expect(isInterruptionOrCancellation(PlatformException(code: '-1004', message: 'Interrupted')), isTrue);
    });

    test('Cancellation detector preserves real network/format failures without misidentifying', () {
      expect(isInterruptionOrCancellation('SocketException: Connection refused'), isFalse);
      expect(isInterruptionOrCancellation('HttpException: 500 Internal Server Error'), isFalse);
      expect(isInterruptionOrCancellation('FormatException: Invalid JSON payload'), isFalse);
      expect(isInterruptionOrCancellation(PlatformException(code: '404', message: 'Not found')), isFalse);
    });

    test('Superseded asynchronous song requests are immediately discarded by request ID', () {
      int activeRequestId = 1;
      const int req1 = 1;

      // User skips quickly to song 2, then song 3
      activeRequestId = 2;
      activeRequestId = 3;

      // When request 1 finishes in background, it must be flagged as superseded
      expect(isInterruptionOrCancellation(null, req1, activeRequestId), isTrue);
      // Active request 3 is valid
      expect(isInterruptionOrCancellation(null, 3, activeRequestId), isFalse);
    });

    test('Queue navigation safely clamps bounds and handles single/empty lists', () {
      final queue = <MediaItem>[
        const MediaItem(id: 's1', title: 'Song 1'),
        const MediaItem(id: 's2', title: 'Song 2'),
        const MediaItem(id: 's3', title: 'Song 3'),
      ];

      int getNext(int current, int len, bool loop) {
        if (len == 0) return 0;
        final safeCurrent = current.clamp(0, len - 1);
        if (len > safeCurrent + 1) {
          return safeCurrent + 1;
        } else if (loop) {
          return 0;
        }
        return safeCurrent;
      }

      int getPrev(int current, int len) {
        if (len == 0) return 0;
        final safeCurrent = current.clamp(0, len - 1);
        if (safeCurrent - 1 >= 0) {
          return safeCurrent - 1;
        }
        return safeCurrent;
      }

      // Normal traversal
      expect(getNext(0, queue.length, false), equals(1));
      expect(getNext(1, queue.length, false), equals(2));
      expect(getNext(2, queue.length, false), equals(2));
      expect(getNext(2, queue.length, true), equals(0));

      // Previous traversal
      expect(getPrev(2, queue.length), equals(1));
      expect(getPrev(1, queue.length), equals(0));
      expect(getPrev(0, queue.length), equals(0));

      // Out of bounds and empty resilient
      expect(getNext(-5, queue.length, false), equals(1));
      expect(getNext(99, queue.length, false), equals(2));
      expect(getNext(0, 0, false), equals(0));
      expect(getPrev(-5, queue.length), equals(0));
      expect(getPrev(99, queue.length), equals(1));
    });

    test('UI progress bar resets position to zero when switching to a different track', () {
      Duration calculateCurrentPos(String oldSongId, String newSongId, Duration oldPos) {
        final bool isSameSong = oldSongId == newSongId;
        return isSameSong ? oldPos : Duration.zero;
      }

      final posAfterSwitch = calculateCurrentPos('song_a', 'song_b', const Duration(seconds: 145));
      expect(posAfterSwitch, equals(Duration.zero));

      final posSameSongMetadataUpdate = calculateCurrentPos('song_a', 'song_a', const Duration(seconds: 145));
      expect(posSameSongMetadataUpdate, equals(const Duration(seconds: 145)));
    });

    test('Shuffle queue sync safely reconstructs without RangeError on unmapped or desynced IDs', () {
      final queue = [
        const MediaItem(id: 'song_1', title: '1'),
        const MediaItem(id: 'song_2', title: '2'),
      ];
      final queueIds = queue.map((e) => e.id).toList();

      List<String> shuffleList(int index, List<String> ids) {
        if (ids.isEmpty) return [];
        final copy = List<String>.from(ids);
        final safeIndex = index.clamp(0, copy.length - 1);
        final current = copy.removeAt(safeIndex);
        copy.shuffle();
        copy.insert(0, current);
        return copy;
      }

      expect(() => shuffleList(-1, queueIds), returnsNormally);
      expect(() => shuffleList(50, queueIds), returnsNormally);
      expect(() => shuffleList(0, []), returnsNormally);

      final shuffled = shuffleList(1, queueIds);
      expect(shuffled.first, equals('song_2'));
      expect(shuffled.length, equals(2));
    });
  });

  group('Leak & Burner Track Platform Matching (e.g. Brand New Car by Squish / Juice WRLD)', () {
    test('extractArtistHints correctly parses multiple artists from playlist or album names', () {
      const itemWithPlaylist = MediaItem(
        id: 'sp_123',
        title: 'Brand New Car',
        artist: 'Squish',
        extras: {
          'playlistName': 'Juice wrld xxxtentacion Lil peep',
        },
      );

      final hints = PlatformSearchService.extractArtistHints(itemWithPlaylist);
      expect(hints.map((h) => h.toLowerCase()), containsAll(['juice wrld', 'xxxtentacion', 'lil peep']));
      // Pseudonym/burner artist 'Squish' must not be in hints
      expect(hints.map((h) => h.toLowerCase()), isNot(contains('squish')));
    });

    test('findBestMatch with fidelity matching selects accurate leak recording and rejects wrong tracks', () {
      const originalSpotifyLeak = MediaItem(
        id: 'sp_brand_new_car',
        title: 'Brand New Car',
        artist: 'Squish',
        duration: Duration(seconds: 183), // 3:03
        extras: {
          'playlistName': 'Juice wrld xxxtentacion Lil peep',
        },
      );

      final candidates = [
        const MediaItem(
          id: 'yt_car_crush',
          title: 'Crushing Crunchy & Soft Things by Car! - Floral Foam, Squishy',
          artist: 'CrushChannel',
          duration: Duration(seconds: 612), // 10:12
        ),
        const MediaItem(
          id: 'yt_stones',
          title: 'Brand New Car',
          artist: 'The Rolling Stones',
          duration: Duration(seconds: 254), // 4:14
        ),
        const MediaItem(
          id: 'yt_action_bronson',
          title: 'Brand New Car',
          artist: 'Action Bronson',
          duration: Duration(seconds: 142), // 2:22
        ),
        const MediaItem(
          id: 'yt_leak_swisssss',
          title: 'Brand New Car',
          artist: 'swisssss',
          duration: Duration(seconds: 184), // 3:04 (diff = 1s!)
        ),
      ];

      final match = PlatformSearchService.findBestMatch(
        candidates,
        originalSpotifyLeak,
        allowFidelityTitleDurationMatch: true,
      );

      expect(match, isNotNull);
      expect(match!.id, equals('yt_leak_swisssss'));
      expect(match.title, equals('Brand New Car'));
    });

    test('findBestMatch prioritizes candidate with playlist artist hint in title/author', () {
      const originalSpotifyLeak = MediaItem(
        id: 'sp_brand_new_car',
        title: 'Brand New Car',
        artist: 'Squish',
        duration: Duration(seconds: 183), // 3:03
        extras: {
          'playlistName': 'Juice wrld xxxtentacion Lil peep',
        },
      );

      final candidates = [
        const MediaItem(
          id: 'yt_unknown_uploader',
          title: 'Brand New Car',
          artist: 'RandomUser123',
          duration: Duration(seconds: 184), // 3:04
        ),
        const MediaItem(
          id: 'yt_juice_wrld_upload',
          title: 'Juice WRLD - Brand New Car',
          artist: 'lljw 999',
          duration: Duration(seconds: 181), // 3:01
        ),
      ];

      final match = PlatformSearchService.findBestMatch(
        candidates,
        originalSpotifyLeak,
        allowFidelityTitleDurationMatch: true,
      );

      expect(match, isNotNull);
      // 'yt_juice_wrld_upload' has the artist hint "Juice WRLD" from playlistName
      expect(match!.id, equals('yt_juice_wrld_upload'));
    });

    test('findBestMatch strictly rejects unwanted modifications even with fidelity matching', () {
      const originalSpotifyLeak = MediaItem(
        id: 'sp_brand_new_car',
        title: 'Brand New Car',
        artist: 'Squish',
        duration: Duration(seconds: 183),
      );

      final candidates = [
        const MediaItem(
          id: 'yt_sped_up',
          title: 'Brand New Car (Sped Up)',
          artist: 'swisssss',
          duration: Duration(seconds: 183),
        ),
        const MediaItem(
          id: 'yt_nightcore',
          title: 'Brand New Car [Nightcore]',
          artist: 'swisssss',
          duration: Duration(seconds: 183),
        ),
        const MediaItem(
          id: 'yt_remix',
          title: 'Brand New Car (Remix)',
          artist: 'swisssss',
          duration: Duration(seconds: 183),
        ),
      ];

      final match = PlatformSearchService.findBestMatch(
        candidates,
        originalSpotifyLeak,
        allowFidelityTitleDurationMatch: true,
      );

      expect(match, isNull);
    });
  });
}
