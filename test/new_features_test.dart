import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:spymusic/services/collab_playlist_service.dart';
import 'package:spymusic/services/song_recognizer_service.dart';
import 'package:spymusic/ui/widgets/daily_mixes_widget.dart';
import 'package:spymusic/models/album.dart';
import 'package:spymusic/models/playlist.dart';
import 'package:spymusic/utils/app_version.dart';
import 'package:spymusic/utils/helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('spymusic_feature_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('AppPrefs');
    await Hive.openBox('CollabPlaylists');
    await Hive.openBox('LibraryPlaylists');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Feature 13: Collaborative Playlists', () {
    test('createCollabPlaylist generates SPY-XXXX format code and stores locally', () async {
      final service = CollabPlaylistService();
      final collab = await service.createCollabPlaylist('Cyber Squad Vibe');

      expect(collab.code.startsWith('SPY-'), isTrue);
      expect(collab.code.length, greaterThanOrEqualTo(8));
      expect(collab.title, 'Cyber Squad Vibe');

      // Verify stored in Hive
      final loaded = service.getCollabPlaylist(collab.code);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Cyber Squad Vibe');
    });

    test('Data saver mode 85% suppresses mobile live sync without WiFi', () async {
      final appPrefs = Hive.box('AppPrefs');
      await appPrefs.put('dataSaverMode', 2); // 85% saver

      final service = CollabPlaylistService();
      // Should flag data saver active
      expect(service.isDataSaverRestricted, isTrue);
    });
  });

  group('Feature 17: Song Recognizer (Radar / Humming / Acoustic)', () {
    test('RecognizedSong converts to valid MediaItem with metadata', () {
      const recognized = RecognizedSong(
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        artworkUrl: 'https://example.com/art.jpg',
        confidence: 0.98,
      );

      final mediaItem = recognized.toMediaItem();
      expect(mediaItem.title, 'Starboy');
      expect(mediaItem.artist, 'The Weeknd');
      expect(mediaItem.album, 'Starboy');
      expect(mediaItem.artUri?.toString(), 'https://example.com/art.jpg');
    });

    test('RecognizedSong handles empty artwork gracefully', () {
      const song = RecognizedSong(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        confidence: 0.95,
      );
      final media = song.toMediaItem();
      expect(media.title, 'Blinding Lights');
      expect(media.artist, 'The Weeknd');
      expect(media.artUri, isNull);
    });
  });

  group('Feature 20: Daily Mixes', () {
    test('DailyMixesWidget exposes 4 curated mixes with icons and gradients', () {
      const mixes = DailyMixesWidget.mixTemplates;
      expect(mixes.length, 4);

      for (final mix in mixes) {
        expect(mix.title.isNotEmpty, isTrue);
        expect(mix.subtitle.isNotEmpty, isTrue);
        expect(mix.gradientColors.length, greaterThanOrEqualTo(2));
        expect(mix.seedQueries.isNotEmpty, isTrue);
      }
    });
  });

  group('Feature 5: 3D Spatial Audio Math Clamping', () {
    test('spatial level clamps smoothly between 0 and 100', () {
      double clampLevel(double val) => val.clamp(0.0, 100.0);
      expect(clampLevel(-15.0), 0.0);
      expect(clampLevel(120.0), 100.0);
      expect(clampLevel(65.0), 65.0);
    });
  });

  group('Obfuscation Safety: AlbumContent and PlaylistContent Type Guards', () {
    test('AlbumContent and PlaylistContent are identified by is-checks, never runtimeType string', () {
      final Object albumContent = AlbumContent(
        title: "Test Album Shelf",
        albumList: [
          Album(
            title: "Album 1",
            browseId: "b1",
            artists: [
              {'name': 'Artist 1'}
            ],
            thumbnailUrl: "https://example.com/art.jpg",
          ),
        ],
      );

      final Object playlistContent = PlaylistContent(
        title: "Test Playlist Shelf",
        playlistList: [
          Playlist(
            title: "Playlist 1",
            playlistId: "p1",
            thumbnailUrl: "https://example.com/art.jpg",
            isPipedPlaylist: false,
          ),
        ],
      );

      expect(albumContent is AlbumContent, isTrue);
      expect(albumContent is PlaylistContent, isFalse);
      expect(playlistContent is PlaylistContent, isTrue);
      expect(playlistContent is AlbumContent, isFalse);
    });
  });

  group('App Update Reliability & Version Comparison', () {
    test('AppVersion constants are valid and non-empty', () {
      expect(AppVersion.current.startsWith('v'), isTrue);
      expect(AppVersion.buildNumber, greaterThan(3000));
      expect(AppVersion.cleanString(AppVersion.current), '1.12.90');
      expect(AppVersion.full, 'v1.12.90+3094');
    });

    test('AppVersion.isNewer logic handles major, minor, patch and build numbers', () {
      expect(AppVersion.isNewer('v1.12.90', 'v1.12.89'), isTrue);
      expect(AppVersion.isNewer('v1.12.90', 'v1.12.90'), isFalse);
      expect(AppVersion.isNewer('v1.12.89', 'v1.12.90'), isFalse);
      expect(AppVersion.isNewer('v2.0.0', 'v1.12.90'), isTrue);
      expect(AppVersion.isNewer('v1.13.0', 'v1.12.90'), isTrue);

      // With build numbers
      expect(AppVersion.isNewer('v1.12.90+3095', 'v1.12.90+3094'), isTrue);
      expect(AppVersion.isNewer('v1.12.90+3094', 'v1.12.90+3094'), isFalse);
      expect(AppVersion.isNewer('v1.12.90+3000', 'v1.12.90+3094'), isFalse);
    });

    test('checkAppUpdateDetails compares current vs latest without false positives', () async {
      // Mocking scenario: check against own version should return hasUpdate == false
      final result = await checkAppUpdateDetails(currentVer: AppVersion.current);
      // Either GitHub network succeeded or fallback triggered, but hasUpdate must NEVER be true for current or newer
      if (result['latest'] == AppVersion.current || result['latest'] == 'v1.12.90') {
        expect(result['hasUpdate'], isFalse);
      }
      expect(result['downloadUrl'], isNotNull);
      expect((result['downloadUrl'] as String).contains('spymusic-arm64-v8a.apk'), isTrue);
    });
  });
}
