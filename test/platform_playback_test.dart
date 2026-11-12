import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/services/audio_handler.dart';
import 'package:spymusic/services/platform_search_service.dart';

void main() {
  group('Platform preview & full-track guardrails', () {
    test('isPreviewAudioUrl detects 30-second catalog previews', () {
      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://cdnt-preview.dzcdn.net/api/1/1/b/9/5/0/track.mp3',
        ),
        isTrue,
      );
      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/track.m4a',
        ),
        isTrue,
      );
      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://p.scdn.co/mp3-preview/abc123',
        ),
        isTrue,
      );
      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://api-v2.soundcloud.com/media/track/preview/hls',
        ),
        isTrue,
      );

      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://rr1---sn-4g5e6nze.googlevideo.com/videoplayback?itag=140&c=ANDROID',
        ),
        isFalse,
      );
      expect(
        PlatformSearchService.isPreviewAudioUrl(
          'https://playback.media-streaming.soundcloud.cloud/abc/aac_160k/playlist.m3u8',
        ),
        isFalse,
      );
      expect(PlatformSearchService.isPreviewAudioUrl(null), isFalse);
      expect(PlatformSearchService.isPreviewAudioUrl(''), isFalse);
    });

    test('findBestMatch rejects <=35s snippets and picks full studio track', () {
      const original = MediaItem(
        id: 'sp_12345',
        title: 'Pfefferkörner',
        artist: '2LADE',
        duration: Duration(seconds: 144),
      );

      const snippet = MediaItem(
        id: 'yt_snip',
        title: 'Pfefferkörner',
        artist: '2LADE - Topic',
        duration: Duration(seconds: 30),
      );
      const slowedRemix = MediaItem(
        id: 'yt_slowed',
        title: 'Pfefferkörner (Slowed + Reverb)',
        artist: '2LADE',
        duration: Duration(seconds: 165),
      );
      const studioMaster = MediaItem(
        id: 'BkzvGcSXCUE',
        title: 'Pfefferkörner',
        artist: '2LADE - Topic',
        duration: Duration(seconds: 144),
      );

      final match = PlatformSearchService.findBestMatch(
        [snippet, slowedRemix, studioMaster],
        original,
      );

      expect(match?.id, 'BkzvGcSXCUE');
    });

    test('findBestMatch ignores placeholder 180s duration when durationEstimated is true', () {
      const amazonRssTrack = MediaItem(
        id: 'az_999',
        title: 'Boxen Laut',
        artist: '2LADE',
        duration: Duration(seconds: 180),
        extras: {'durationEstimated': true},
      );

      const actualShortTrack = MediaItem(
        id: 'yt_boxen',
        title: 'Boxen Laut',
        artist: '2LADE - Topic',
        duration: Duration(seconds: 117),
      );

      final match = PlatformSearchService.findBestMatch(
        [actualShortTrack],
        amazonRssTrack,
        strictSpeedCheck: true,
      );

      expect(match?.id, 'yt_boxen');
    });
  });

  group('Audio source routing & stream headers across platforms', () {
    test('Spotify and Amazon tracks resolved to googlevideo preserve YouTube headers', () {
      const spotifyItem = MediaItem(
        id: 'sp_track_1',
        title: 'Pfefferkörner',
        artist: '2LADE',
        extras: {'isSpotify': true, 'platform': 'Spotify'},
      );
      const amazonItem = MediaItem(
        id: 'az_track_2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        extras: {'isAmazon': true, 'platform': 'Amazon'},
      );

      const androidYtUrl =
          'https://rr2---sn-4g5ednsd.googlevideo.com/videoplayback?itag=140&c=ANDROID';
      const iosYtUrl =
          'https://rr2---sn-4g5ednsd.googlevideo.com/videoplayback?itag=140&c=IOS';

      expect(
        MyAudioHandler.isDirectHlsOrSoundCloudStream(androidYtUrl, spotifyItem),
        isFalse,
      );
      expect(
        MyAudioHandler.isDirectHlsOrSoundCloudStream(iosYtUrl, amazonItem),
        isFalse,
      );

      final androidHeaders = MyAudioHandler.buildStreamHeaders(androidYtUrl);
      expect(androidHeaders?['User-Agent'], contains('com.google.android.youtube'));

      final iosHeaders = MyAudioHandler.buildStreamHeaders(iosYtUrl);
      expect(iosHeaders?['User-Agent'], contains('com.google.ios.youtube'));
    });

    test('SoundCloud and HLS fallback streams route as direct HLS/SoundCloud sources', () {
      const soundCloudItem = MediaItem(
        id: 'sc_98765',
        title: 'Track',
        artist: 'Artist',
        extras: {'isSoundCloud': true},
      );
      const spotifyScFallback = MediaItem(
        id: 'sp_555',
        title: 'Indie Song',
        artist: 'Indie Artist',
        extras: {'isSpotify': true},
      );
      const scHlsUrl =
          'https://playback.media-streaming.soundcloud.cloud/xyz/aac_160k/playlist.m3u8';

      expect(
        MyAudioHandler.isDirectHlsOrSoundCloudStream(scHlsUrl, soundCloudItem),
        isTrue,
      );
      expect(
        MyAudioHandler.isDirectHlsOrSoundCloudStream(scHlsUrl, spotifyScFallback),
        isTrue,
      );
      expect(MyAudioHandler.buildStreamHeaders(scHlsUrl), isNull);
    });
  });
}

