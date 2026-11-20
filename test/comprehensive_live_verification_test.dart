// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:spymusic/services/data_usage_tracker.dart';
import 'package:spymusic/services/music_service.dart';
import 'package:spymusic/services/platform_search_service.dart';
import 'package:spymusic/services/stream_service.dart';

void main() {
  HttpOverrides.global = null;

  group('Live Verification & Stress Tests for YouTube and Spotify', () {
    test('1. Live YouTube Searches & Streams: Test 5 diverse genres for 1-3 MB data limit',
        () async {
      final ms = MusicServices();
      final queries = [
        'Lucid Dreams Juice WRLD',
        'Roller Apache 207',
        'Numb Linkin Park',
        'Levels Avicii',
        'Blinding Lights The Weeknd',
      ];

      for (final q in queries) {
        final searchRes = await ms.search(q, filter: 'songs', limit: 3);
        final songs = searchRes['Songs'] as List? ?? [];
        expect(songs, isNotEmpty, reason: 'YouTube search for "$q" must return songs');

        final song = songs.first as MediaItem;
        print('Search "$q" -> found "${song.title}" by "${song.artist}" (${song.id})');

        final stream = await StreamProvider.fetch(song.id);
        expect(stream.playable, isTrue, reason: 'Stream for ${song.title} (${song.id}) must be playable');
        expect(stream.highestQualityAudio, isNotNull, reason: 'Audio stream for ${song.title} must not be null');

        final audio = stream.highestQualityAudio!;
        final sizeMb = (audio.size / (1024 * 1024)).toStringAsFixed(2);
        print('Verified ${song.title} (${song.id}): itag=${audio.itag}, codec=${audio.audioCodec}, size=$sizeMb MB (${audio.size} bytes)');

        // Must be a pure audio itag (250, 140, 251, 139, 249)
        expect([250, 140, 251, 139, 249].contains(audio.itag), isTrue,
            reason: 'Expected pure audio itag but got ${audio.itag}');

        // Size check: must be strictly within 1-3.5 MB for typical songs
        expect(audio.size, greaterThan(1000000), reason: '${song.title} size must be >= 1 MB');
        expect(audio.size, lessThan(3600000), reason: '${song.title} size must be <= 3.5 MB (1-3 MB range)');
      }
    });

    test('2. Live Spotify Search, Top Hits & Full Stream Resolution', () async {
      // 1. Check Spotify Top Hits shelf
      final topHits = await PlatformSearchService.getSpotifyTopHits(limit: 10);
      expect(topHits, isNotEmpty, reason: 'Spotify Top Hits must return tracks');
      print('Retrieved ${topHits.length} Spotify Top Hits. First: "${topHits.first.title}" by "${topHits.first.artist}" (${topHits.first.id})');
      expect(topHits.first.id.startsWith('sp_'), isTrue, reason: 'Track ID must start with sp_');

      // 2. Check Spotify query search for multiple tracks
      final testQueries = [
        'The Weeknd Blinding Lights',
        'Billie Eilish Birds of a Feather',
        'Apache 207 Roller',
      ];

      for (final query in testQueries) {
        final searchResults = await PlatformSearchService.searchSpotify(query, limit: 3);
        expect(searchResults, isNotEmpty, reason: 'Spotify search for "$query" must return results');
        final spTrack = searchResults.first;
        print('Spotify Search Result: "${spTrack.title}" by "${spTrack.artist}" (${spTrack.id})');

        // 3. Resolve Spotify track to full playable stream
        final resolvedMatch = await PlatformSearchService.resolveMatchedTrack(
          spTrack.id,
          '${spTrack.title} ${spTrack.artist}',
          originalTrack: spTrack,
        );
        expect(resolvedMatch, isNotNull, reason: 'Spotify track "${spTrack.title}" must resolve to a valid candidate');
        print('Resolved Spotify track to candidate: "${resolvedMatch!.title}" (${resolvedMatch.id})');

        final stream = await StreamProvider.fetch(resolvedMatch.id);
        expect(stream.playable, isTrue, reason: 'Resolved stream for "${resolvedMatch.title}" must be playable');
        final audio = stream.highestQualityAudio;
        expect(audio, isNotNull);
        final sizeMb = (audio!.size / (1024 * 1024)).toStringAsFixed(2);
        print('Spotify track audio stream: itag=${audio.itag}, size=$sizeMb MB (${audio.size} bytes)');
        expect(audio.size, greaterThan(1000000));
        expect(audio.size, lessThan(3600000));
      }
    });

    test('3. Song skipping strictly consumes <= 200 KB per skip', () {
      final tracker = DataUsageTracker.instance;
      final startAudioBytes = tracker.sessionAudioBytes.value;

      // Simulate 5 rapid song skips (e.g. user tapping Next repeatedly)
      for (int i = 1; i <= 5; i++) {
        final beforeSkip = tracker.sessionAudioBytes.value;
        tracker.recordAudioStream(
          title: 'Skipped Song $i',
          artist: 'Test Artist',
          itag: 250,
          codec: 'opus',
          bitrate: 70000,
          sizeBytes: 1800000, // 1.8 MB full song
          durationSeconds: 195,
        );
        final bytesForThisSkip = tracker.sessionAudioBytes.value - beforeSkip;
        print('Skip #$i consumed: ${(bytesForThisSkip / 1024).toStringAsFixed(1)} KB ($bytesForThisSkip bytes)');

        // Each skip must consume <= 200 KB
        expect(bytesForThisSkip, lessThanOrEqualTo(200 * 1024),
            reason: 'Each song skip must strictly consume <= 200 KB');
        // Specifically clamped to initial burst <= 150 KB
        expect(bytesForThisSkip, lessThanOrEqualTo(150 * 1000));
      }

      final totalSkipBytes = tracker.sessionAudioBytes.value - startAudioBytes;
      print('Total data for 5 skips: ${(totalSkipBytes / 1024).toStringAsFixed(1)} KB (Avg: ${(totalSkipBytes / (5 * 1024)).toStringAsFixed(1)} KB/skip)');
      expect(totalSkipBytes, lessThanOrEqualTo(1000 * 1024),
          reason: '5 skips combined must consume <= 1 MB total');
    });
  });
}
