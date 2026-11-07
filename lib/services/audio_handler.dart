import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

import 'soundcloud_service.dart';
import 'platform_search_service.dart';
import 'watchtime_service.dart';
import 'data_usage_tracker.dart';
import '/models/album.dart';
import '../models/playlist.dart';
import '/services/equalizer.dart';
import '/services/stream_service.dart';
import '/models/hm_streaming_data.dart';
import '/ui/player/player_controller.dart';
import '../ui/screens/Home/home_screen_controller.dart';
import '/services/background_task.dart';
import '../utils/helper.dart';
import '/models/media_Item_builder.dart';
import '/services/utils.dart';
import '/services/discord_service.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/screens/Library/library_controller.dart';
// ignore: unused_import, implementation_imports, depend_on_referenced_packages
import "package:media_kit/src/player/platform_player.dart" show MPVLogLevel;

Future<AudioHandler> initAudioService() async {
  try {
    return await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationIcon: 'mipmap/ic_launcher_monochrome',
        androidNotificationChannelId: 'com.spymusic.app.audio',
        androidNotificationChannelName: 'SPY MUSIC Player',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ).timeout(const Duration(seconds: 4));
  } catch (e) {
    printERROR("AudioService.init timeout or error: $e");
    return MyAudioHandler();
  }
}

class MyAudioHandler extends BaseAudioHandler with GetxServiceMixin {
  // ignore: prefer_typing_uninitialized_variables
  late final _cacheDir;
  late AudioPlayer _player;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  late MediaLibrary _mediaLibrary;
  // ignore: prefer_typing_uninitialized_variables
  dynamic currentIndex;
  int currentShuffleIndex = 0;
  String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;
  // var networkErrorPause = false;

  bool get _isGerman {
    try {
      if (Get.isRegistered<SettingsScreenController>()) {
        final settings = Get.find<SettingsScreenController>();
        if (settings.currentAppLanguageCode.value == 'de') return true;
        if (settings.currentAppLanguageCode.value != 'de') return false;
      }
    } catch (_) {}
    return (Get.locale?.languageCode ?? 'en') == 'de';
  }
  bool isSongLoading = true;
  int _songErrorRetryCount = 0;
  String? _lastFailedSongId;
  bool _pausedByDeviceDisconnect = false;
  bool _wasPlayingBeforeInterruption = false;

  // Tracking for verified "from beginning to end" song completion
  int _currentSongPlayedSeconds = 0;
  bool _currentSongCompletedRecorded = false;
  String? _lastTrackedSongId;
  int _activePlayRequestId = 0;
  bool _isTriggeringNext = false;
  DateTime? _lastStreamErrorTime;

  // list of shuffled queue songs ids
  List<String> shuffledQueue = [];

  MyAudioHandler() {
    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      JustAudioMediaKit.title = 'SPY MUSIC';
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
    }
    _mediaLibrary = MediaLibrary();
    _player = AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: true,
        handleAudioSessionActivation: false,
        useProxyForRequestHeaders: false,
        audioLoadConfiguration: const AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 8),
          maxBufferDuration: Duration(seconds: 20),
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1000),
          prioritizeTimeOverSizeThresholds: true,
          backBufferDuration: Duration(seconds: 10),
        )));
    if (GetPlatform.isAndroid || GetPlatform.isIOS) {
      _initAudioSession();
    }
    mediaItem.listen((item) {
      if (item != null) {
        if (_lastTrackedSongId != item.id) {
          _lastTrackedSongId = item.id;
          _currentSongPlayedSeconds = 0;
          _currentSongCompletedRecorded = false;
          WatchtimeService.recordSongStart(item);
        }
        DiscordService().updatePresence(
          item,
          isPlaying: _player.playing,
          position: _player.position,
        );
      }
    });
    _player.playerStateStream.listen((playerState) {
      if (mediaItem.value != null) {
        // Only update Discord on state changes when ready or completed, avoiding spam during loading/buffering
        if (playerState.processingState == ProcessingState.ready ||
            playerState.processingState == ProcessingState.completed) {
          DiscordService().updatePresence(
            mediaItem.value,
            isPlaying: playerState.playing,
            position: _player.position,
          );
        }
      }
    });
    _createCacheDir();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackForNextSong();
    _listenForSequenceStateChanges();
    final appPrefsBox = Hive.box("AppPrefs");
    _player
        .setSkipSilenceEnabled(appPrefsBox.get("skipSilenceEnabled") ?? false);
    loopModeEnabled = appPrefsBox.get("isLoopModeEnabled") ?? false;
    shuffleModeEnabled = appPrefsBox.get("isShuffleModeEnabled") ?? false;
    queueLoopModeEnabled =
        Hive.box("AppPrefs").get("queueLoopModeEnabled") ?? false;
    loudnessNormalizationEnabled =
        appPrefsBox.get("loudnessNormalizationEnabled") ?? false;
    _listenForDurationChanges();
    if (GetPlatform.isAndroid) {
      _listenSessionIdStream();
      _initEqualizerFromPrefs();
    }
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_player.playing &&
          mediaItem.value != null &&
          _player.processingState == ProcessingState.ready) {
        WatchtimeService.recordPlaytime(mediaItem.value!, seconds: 5);
        _currentSongPlayedSeconds += 5;
        _checkAndRecordSongCompletion();
      }
    });
  }

  Future<void> _initEqualizerFromPrefs() async {
    try {
      final appPrefsBox = Hive.box("AppPrefs");
      await appPrefsBox.put("eq_enabled", false);
      await appPrefsBox.put("eq_loudness_enabled", false);
      await appPrefsBox.put("eq_loudness_gain", 0.0);
      await appPrefsBox.put("eq_band_gains", {});
      await appPrefsBox.put("eq_preset", "Normal");
      await appPrefsBox.put("custom_bass_boost", 0.0);
      await appPrefsBox.put("bummm_boost_gain", 0.0);
    } catch (e) {
      printERROR("Error resetting equalizer prefs: $e");
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.interruptionEventStream.listen((event) async {
        final playDuringCalls = Hive.box("AppPrefs")
            .get("playDuringCalls", defaultValue: true) as bool;
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (!playDuringCalls && _player.playing) {
                await _player.setVolume(0.3);
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // If SPY MUSIC is not playing, NEVER steal or touch audio focus!
              if (!_player.playing) {
                _wasPlayingBeforeInterruption = false;
                try {
                  await session.setActive(false);
                } catch (_) {}
                return;
              }

              // SPY MUSIC was actively playing: pause cleanly and yield audio focus
              _wasPlayingBeforeInterruption = true;
              await _player.pause();
              try {
                await session.setActive(false);
              } catch (_) {}
              break;
          }
        } else {
          // Interruption ended (call ended, WhatsApp voice message finished, etc.):
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (_player.playing) {
                await _player.setVolume(1.0);
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Only auto-resume if WE WERE ACTIVELY PLAYING before the interruption
              if (_wasPlayingBeforeInterruption &&
                  !_pausedByDeviceDisconnect &&
                  !_player.playing) {
                try {
                  final active = await session.setActive(true);
                  if (active) {
                    await _player.setVolume(1.0);
                    await _player.play();
                  }
                } catch (_) {}
              }
              _wasPlayingBeforeInterruption = false;
              break;
          }
        }
      });

      // Becoming Noisy: Triggered immediately when Bluetooth device or headphones disconnect!
      session.becomingNoisyEventStream.listen((_) async {
        printINFO(
            "Audio becoming noisy (Bluetooth / headphones disconnected). Pausing playback!");
        _pausedByDeviceDisconnect = true;
        _wasPlayingBeforeInterruption = false;
        if (_player.playing) {
          await _player.pause();
          try {
            await session.setActive(false);
          } catch (_) {}
        }
      });

      // Audio Device Disconnection (Bluetooth / Headset removed)
      session.devicesChangedEventStream.listen((event) async {
        final hadDeviceRemoved = event.devicesRemoved.any((d) =>
            d.type == AudioDeviceType.bluetoothA2dp ||
            d.type == AudioDeviceType.bluetoothSco ||
            d.type == AudioDeviceType.bluetoothLe ||
            d.type == AudioDeviceType.wiredHeadset ||
            d.type == AudioDeviceType.wiredHeadphones ||
            d.type == AudioDeviceType.usbAudio ||
            d.type == AudioDeviceType.hearingAid ||
            d.type == AudioDeviceType.lineAnalog ||
            d.type == AudioDeviceType.lineDigital);
        if (hadDeviceRemoved) {
          printINFO(
              "Audio device removed (${event.devicesRemoved}). Pausing playback!");
          _pausedByDeviceDisconnect = true;
          _wasPlayingBeforeInterruption = false;
          if (_player.playing) {
            await _player.pause();
            try {
              await session.setActive(false);
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      printINFO("AudioSession config error: $e");
    }
  }

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    final cDir = Directory("$_cacheDir/cachedSongs/");
    if (!cDir.existsSync()) {
      cDir.createSync(recursive: true);
    } else {
      // Clean up any corrupt partial downloads from prior broken cache attempts
      try {
        final files = cDir.listSync();
        for (final f in files) {
          if (f is File) {
            if (f.path.endsWith('.part') ||
                (f.path.endsWith('.mp3') && f.lengthSync() < 800 * 1024)) {
              printINFO("Cleaning corrupt/partial cache file: ${f.path}");
              try {
                f.deleteSync();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }
  }

  void _listenSessionIdStream() {
    _player.androidAudioSessionIdStream.listen((int? id) {
      if (id != null) {
        try {
          EqualizerService.initAudioEffect(id);
        } catch (e) {
          printERROR("initAudioEffect error: $e");
        }
      }
    });
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      if (_player.processingState == ProcessingState.completed) {
        _checkAndRecordSongCompletion();
      }
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isSongLoading
            ? AudioProcessingState.loading
            : const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[_player.processingState]!,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
        shuffleMode: (shuffleModeEnabled)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIndex,
      ));

      //print("set ${playbackState.value.queueIndex},${event.currentIndex}");
    }, onError: (Object e, StackTrace st) async {
      printERROR("playbackEventStream error: $e");
      final errStr = e.toString().toLowerCase();

      // Normal cancellations when switching tracks or replacing media sources: ignore completely!
      if (errStr.contains("abort") ||
          errStr.contains("loading interrupted") ||
          errStr.contains("connection aborted")) {
        return;
      }

      // If a song is actively being loaded in playByIndex or setSourceNPlay,
      // let its own try/catch handle it! Do NOT launch a competing retry!
      if (isSongLoading) {
        return;
      }

      // Debounce duplicate error events dispatched by ExoPlayer in the same second
      final now = DateTime.now();
      if (_lastStreamErrorTime != null &&
          now.difference(_lastStreamErrorTime!) < const Duration(milliseconds: 1500)) {
        return;
      }
      _lastStreamErrorTime = now;

      final currentId = mediaItem.value?.id ??
          (currentIndex != null && queue.value.isNotEmpty
              ? queue.value[currentIndex!].id
              : null);

      if (currentId != null) {
        try {
          Hive.box("SongsUrlCache").delete(currentId);
        } catch (_) {}
        if (currentId.startsWith("sp_") || currentId.startsWith("az_")) {
          PlatformSearchService.invalidateMatch(currentId);
        }
      }

      if (_lastFailedSongId != currentId) {
        _lastFailedSongId = currentId;
        _songErrorRetryCount = 0;
      }

      if (_songErrorRetryCount < 2) {
        _songErrorRetryCount++;
        printINFO(
            "Retrying playback for $currentId (attempt $_songErrorRetryCount of 2)...");
        customAction(
            "playByIndex", {'index': currentIndex ?? 0, 'newUrl': true});
      } else {
        printERROR(
            "Playback failed after $_songErrorRetryCount retries for $currentId: $e");
        _songErrorRetryCount = 0;
        isSongLoading = false;
        await _player.stop();
        final errText =
            e is PlayerException ? (e.message ?? e.toString()) : e.toString();
        try {
          Get.find<PlayerController>().notifyPlayError(errText);
        } catch (_) {}
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorCode: 500,
          errorMessage: errText,
        ));
      }
    });
  }

  String? _lastPreloadedSongId;

  void _preloadNextSongStream() {
    if (queue.value.isEmpty) return;
    final dataSaver =
        Hive.box('AppPrefs').get('dataSaverMode', defaultValue: 0);
    final streamingQuality =
        Hive.box('AppPrefs').get('streamingQuality', defaultValue: 0);
    if ((dataSaver is int && dataSaver > 0) ||
        (streamingQuality is int && streamingQuality > 0)) {
      // In Data Saver Mode (Mid or Ultra), do NOT preload next song in background to save mobile data!
      return;
    }
    final currIndex = playbackState.value.queueIndex ?? 0;
    final nextIndex = currIndex + 1;
    if (nextIndex >= queue.value.length) return;

    final nextSong = queue.value[nextIndex];
    if (nextSong.id == _lastPreloadedSongId) return;
    _lastPreloadedSongId = nextSong.id;

    if (Hive.box("SongsUrlCache").containsKey(nextSong.id) ||
        Hive.box("SongDownloads").containsKey(nextSong.id) ||
        Hive.box("SongsCache").containsKey(nextSong.id)) {
      return;
    }

    printINFO(
        "Background preloading next song stream for poor network resilience: ${nextSong.title} (${nextSong.id})");
    checkNGetUrl(nextSong.id, targetMediaItem: nextSong).catchError((e) {
      printINFO("Background preload encountered: $e");
      return HMStreamingData(playable: false, statusMSG: "");
    });
  }

  bool _currentSongCachedToDisk = false;

  void _saveCurrentSongToDiskIfEnabled() {
    final currentSong = mediaItem.value;
    if (currentSong == null) return;
    final url = (currentSong.extras?['url'] ?? '') as String;
    if (url.isEmpty || !url.startsWith('http')) return;

    bool isCacheEnabled = false;
    try {
      if (Get.isRegistered<SettingsScreenController>()) {
        isCacheEnabled = Get.find<SettingsScreenController>().cacheSongs.isTrue;
      } else {
        isCacheEnabled =
            Hive.box("AppPrefs").get('cacheSongs', defaultValue: false) == true;
      }
    } catch (_) {}

    if (!isCacheEnabled) return;

    final songId = currentSong.id;
    final cacheFile = File("$_cacheDir/cachedSongs/$songId.mp3");
    if (cacheFile.existsSync() && cacheFile.lengthSync() >= 250 * 1024) return;

    _downloadSongToCache(songId, url, currentSong);
  }

  void _downloadSongToCache(String songId, String url, MediaItem song) async {
    try {
      final cacheDir = Directory("$_cacheDir/cachedSongs");
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      final tempFile = File("$_cacheDir/cachedSongs/${songId}_temp.mp3");
      final targetFile = File("$_cacheDir/cachedSongs/$songId.mp3");

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final req = await client.getUrl(Uri.parse(url));
      if (url.contains('c=ANDROID')) {
        req.headers.set('User-Agent',
            'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
      } else if (url.contains('c=IOS')) {
        req.headers.set('User-Agent',
            'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)');
      }
      final resp = await req.close();
      if (resp.statusCode == 200 || resp.statusCode == 206) {
        final sink = tempFile.openWrite();
        await resp.pipe(sink);
        await sink.close();

        if (tempFile.existsSync() && tempFile.lengthSync() >= 250 * 1024) {
          if (targetFile.existsSync()) targetFile.deleteSync();
          tempFile.renameSync(targetFile.path);
          printINFO(
              "Successfully cached 1-2MB pure audio song after 10s listening: $songId (${(targetFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)");
          final box = await Hive.openBox("SongsCache");
          box.put(songId, {
            "streamInfo": [
              null,
              {
                "url": "file://${targetFile.path}",
                "audioCodec": "mp4a",
                "itag": 140,
                "size": targetFile.lengthSync(),
                "bitrate": 0,
                "duration": song.duration?.inMilliseconds ?? 0,
                "loudnessDb": 0.0,
              }
            ]
          });
        } else if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } else {
        await resp.drain();
      }
      client.close();
    } catch (e) {
      printINFO("Background cache download encountered: $e");
    }
  }

  void _listenToPlaybackForNextSong() {
    final playerDurationOffset = GetPlatform.isWindows
        ? 200
        : GetPlatform.isLinux
            ? 700
            : 0;
    _player.positionStream.listen((value) async {
      if (_player.duration != null && _player.duration?.inSeconds != 0) {
        final totalMs = _player.duration!.inMilliseconds;
        final currentMs = value.inMilliseconds;

        // User requirement: Only cache/preload song after at least 10 seconds of verified listening
        if (currentMs >= 10000 && !_currentSongCachedToDisk) {
          _currentSongCachedToDisk = true;
          _saveCurrentSongToDiskIfEnabled();
        }

        // Preload next track's stream 25 seconds before the current song ends for seamless playback
        if (totalMs > 30000 &&
            (totalMs - currentMs) <= 25000 &&
            (totalMs - currentMs) > 23000) {
          _preloadNextSongStream();
        }

        if (currentMs >= (totalMs - playerDurationOffset)) {
          _checkAndRecordSongCompletion();
          await _triggerNext();
        }
      }
    });
  }

  void _checkAndRecordSongCompletion() {
    final currentSong = mediaItem.value;
    if (currentSong == null) return;
    if (_currentSongCompletedRecorded) return;

    final durationSec =
        currentSong.duration?.inSeconds ?? _player.duration?.inSeconds ?? 0;
    final currentPosSec = _player.position.inSeconds;

    // 1. Must have reached the end of the song:
    // Either player processingState is completed, OR current position reached at least 88% of duration
    final bool reachedEnd =
        (_player.processingState == ProcessingState.completed) ||
            (durationSec > 0 && currentPosSec >= (durationSec * 0.88)) ||
            (durationSec > 0 && (durationSec - currentPosSec) <= 4);

    // 2. Must have actually listened to the song from beginning to end:
    // Requires that user spent at least 50% of the song duration listening (or at least 25 seconds)
    final int minRequiredListeningSec =
        durationSec > 0 ? min(25, (durationSec * 0.50).round()) : 20;
    final bool actuallyListened =
        _currentSongPlayedSeconds >= minRequiredListeningSec;

    if (reachedEnd && actuallyListened) {
      _currentSongCompletedRecorded = true;
      WatchtimeService.recordSongCompleted(currentSong);
    }
  }

  Future<void> _triggerNext() async {
    if (_isTriggeringNext) return;
    _isTriggeringNext = true;
    try {
      _checkAndRecordSongCompletion();
      WatchtimeService.flushBufferedPlaytime();
      if (loopModeEnabled) {
        _currentSongCompletedRecorded = false;
        _currentSongPlayedSeconds = 0;
        await _player.seek(Duration.zero);
        if (!_player.playing) {
          try {
            final session = await AudioSession.instance;
            await session.setActive(true);
          } catch (_) {}
          await _player.play();
        }
        return;
      }
      await skipToNext();
    } catch (e) {
      printERROR("Error in _triggerNext: $e");
    } finally {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _isTriggeringNext = false;
      });
    }
  }

  void _listenForSequenceStateChanges() {
    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) async {
      final currQueue = queue.value;
      if (currentIndex == null ||
          currQueue.isEmpty ||
          duration == null ||
          duration == Duration.zero ||
          duration.inSeconds == 0) return;
      final currentSong = queue.value[currentIndex];
      // Only set duration from player if metadata did not already have a valid non-zero duration
      if (currentSong.duration == null ||
          currentSong.duration == Duration.zero ||
          currentSong.duration!.inSeconds == 0) {
        final newMediaItem = currentSong.copyWith(duration: duration);
        queue.value[currentIndex] = newMediaItem;
        mediaItem.add(newMediaItem);
      }
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    // notify system
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);

    if (shuffleModeEnabled) {
      final mediaItemsIds = mediaItems.toList().map((item) => item.id).toList();
      final notPlayedshuffledQueue = shuffledQueue.isNotEmpty
          ? shuffledQueue.toList().sublist(currentShuffleIndex + 1)
          : shuffledQueue;
      notPlayedshuffledQueue.addAll(mediaItemsIds);
      notPlayedshuffledQueue.shuffle();
      shuffledQueue.replaceRange(
          currentShuffleIndex, shuffledQueue.length, notPlayedshuffledQueue);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final newQueue = this.queue.value
      ..replaceRange(0, this.queue.value.length, queue);
    this.queue.add(newQueue);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    if (shuffleModeEnabled) {
      shuffledQueue.add(mediaItem.id);
    }

    // notify system
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  AudioSource _createAudioSource(MediaItem mediaItem) {
    // 0. ABSOLUTE PRIORITY: Check SongDownloads FIRST!
    // If this song is downloaded, ALWAYS play the local file (0 KB mobile data!),
    // even if mediaItem.extras?['url'] contains a remote stream URL!
    if (Hive.box("SongDownloads").containsKey(mediaItem.id)) {
      final songJson = Hive.box("SongDownloads").get(mediaItem.id);
      final dlPath = (songJson is Map ? (songJson['url'] ?? '') : '')
          .toString()
          .replaceFirst('file://', '');
      if (dlPath.isNotEmpty) {
        final dlFile = File(dlPath);
        if (dlFile.existsSync() && dlFile.lengthSync() > 1024) {
          printINFO(
              "Playing offline downloaded file from SongDownloads (0 mobile data): $dlPath");
          isPlayingUsingLockCachingSource = false;
          return AudioSource.file(
            dlPath,
            tag: mediaItem,
          );
        }
      }
    }

    String url = (mediaItem.extras?['url'] ?? '') as String;
    final isLocalFile =
        !url.startsWith('http://') && !url.startsWith('https://');
    if (isLocalFile && url.isNotEmpty) {
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync() && file.lengthSync() > 1024) {
        printINFO("Playing offline local file: $cleanPath");
        isPlayingUsingLockCachingSource = false;
        return AudioSource.file(
          cleanPath,
          tag: mediaItem,
        );
      }
    }

    // Direct HLS stream for SoundCloud or any HLS source (.m3u8 or /stream/hls)
    if (url.contains('.m3u8') ||
        url.contains('/stream/hls') ||
        url.contains('/hls')) {
      printINFO(
          "Playing HLS stream via HlsAudioSource: ${url.substring(0, min(80, url.length))}...");
      isPlayingUsingLockCachingSource = false;
      return HlsAudioSource(
        Uri.parse(url),
        tag: mediaItem,
      );
    }

    // Direct AudioSource.uri for SoundCloud progressive or other non-YouTube streams
    if (url.contains('soundcloud') ||
        url.contains('sndcdn') ||
        mediaItem.id.startsWith("sc_") ||
        (mediaItem.extras?['isSoundCloud'] == true)) {
      printINFO(
          "Playing direct stream via AudioSource.uri: ${url.substring(0, min(80, url.length))}...");
      isPlayingUsingLockCachingSource = false;
      return AudioSource.uri(
        Uri.parse(url),
        tag: mediaItem,
      );
    }

    final cacheFile = File("$_cacheDir/cachedSongs/${mediaItem.id}.mp3");

    // 1. Check if the song is already cached on disk (0 KB network usage!)
    if (cacheFile.existsSync() && cacheFile.lengthSync() >= 250 * 1024) {
      printINFO(
          "Playing offline cached song from disk (0 network data!): ${cacheFile.path}");
      isPlayingUsingLockCachingSource = false;
      return AudioSource.file(
        cacheFile.path,
        tag: mediaItem,
      );
    }

    // 2. Direct on-demand streaming (does NOT buffer the whole song upfront!)
    printINFO("Playing stream via AudioSource.uri: ${url.substring(0, min(80, url.length))}...");
    isPlayingUsingLockCachingSource = false;
    final uri =
        isLocalFile ? Uri.file(url) : (Uri.tryParse(url) ?? Uri.parse(url));
    return AudioSource.uri(
      uri,
      tag: mediaItem,
      headers: url.contains('googlevideo.com')
          ? {
              'User-Agent':
                  'com.google.android.youtube/19.09.37 (Linux; U; Android 11; US)',
            }
          : null,
    );
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<void> removeQueueItem(MediaItem mediaItem_) async {
    if (shuffleModeEnabled) {
      final id = mediaItem_.id;
      final itemIndex = shuffledQueue.indexOf(id);
      if (currentShuffleIndex > itemIndex) {
        currentShuffleIndex -= 1;
      }
      shuffledQueue.remove(id);
    }

    final currentQueue = queue.value;
    final currentSong = mediaItem.value;
    final itemIndex = currentQueue.indexOf(mediaItem_);
    if (currentIndex > itemIndex) {
      currentIndex -= 1;
    }
    currentQueue.remove(mediaItem_);
    queue.add(currentQueue);
    mediaItem.add(currentSong);
  }

  @override
  Future<void> play() async {
    _pausedByDeviceDisconnect = false;
    _wasPlayingBeforeInterruption = false;
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (!loudnessNormalizationEnabled && _player.volume < 1.0) {
      await _player.setVolume(1.0);
    }
    if (currentSongUrl == null ||
        (GetPlatform.isDesktop &&
            (_player.duration == null ||
                _player.duration?.inMilliseconds == 0))) {
      await customAction("playByIndex", {'index': currentIndex});
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _wasPlayingBeforeInterruption = false;
    WatchtimeService.flushBufferedPlaytime();
    await _player.pause();
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) {
    if (mediaItem.value != null) {
      DiscordService().updatePresence(
        mediaItem.value,
        isPlaying: _player.playing,
        position: position,
      );
    }
    return _player.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await customAction("playByIndex", {'index': index});
  }

  int _getNextSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex + 1 >= shuffledQueue.length) {
        shuffledQueue.shuffle();
        currentShuffleIndex = 0;
      } else {
        currentShuffleIndex += 1;
      }
      return queue.value
          .indexWhere((item) => item.id == shuffledQueue[currentShuffleIndex]);
    }

    if (queue.value.length > currentIndex + 1) {
      return currentIndex + 1;
    } else if (queueLoopModeEnabled) {
      return 0;
    } else {
      return currentIndex;
    }
  }

  int _getPrevSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex - 1 < 0) {
        shuffledQueue.shuffle();
        currentShuffleIndex = shuffledQueue.length - 1;
      } else {
        currentShuffleIndex -= 1;
      }
      return queue.value
          .indexWhere((item) => item.id == shuffledQueue[currentShuffleIndex]);
    }

    if (currentIndex - 1 >= 0) {
      return currentIndex - 1;
    } else {
      return currentIndex;
    }
  }

  @override
  Future<void> skipToNext() async {
    _checkAndRecordSongCompletion();
    _currentSongCompletedRecorded = false;
    _currentSongPlayedSeconds = 0;
    final index = _getNextSongIndex();
    if (index != currentIndex) {
      try {
        _player.pause();
      } catch (_) {}
      await customAction("playByIndex", {'index': index});
    } else {
      _player.seek(Duration.zero);
      _player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inMilliseconds > 5000) {
      _player.seek(Duration.zero);
      return;
    }
    _checkAndRecordSongCompletion();
    _currentSongCompletedRecorded = false;
    _currentSongPlayedSeconds = 0;
    try {
      _player.pause();
    } catch (_) {}
    final index = _getPrevSongIndex();
    if (index != currentIndex) {
      await customAction("playByIndex", {'index': index});
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.none) {
      loopModeEnabled = false;
      await _player.setLoopMode(LoopMode.off);
    } else if (repeatMode == AudioServiceRepeatMode.one) {
      loopModeEnabled = true;
      await _player.setLoopMode(LoopMode.one);
    } else {
      loopModeEnabled = false;
      await _player.setLoopMode(LoopMode.all);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      shuffleModeEnabled = false;
      shuffledQueue.clear();
    } else {
      _shuffleCmd(currentIndex);
      shuffleModeEnabled = true;
    }
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await _player.dispose();
        super.stop();
        break;

      case 'resetLoadingState':
        isSongLoading = false;
        try {
          await _player.stop();
        } catch (_) {}
        await _createCacheDir();
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ));
        break;

      case 'playByIndex':
        final songIndex = extras!['index'];
        currentIndex = songIndex;
        final isNewUrlReq = extras['newUrl'] ?? false;
        if (!isNewUrlReq) {
          _songErrorRetryCount = 0;
        }
        final currentSong = queue.value[currentIndex];
        final bool restoreSession = extras['restoreSession'] ?? false;
        final int reqId = ++_activePlayRequestId;

        try {
          isSongLoading = true;
          try {
            if (_player.playing) {
              await _player.pause();
            }
          } catch (_) {}
          playbackState.add(playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.loading,
            queueIndex: currentIndex,
          ));

          mediaItem.add(currentSong);
          final streamInfo = await checkNGetUrl(
            currentSong.id,
            targetMediaItem: currentSong,
            generateNewUrl: isNewUrlReq,
          ).timeout(const Duration(seconds: 30));

          if (reqId != _activePlayRequestId || songIndex != currentIndex) {
            return;
          } else if (!streamInfo.playable) {
            currentSongUrl = null;
            isSongLoading = false;
            try {
              Get.find<PlayerController>()
                  .notifyPlayError(streamInfo.statusMSG);
            } catch (_) {}
            playbackState.add(playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                errorCode: 404,
                errorMessage: streamInfo.statusMSG));
            return;
          }
          final streamAudioUrl = streamInfo.audio?.url ?? '';
          currentSongUrl = streamAudioUrl;
          final updatedExtras =
              Map<String, dynamic>.from(currentSong.extras ?? {});
          updatedExtras['url'] = streamAudioUrl;
          updatedExtras['size'] = streamInfo.audio?.size ?? 0;
          updatedExtras['codec'] = streamInfo.audio?.audioCodec.name ?? 'mp4a';
          final playableSong = currentSong.copyWith(extras: updatedExtras);
          if (songIndex < queue.value.length) {
            queue.value[songIndex] = playableSong;
          }
          mediaItem.add(playableSong);
          WatchtimeService.recordSongStart(playableSong);
          final dlBox = Hive.box("SongDownloads");
          final bool isDownloaded = dlBox.containsKey(playableSong.id) &&
              File((dlBox.get(playableSong.id)['url'] ?? '')
                      .toString()
                      .replaceFirst('file://', ''))
                  .existsSync();
          final isFromDiskCache =
              File("$_cacheDir/cachedSongs/${playableSong.id}.mp3").existsSync() &&
                  (File("$_cacheDir/cachedSongs/${playableSong.id}.mp3").lengthSync() >= 250 * 1024);
          final bool isLocalFile = isDownloaded ||
              isFromDiskCache ||
              streamAudioUrl.startsWith('file:') ||
              playableSong.extras?['url']?.toString().startsWith('file:') == true;
          _currentSongCachedToDisk = isLocalFile;
          DataUsageTracker.instance.recordAudioStream(
            title: playableSong.title,
            artist: playableSong.artist ?? '',
            itag: streamInfo.audio?.itag ?? 0,
            codec: streamInfo.audio?.audioCodec.name ?? 'aac',
            bitrate: streamInfo.audio?.bitrate ?? 0,
            sizeBytes: isLocalFile ? 0 : (streamInfo.audio?.size ?? 0),
            durationSeconds: playableSong.duration?.inSeconds ?? 0,
            source: isDownloaded
                ? 'Downloaded Songs (0 MB)'
                : (isFromDiskCache
                    ? 'Device Cache (0 MB)'
                    : (streamAudioUrl.contains('googlevideo.com')
                        ? ((streamInfo.audio?.itag == 18 ||
                                streamInfo.audio?.itag == 22)
                            ? 'YouTube (Muxed Fallback)'
                            : 'YouTube (Pure Audio)')
                        : (streamAudioUrl.contains('sndcdn')
                            ? 'SoundCloud'
                            : 'Direct Audio'))),
            isCached: isLocalFile,
          );
          playbackState
              .add(playbackState.value.copyWith(queueIndex: currentIndex));

          if (reqId != _activePlayRequestId) return;
          _isTriggeringNext = false;

          final audioSource = _createAudioSource(playableSong);
          final startPos = restoreSession
              ? Duration(milliseconds: extras['position'] ?? 0)
              : Duration.zero;

          try {
            await _player.setAudioSource(
              audioSource,
              initialPosition: startPos,
            ).timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                throw TimeoutException(
                    "Playback loading timed out after 25 seconds");
              },
            );
          } catch (loadErr) {
            final errStr = loadErr.toString().toLowerCase();
            if (reqId != _activePlayRequestId ||
                errStr.contains("loading interrupted")) {
              return;
            }
            final fallback =
                streamInfo.getFallbackFor(streamInfo.audio) ?? streamInfo.fallbackAudio;
            if (fallback != null && fallback.url != streamAudioUrl) {
              printINFO(
                  "Primary audio failed with $loadErr, switching to fallback ratebypass stream for ${currentSong.id}");
              final fallbackSong = playableSong.copyWith(extras: {
                ...Map<String, dynamic>.from(playableSong.extras ?? {}),
                'url': fallback.url,
                'size': fallback.size,
                'codec': fallback.audioCodec.name,
              });
              currentSongUrl = fallback.url;
              if (songIndex < queue.value.length) {
                queue.value[songIndex] = fallbackSong;
              }
              mediaItem.add(fallbackSong);
              DataUsageTracker.instance.recordAudioStream(
                title: fallbackSong.title,
                artist: fallbackSong.artist ?? '',
                itag: fallback.itag,
                codec: fallback.audioCodec.name,
                bitrate: fallback.bitrate,
                sizeBytes: fallback.size,
                durationSeconds: fallbackSong.duration?.inSeconds ?? 0,
                source: fallback.url.contains('googlevideo.com')
                    ? ((fallback.itag == 18 || fallback.itag == 22)
                        ? 'YouTube (Muxed Fallback)'
                        : 'YouTube (Pure Audio)')
                    : 'Direct Audio',
                isCached: false,
              );
              await _player.setAudioSource(
                _createAudioSource(fallbackSong),
                initialPosition: startPos,
              ).timeout(const Duration(seconds: 25));
            } else {
              rethrow;
            }
          }

          if (reqId != _activePlayRequestId) return;
          _isTriggeringNext = false;

          isSongLoading = false;
          if (loudnessNormalizationEnabled && GetPlatform.isAndroid) {
            _normalizeVolume(streamInfo.audio!.loudnessDb);
          }

          if (!restoreSession || GetPlatform.isDesktop) {
            try {
              final session = await AudioSession.instance;
              await session.setActive(true);
            } catch (_) {}
            await _player.play();
          }
        } catch (e, st) {
          final errStr = e.toString().toLowerCase();
          if (reqId != _activePlayRequestId ||
              errStr.contains("loading interrupted")) {
            return;
          }
          _isTriggeringNext = false;
          printERROR("playByIndex error for ${currentSong.id}: $e\n$st");
          if (!isNewUrlReq && _songErrorRetryCount == 0) {
            _songErrorRetryCount = 1;
            Hive.box("SongsUrlCache").delete(currentSong.id);
            try {
              final freshInfo = await checkNGetUrl(
                currentSong.id,
                targetMediaItem: currentSong,
                generateNewUrl: true,
                allowFallback: true,
              ).timeout(const Duration(seconds: 25));
              if (freshInfo.playable && freshInfo.audio?.url != null) {
                final playableSong = currentSong.copyWith(extras: {
                  ...Map<String, dynamic>.from(currentSong.extras ?? {}),
                  'url': freshInfo.audio!.url,
                  'size': freshInfo.audio!.size,
                  'codec': freshInfo.audio!.audioCodec.name,
                });
                if (songIndex < queue.value.length) {
                  queue.value[songIndex] = playableSong;
                }
                mediaItem.add(playableSong);
                await _player.setAudioSource(
                  _createAudioSource(playableSong),
                  initialPosition: Duration.zero,
                ).timeout(const Duration(seconds: 25));
                isSongLoading = false;
                try {
                  final session = await AudioSession.instance;
                  await session.setActive(true);
                } catch (_) {}
                await _player.play();
                return;
              }
            } catch (_) {}
          }
          currentSongUrl = null;
          final msg = _isGerman
              ? "Fehler beim Laden des Tracks: $e"
              : "Error loading track: $e";
          try {
            Get.find<PlayerController>().notifyPlayError(msg);
          } catch (_) {}
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorCode: 500,
            errorMessage: msg,
          ));
        } finally {
          isSongLoading = false;
        }
        break;

      case 'checkWithCacheDb':
        if (isPlayingUsingLockCachingSource) {
          final song = extras!['mediaItem'] as MediaItem;
          final songsCacheBox = Hive.box("SongsCache");
          if (!songsCacheBox.containsKey(song.id) &&
              await File("$_cacheDir/cachedSongs/${song.id}.mp3").exists()) {
            final Map<String, dynamic> songExtras =
                Map<String, dynamic>.from(song.extras ?? {});
            songExtras['url'] = currentSongUrl;
            songExtras['date'] = DateTime.now().millisecondsSinceEpoch;
            final updatedSong = song.copyWith(extras: songExtras);
            final dbStreamData = Hive.box("SongsUrlCache").get(song.id);
            final jsonData = MediaItemBuilder.toJson(updatedSong);
            jsonData['duration'] = _player.duration!.inSeconds;
            // playbility status and info
            jsonData['streamInfo'] = dbStreamData != null
                ? [
                    true,
                    dbStreamData[
                        Hive.box('AppPrefs').get('streamingQuality') == 2
                            ? 'lowQualityAudio'
                            : (Hive.box('AppPrefs').get('streamingQuality') == 1
                                ? 'midQualityAudio'
                                : "highQualityAudio")]
                  ]
                : null;
            songsCacheBox.put(song.id, jsonData);
            LibrarySongsController librarySongsController =
                Get.find<LibrarySongsController>();
            if (!librarySongsController.isClosed) {
              librarySongsController.librarySongsList.value =
                  librarySongsController.librarySongsList.toList() +
                      [updatedSong];
            }
          }
        }
        break;

      case 'setSourceNPlay':
        final currMed = (extras!['mediaItem'] as MediaItem);
        _songErrorRetryCount = 0;
        final int reqId = ++_activePlayRequestId;
        try {
          try {
            if (_player.playing) {
              await _player.pause();
            }
          } catch (_) {}
          playbackState.add(playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.loading,
            queueIndex: 0,
          ));
          mediaItem.add(currMed);
          queue.add([currMed]);
          isSongLoading = true;
          currentIndex = 0;

          final streamInfo = await checkNGetUrl(
            currMed.id,
            targetMediaItem: currMed,
          ).timeout(const Duration(seconds: 30));

          if (reqId != _activePlayRequestId) return;
          _isTriggeringNext = false;

          if (!streamInfo.playable) {
            currentSongUrl = null;
            isSongLoading = false;
            try {
              Get.find<PlayerController>()
                  .notifyPlayError(streamInfo.statusMSG);
            } catch (_) {}
            playbackState.add(playbackState.value
                .copyWith(processingState: AudioProcessingState.error));
            return;
          }
          currentSongUrl = streamInfo.audio!.url;
          final updatedExtras = Map<String, dynamic>.from(currMed.extras ?? {});
          updatedExtras['url'] = currentSongUrl;
          updatedExtras['size'] = streamInfo.audio!.size;
          updatedExtras['codec'] = streamInfo.audio!.audioCodec.name;
          final playableSong = currMed.copyWith(extras: updatedExtras);
          queue.add([playableSong]);
          mediaItem.add(playableSong);
          WatchtimeService.recordSongStart(playableSong);
          final dlBox = Hive.box("SongDownloads");
          final bool isDownloaded = dlBox.containsKey(playableSong.id) &&
              File((dlBox.get(playableSong.id)['url'] ?? '')
                      .toString()
                      .replaceFirst('file://', ''))
                  .existsSync();
          final isFromDiskCache =
              File("$_cacheDir/cachedSongs/${playableSong.id}.mp3").existsSync() &&
                  (File("$_cacheDir/cachedSongs/${playableSong.id}.mp3").lengthSync() >= 250 * 1024);
          final bool isLocalFile = isDownloaded ||
              isFromDiskCache ||
              currentSongUrl!.startsWith('file:') ||
              playableSong.extras?['url']?.toString().startsWith('file:') == true;
          _currentSongCachedToDisk = isLocalFile;
          DataUsageTracker.instance.recordAudioStream(
            title: playableSong.title,
            artist: playableSong.artist ?? '',
            itag: streamInfo.audio?.itag ?? 0,
            codec: streamInfo.audio?.audioCodec.name ?? 'aac',
            bitrate: streamInfo.audio?.bitrate ?? 0,
            sizeBytes: isLocalFile ? 0 : (streamInfo.audio?.size ?? 0),
            durationSeconds: playableSong.duration?.inSeconds ?? 0,
            source: isDownloaded
                ? 'Downloaded Songs (0 MB)'
                : (isFromDiskCache
                    ? 'Device Cache (0 MB)'
                    : (currentSongUrl!.contains('googlevideo.com')
                        ? ((streamInfo.audio?.itag == 18 ||
                                streamInfo.audio?.itag == 22)
                            ? 'YouTube (Muxed Fallback)'
                            : 'YouTube (Pure Audio)')
                        : (currentSongUrl!.contains('sndcdn')
                            ? 'SoundCloud'
                            : 'Direct Audio'))),
            isCached: isLocalFile,
          );

          playbackState.add(playbackState.value.copyWith(queueIndex: 0));
          if (reqId != _activePlayRequestId) return;
          _isTriggeringNext = false;
          final audioSource = _createAudioSource(playableSong);
          try {
            await _player.setAudioSource(
              audioSource,
              initialPosition: Duration.zero,
            ).timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                throw TimeoutException(
                    "Playback loading timed out after 25 seconds");
              },
            );
          } catch (loadErr) {
            final errStr = loadErr.toString().toLowerCase();
            if (reqId != _activePlayRequestId ||
                errStr.contains("loading interrupted")) {
              return;
            }
            final fallback =
                streamInfo.getFallbackFor(streamInfo.audio) ?? streamInfo.fallbackAudio;
            if (fallback != null && fallback.url != currentSongUrl) {
              printINFO(
                  "Primary audio failed with $loadErr, switching to fallback ratebypass stream for ${currMed.id}");
              final fallbackSong = playableSong.copyWith(extras: {
                ...Map<String, dynamic>.from(playableSong.extras ?? {}),
                'url': fallback.url,
                'size': fallback.size,
                'codec': fallback.audioCodec.name,
              });
              currentSongUrl = fallback.url;
              queue.add([fallbackSong]);
              mediaItem.add(fallbackSong);
              DataUsageTracker.instance.recordAudioStream(
                title: fallbackSong.title,
                artist: fallbackSong.artist ?? '',
                itag: fallback.itag,
                codec: fallback.audioCodec.name,
                bitrate: fallback.bitrate,
                sizeBytes: fallback.size,
                durationSeconds: fallbackSong.duration?.inSeconds ?? 0,
                source: fallback.url.contains('googlevideo.com')
                    ? ((fallback.itag == 18 || fallback.itag == 22)
                        ? 'YouTube (Muxed Fallback)'
                        : 'YouTube (Pure Audio)')
                    : 'Direct Audio',
                isCached: false,
              );
              await _player.setAudioSource(
                _createAudioSource(fallbackSong),
                initialPosition: Duration.zero,
              ).timeout(const Duration(seconds: 25));
            } else {
              rethrow;
            }
          }
          if (reqId != _activePlayRequestId) return;
          _isTriggeringNext = false;
          isSongLoading = false;

          // Normalize audio
          if (loudnessNormalizationEnabled && GetPlatform.isAndroid) {
            _normalizeVolume(streamInfo.audio!.loudnessDb);
          }

          try {
            final session = await AudioSession.instance;
            await session.setActive(true);
          } catch (_) {}
          await _player.play();
        } catch (e, st) {
          final errStr = e.toString().toLowerCase();
          if (reqId != _activePlayRequestId ||
              errStr.contains("loading interrupted")) {
            return;
          }
          _isTriggeringNext = false;
          printERROR("setSourceNPlay error for ${currMed.id}: $e\n$st");
          if (_songErrorRetryCount == 0) {
            _songErrorRetryCount = 1;
            Hive.box("SongsUrlCache").delete(currMed.id);
            try {
              final freshInfo = await checkNGetUrl(
                currMed.id,
                targetMediaItem: currMed,
                generateNewUrl: true,
                allowFallback: true,
              ).timeout(const Duration(seconds: 25));
              if (freshInfo.playable && freshInfo.audio?.url != null) {
                final playableSong = currMed.copyWith(extras: {
                  ...Map<String, dynamic>.from(currMed.extras ?? {}),
                  'url': freshInfo.audio!.url,
                  'size': freshInfo.audio!.size,
                  'codec': freshInfo.audio!.audioCodec.name,
                });
                queue.add([playableSong]);
                mediaItem.add(playableSong);
                await _player.setAudioSource(
                  _createAudioSource(playableSong),
                  initialPosition: Duration.zero,
                ).timeout(const Duration(seconds: 25));
                isSongLoading = false;
                try {
                  final session = await AudioSession.instance;
                  await session.setActive(true);
                } catch (_) {}
                await _player.play();
                return;
              }
            } catch (_) {}
          }
          currentSongUrl = null;
          final msg = _isGerman
              ? "Fehler beim Starten des Songs: $e"
              : "Error starting track: $e";
          try {
            Get.find<PlayerController>().notifyPlayError(msg);
          } catch (_) {}
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorCode: 500,
            errorMessage: msg,
          ));
        } finally {
          isSongLoading = false;
        }
        break;

      case 'toggleSkipSilence':
        final enable = (extras!['enable'] as bool);
        await _player.setSkipSilenceEnabled(enable);
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          _player.setVolume(1.0);
          return;
        }

        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = (queue.value[currentIndex]).id;
            if (Hive.box("SongsUrlCache").containsKey(currentSongId)) {
              final songJson = Hive.box("SongsUrlCache").get(currentSongId);
              _normalizeVolume((songJson)["highQualityAudio"]["loudnessDb"]);
              return;
            }

            if (Hive.box("SongDownloads").containsKey(currentSongId)) {
              final streamInfo =
                  (Hive.box("SongDownloads").get(currentSongId))["streamInfo"];

              _normalizeVolume(
                  streamInfo == null ? 0 : streamInfo[1]["loudnessDb"]);
            }
          } catch (e) {
            printERROR(e);
          }
        }
        break;

      case 'shuffleQueue':
        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        currentQueue.remove(currentItem);
        currentQueue.shuffle();
        currentQueue.insert(0, currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        currentIndex = 0;
        break;

      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'];
        int newIndex = extras['newIndex'];

        if (oldIndex < newIndex) {
          newIndex--;
        }

        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        final item = currentQueue.removeAt(
          oldIndex,
        );
        currentQueue.insert(newIndex, item);
        currentIndex = currentQueue.indexOf(currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        break;

      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        final currentQueue = queue.value;
        currentQueue.insert(currentIndex + 1, song);
        queue.add(currentQueue);
        if (shuffleModeEnabled) {
          shuffledQueue.insert(currentShuffleIndex + 1, song.id);
        }
        break;

      case 'openEqualizer':
        EqualizerService.openEqualizer(_player.androidAudioSessionId!);
        break;

      case 'getEqualizerData':
        if (!GetPlatform.isAndroid || _equalizer == null) {
          return {'supported': false};
        }
        try {
          final params = await _equalizer!.parameters;
          final appPrefsBox = Hive.box("AppPrefs");
          final savedPreset =
              appPrefsBox.get("eq_preset", defaultValue: "Normal");
          return {
            'supported': true,
            'enabled': _equalizer!.enabled,
            'minDecibels': params.minDecibels * 10.0,
            'maxDecibels': params.maxDecibels * 10.0,
            'bands': params.bands
                .map((b) => {
                      'index': b.index,
                      'centerFrequency': b.centerFrequency,
                      'gain': (b.gain * 10.0)
                          .clamp(params.minDecibels * 10.0, params.maxDecibels * 10.0),
                    })
                .toList(),
            'loudnessEnabled': _loudnessEnhancer?.enabled ?? false,
            'loudnessGain':
                ((_loudnessEnhancer?.targetGain ?? 0.0) * 10.0).clamp(0.0, 8.0),
            'preset': savedPreset,
          };
        } catch (e) {
          printERROR("getEqualizerData error: $e");
          return {'supported': false, 'error': e.toString()};
        }

      case 'setEqualizerEnabled':
        final enable = extras!['enabled'] as bool;
        if (_equalizer != null) {
          await _equalizer!.setEnabled(enable);
          await Hive.box("AppPrefs").put("eq_enabled", enable);

          final sessionId = _player.androidAudioSessionId;
          if (sessionId != null) {
            try {
              if (enable) {
                // Unhook system equalizer so it doesn't double-process or clash!
                EqualizerService.endAudioEffect(sessionId);
              } else {
                // Re-enable system equalizer when app equalizer is turned off
                EqualizerService.initAudioEffect(sessionId);
              }
            } catch (e) {
              printERROR("Error toggling audio effect control session: $e");
            }
          }
        }
        break;

      case 'setEqualizerBandGain':
        final index = extras!['index'] as int;
        final gainDb = (extras['gain'] as num).toDouble();
        if (_equalizer != null) {
          final params = await _equalizer!.parameters;
          if (index >= 0 && index < params.bands.length) {
            final justAudioGain =
                (gainDb / 10.0).clamp(params.minDecibels, params.maxDecibels);
            await params.bands[index].setGain(justAudioGain);
            final appPrefsBox = Hive.box("AppPrefs");
            Map savedBands = Map.from(
                appPrefsBox.get("eq_band_gains", defaultValue: {}) ?? {});
            savedBands[index] = gainDb;
            await appPrefsBox.put("eq_band_gains", savedBands);
          }
        }
        break;

      case 'setLoudnessEnhancer':
        final enable = extras!['enabled'] as bool;
        final gain = (extras['gain'] as num).toDouble();
        if (_loudnessEnhancer != null) {
          await _loudnessEnhancer!.setEnabled(enable);
          if (enable) {
            // just_audio multiplies targetGain by 1000 in Java (mB).
            // Passing (gain / 10.0) gives gain * 100 mB = gain in dB!
            final scaled = (gain / 10.0).clamp(0.0, 0.8);
            await _loudnessEnhancer!.setTargetGain(scaled);
          }
          final appPrefsBox = Hive.box("AppPrefs");
          await appPrefsBox.put("eq_loudness_enabled", enable);
          await appPrefsBox.put("eq_loudness_gain", gain);
        }
        break;

      case 'resetAudioEngine':
        try {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music());
          await session.setActive(true);
          await _player.setVolume(1.0);
          await _createCacheDir();
          final sessionId = _player.androidAudioSessionId;
          final isAppEq = Hive.box("AppPrefs")
              .get("eq_enabled", defaultValue: false) as bool;
          if (sessionId != null) {
            if (isAppEq) {
              EqualizerService.endAudioEffect(sessionId);
            } else {
              EqualizerService.initAudioEffect(sessionId);
            }
          }
          printINFO(
              "Audio engine reset successfully: volume 1.0, session active, cacheDir verified");
        } catch (e) {
          printERROR("resetAudioEngine error: $e");
        }
        break;

      case 'applyEqualizerPreset':
        final presetName = extras!['preset'] as String;
        final gains = List<double>.from(
            (extras['gains'] as List).map((e) => (e as num).toDouble()));
        final preserveBass = extras['preserveBass'] as bool? ?? false;
        final customBass = (extras['customBass'] as num?)?.toDouble() ?? 0.0;
        if (_equalizer != null) {
          final params = await _equalizer!.parameters;
          final appPrefsBox = Hive.box("AppPrefs");

          final effectiveBass = preserveBass && customBass > 0
              ? customBass
              : ((appPrefsBox.get("custom_bass_boost", defaultValue: 0.0) as num).toDouble() +
                 (appPrefsBox.get("bummm_boost_gain", defaultValue: 0.0) as num).toDouble());

          if (effectiveBass > 0 && gains.isNotEmpty) {
            gains[0] = effectiveBass;
          }

          Map savedBands = {};
          for (int i = 0; i < params.bands.length && i < gains.length; i++) {
            final justAudioGain =
                (gains[i] / 10.0).clamp(params.minDecibels, params.maxDecibels);
            await params.bands[i].setGain(justAudioGain);
            savedBands[i] = gains[i];
          }
          await appPrefsBox.put("eq_band_gains", savedBands);
          await appPrefsBox.put("eq_preset", presetName);
        }
        break;

      case 'saveSession':
        await saveSessionData();
        break;

      case 'setVolume':
        _player.setVolume(extras!['value'] / 100);
        break;

      case 'setPlayDuringCalls':
        final enabled = extras!['enabled'] as bool;
        await Hive.box("AppPrefs").put("playDuringCalls", enabled);
        break;

      case 'shuffleCmd':
        final songIndex = extras!['index'];
        _shuffleCmd(songIndex);
        break;

      case 'upadateMediaItemInAudioService':
        //added to update media item from player controller
        final songIndex = extras!['index'];
        currentIndex = songIndex;
        mediaItem.add(queue.value[currentIndex]);
        break;

      case 'toggleQueueLoopMode':
        queueLoopModeEnabled = extras!['enable'];
        break;

      case 'clearQueue':
        customAction("reorderQueue", {'oldIndex': currentIndex, 'newIndex': 0});
        final newQueue = queue.value;
        newQueue.removeRange(1, newQueue.length);
        queue.add(newQueue);
        if (shuffleModeEnabled) {
          shuffledQueue.clear();
          shuffledQueue.add(newQueue[0].id);
          currentShuffleIndex = 0;
        }
        break;
      default:
        break;
    }
  }

  void _shuffleCmd(int index) {
    final queueIds = queue.value.toList().map((item) => item.id).toList();
    final currentSongId = queueIds.removeAt(index);
    queueIds.shuffle();
    queueIds.insert(0, currentSongId);
    shuffledQueue.replaceRange(0, shuffledQueue.length, queueIds);
    currentShuffleIndex = 0;
  }

  void _normalizeVolume(double currentLoudnessDb) {
    // Boost baseline target from -5 to +0.5 dB so normalized songs remain loud, punchy and clear
    double loudnessDifference = 0.5 - currentLoudnessDb;

    // Converted loudness difference to a volume multiplier
    // We use a factor to convert dB difference to a linear scale
    // 10^(difference / 20) converts dB difference to a linear volume factor
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    printINFO(
        "loudness:$currentLoudnessDb Normalized volume: $volumeAdjustment");
    _player.setVolume(volumeAdjustment.toDouble().clamp(0.2, 1.0));
  }

  Future<void> saveSessionData() async {
    if (Get.find<SettingsScreenController>().restorePlaybackSession.isFalse) {
      return;
    }
    final currQueue = queue.value;
    if (currQueue.isNotEmpty) {
      final queueData =
          currQueue.map((e) => MediaItemBuilder.toJson(e)).toList();
      final currIndex = currentIndex ?? 0;
      final position = _player.position.inMilliseconds;
      final prevSessionData = await Hive.openBox("prevSessionData");
      await prevSessionData.clear();
      await prevSessionData.putAll(
          {"queue": queueData, "position": position, "index": currIndex});
      await prevSessionData.close();
      printINFO("Saved session data");
    }
  }

  /// Android Auto
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    return _mediaLibrary.getByRootId(parentMediaId);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return Stream.fromFuture(
            _mediaLibrary.getByRootId(parentMediaId).then((items) => items))
        .map((_) => <String, dynamic>{})
        .shareValue();
  }

  // only for Android Auto
  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    customEvent.add({
      'eventType': 'playFromMediaId',
      'songId': mediaId,
      'libraryId': extras!['libraryId'],
    });
  }

  @override
  Future<void> onTaskRemoved() async {
    final stopForegroundService =
        Get.find<SettingsScreenController>().stopPlyabackOnSwipeAway.value;
    if (stopForegroundService) {
      await Get.find<HomeScreenController>().cachedHomeScreenData();
      await saveSessionData();
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    WatchtimeService.flushBufferedPlaytime();
    _pausedByDeviceDisconnect = false;
    _wasPlayingBeforeInterruption = false;
    DiscordService().clearPresence();
    await _player.stop();
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    return super.stop();
  }

  void _applyMatchedDuration(MediaItem? song, MediaItem matched) {
    if (song == null) return;
    final missing = song.duration == null || song.duration!.inSeconds == 0;
    final matchedDuration = matched.duration;
    if (!missing ||
        matchedDuration == null ||
        matchedDuration <= Duration.zero) {
      return;
    }
    final updated = song.copyWith(duration: matchedDuration);
    final index = currentIndex;
    if (index != null &&
        index < queue.value.length &&
        queue.value[index].id == song.id) {
      queue.value[index] = updated;
    }
    mediaItem.add(updated);
  }

// Work around used [useNewInstanceOfExplode = false] to Fix Connection closed before full header was received issue
  Future<HMStreamingData> checkNGetUrl(String songId,
      {MediaItem? targetMediaItem,
      bool generateNewUrl = false,
      bool offlineReplacementUrl = false,
      bool allowFallback = true}) async {
    printINFO("Requested id : $songId");

    final targetSong = targetMediaItem ??
        queue.value.firstWhereOrNull((item) => item.id == songId) ??
        (mediaItem.value?.id == songId ? mediaItem.value : null);

    // 0. ABSOLUTE TOP PRIORITY: Check SongDownloads FIRST!
    // If this song is downloaded locally, NEVER touch the network,
    // NEVER search Spotify/SoundCloud/YouTube, and NEVER consume mobile data!
    final songDownloadsBox = Hive.box("SongDownloads");
    if (!offlineReplacementUrl && songDownloadsBox.containsKey(songId)) {
      final song = songDownloadsBox.get(songId);
      final rawPath = song is Map ? (song['url']?.toString() ?? '') : '';
      final filePath = rawPath.replaceFirst("file://", "");
      if (filePath.isNotEmpty) {
        final dlFile = File(filePath);
        if (dlFile.existsSync() && dlFile.lengthSync() > 1024) {
          printINFO(
              "checkNGetUrl: Song ($songId) is DOWNLOADED (${dlFile.lengthSync()} bytes) -> Playing offline file with 0 mobile data");
          final streamInfoJson = song["streamInfo"];
          Audio? audio;
          if (streamInfoJson != null &&
              streamInfoJson is List &&
              streamInfoJson.length > 1) {
            audio = Audio.fromJson(streamInfoJson[1]);
          }
          audio ??= Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: targetSong?.duration?.inMilliseconds ?? 0,
            loudnessDb: 0,
            url: "file://$filePath",
            size: dlFile.lengthSync(),
          );

          return HMStreamingData(
            playable: true,
            statusMSG: "OK",
            highQualityAudio: audio,
            midQualityAudio: audio,
            lowQualityAudio: audio,
          );
        }
      }
    }

    // SoundCloud Native Song Handling (Strictly SoundCloud - NEVER falls back to other platforms!)
    if (songId.startsWith("sc_")) {
      printINFO("Resolving SoundCloud track: $songId");
      final transcodingUrl = targetSong?.extras?['transcodingUrl'] as String?;
      final trackAuth = targetSong?.extras?['track_authorization'] as String?;
      final scStreamUrl = await SoundCloudService.resolveStreamUrl(songId,
          transcodingUrl: transcodingUrl, trackAuthorization: trackAuth);

      if (scStreamUrl != null && scStreamUrl.isNotEmpty) {
        int durationMs = targetSong?.duration?.inMilliseconds ?? 0;
        if (durationMs == 0 && targetSong?.extras?['duration'] != null) {
          final dur = targetSong!.extras!['duration'];
          if (dur is num) durationMs = (dur * 1000).toInt();
        }
        if (durationMs > 0 &&
            (targetSong?.duration == null ||
                targetSong?.duration == Duration.zero ||
                targetSong?.duration!.inSeconds == 0)) {
          final updatedSong = targetSong!
              .copyWith(duration: Duration(milliseconds: durationMs));
          if (currentIndex != null &&
              currentIndex! < queue.value.length &&
              queue.value[currentIndex!].id == targetSong.id) {
            queue.value[currentIndex!] = updatedSong;
          }
          mediaItem.add(updatedSong);
        }

        final audio = Audio(
          audioCodec: Codec.mp4a,
          bitrate: 160000,
          loudnessDb: 0,
          duration: durationMs,
          size: 0,
          url: scStreamUrl,
          itag: 140,
        );
        return HMStreamingData(
          playable: true,
          statusMSG: "OK",
          lowQualityAudio: audio,
          highQualityAudio: audio,
        );
      }

      SoundCloudService.invalidateStreamCache(songId);
      return HMStreamingData(
        playable: false,
        statusMSG: _isGerman
            ? "SoundCloud-Stream für '${targetSong?.title ?? songId}' konnte nicht geladen werden."
            : "Could not load SoundCloud stream for '${targetSong?.title ?? songId}'.",
      );
    }

    // Spotify or Amazon Native Track Stream Matching
    if (songId.startsWith("sp_") || songId.startsWith("az_")) {
      printINFO("Resolving Spotify/Amazon track stream for: $songId");
      if (generateNewUrl) {
        PlatformSearchService.invalidateMatch(songId);
      }
      final artistName = getSafeSongArtist(targetSong, fallback: '');
      final query = (targetSong?.extras?['searchQuery'] as String?) ??
          ('${targetSong?.title ?? ''} $artistName').trim();
      var matchedTrack = await PlatformSearchService.resolveMatchedTrack(
          songId, query,
          originalTrack: targetSong);

      for (var attempt = 0; attempt < 2 && matchedTrack != null; attempt++) {
        _applyMatchedDuration(targetSong, matchedTrack);

        if (!matchedTrack.id.startsWith("sc_")) {
          final res = await checkNGetUrl(matchedTrack.id,
              targetMediaItem: targetSong,
              generateNewUrl: generateNewUrl,
              allowFallback: true);
          if (res.playable) return res;

          // If YouTube failed, invalidate match and retry
          PlatformSearchService.invalidateMatch(songId);
          matchedTrack = await PlatformSearchService.resolveMatchedTrack(
              songId, query,
              originalTrack: targetSong, skipSoundCloud: false);
          continue;
        }

        final scStreamUrl = await SoundCloudService.resolveStreamUrl(
          matchedTrack.id,
          transcodingUrl: matchedTrack.extras?['transcodingUrl'] as String?,
          trackAuthorization:
              matchedTrack.extras?['track_authorization'] as String?,
        );
        if (scStreamUrl != null && scStreamUrl.isNotEmpty) {
          final audio = Audio(
            audioCodec: Codec.mp4a,
            bitrate: 160000,
            loudnessDb: 0,
            duration: targetSong?.duration?.inMilliseconds ??
                (matchedTrack.duration?.inMilliseconds ?? 0),
            size: 0,
            url: scStreamUrl,
            itag: 140,
          );
          return HMStreamingData(
            playable: true,
            statusMSG: "OK",
            lowQualityAudio: audio,
            highQualityAudio: audio,
          );
        }

        // The SoundCloud match had no usable stream, look for a YouTube Music match instead
        SoundCloudService.invalidateStreamCache(matchedTrack.id);
        PlatformSearchService.invalidateMatch(songId);
        matchedTrack = await PlatformSearchService.resolveMatchedTrack(
            songId, query,
            originalTrack: targetSong, skipSoundCloud: true);
      }

      // DO NOT fall through to YouTube code!
      PlatformSearchService.invalidateMatch(songId);
      return HMStreamingData(
        playable: false,
        statusMSG: _isGerman
            ? "Audio-Stream für '${targetSong?.title ?? songId}' ist derzeit nicht verfügbar."
            : "Audio stream for '${targetSong?.title ?? songId}' is currently unavailable.",
      );
    }

    final songsCacheBox = await Hive.openBox("SongsCache");
    final cachedFilePath = "$_cacheDir/cachedSongs/$songId.mp3";
    final cachedFile = File(cachedFilePath);

    if (!offlineReplacementUrl) {
      if (cachedFile.existsSync() && cachedFile.lengthSync() >= 250 * 1024) {
        printINFO(
            "Got Song from cachedbox ($songId) with verified file (${cachedFile.lengthSync()} bytes)");
        Audio? cacheAudioPlaceholder;
        if (songsCacheBox.containsKey(songId)) {
          final streamInfo = songsCacheBox.get(songId)["streamInfo"];
          if (streamInfo != null && streamInfo.isNotEmpty) {
            streamInfo[1]['url'] = "file://$cachedFilePath";
            cacheAudioPlaceholder = Audio.fromJson(streamInfo[1]);
          }
        }
        cacheAudioPlaceholder ??= Audio(
            audioCodec: Codec.mp4a,
            bitrate: 0,
            loudnessDb: 0,
            duration: targetSong?.duration?.inMilliseconds ?? 0,
            size: cachedFile.lengthSync(),
            url: "file://$cachedFilePath",
            itag: 0);

        return HMStreamingData(
            playable: true,
            statusMSG: "OK",
            lowQualityAudio: cacheAudioPlaceholder,
            midQualityAudio: cacheAudioPlaceholder,
            highQualityAudio: cacheAudioPlaceholder);
      } else if (songsCacheBox.containsKey(songId)) {
        // Cache file was deleted, corrupted, or incomplete (<250KB) -> Evict stale DB entry so fresh stream is fetched
        printINFO(
            "Cached song file missing or incomplete for ($songId). Evicting from SongsCache and fetching fresh stream.");
        if (cachedFile.existsSync()) {
          try {
            cachedFile.deleteSync();
          } catch (_) {}
        }
        await songsCacheBox.delete(songId);
      }
    }

    if (!offlineReplacementUrl && songDownloadsBox.containsKey(songId)) {
      final song = songDownloadsBox.get(songId);
      final streamInfoJson = song["streamInfo"];
      Audio? audio;
      final rawPath = song['url']?.toString() ?? '';
      final filePath = rawPath.replaceFirst("file://", "");
      final dlFile = File(filePath);

      if (dlFile.existsSync() && dlFile.lengthSync() > 1024) {
        if (streamInfoJson != null && streamInfoJson.isNotEmpty) {
          audio = Audio.fromJson(streamInfoJson[1]);
        } else {
          audio = Audio(
              itag: 140,
              audioCodec: Codec.mp4a,
              bitrate: 0,
              duration: 0,
              loudnessDb: 0,
              url: rawPath,
              size: 0);
        }

        final streamInfo = HMStreamingData(
            playable: true,
            statusMSG: "OK",
            highQualityAudio: audio,
            lowQualityAudio: audio);
        return streamInfo;
      } else {
        printINFO(
            "Downloaded song file missing for ($songId), fetching fresh network stream instead");
      }
    }
    //check if song stream url is cached and allocate url accordingly
    final songsUrlCacheBox = Hive.box("SongsUrlCache");
    final dataSaver =
        Hive.box('AppPrefs').get('dataSaverMode', defaultValue: 0);
    final streamingQuality =
        Hive.box('AppPrefs').get('streamingQuality', defaultValue: 0);
    final qualityIndex = (dataSaver is int && dataSaver > 0)
        ? dataSaver.clamp(0, 2)
        : (streamingQuality is int ? streamingQuality : 0).clamp(0, 2);
    HMStreamingData? streamInfo;

    if (songsUrlCacheBox.containsKey(songId) && !generateNewUrl) {
      final streamInfoJson = songsUrlCacheBox.get(songId);
      if (streamInfoJson.runtimeType.toString().contains("Map")) {
        final lowUrl = streamInfoJson['lowQualityAudio']?['url'];
        final highUrl = streamInfoJson['highQualityAudio']?['url'];
        final midUrl = streamInfoJson['midQualityAudio']?['url'];
        final testUrl = highUrl ?? lowUrl ?? midUrl;
        if (testUrl != null && !isExpired(url: testUrl)) {
          final lowItag = streamInfoJson['lowQualityAudio']?['itag'];
          final midItag = streamInfoJson['midQualityAudio']?['itag'];
          final highItag = streamInfoJson['highQualityAudio']?['itag'];
          final fallbackItag = streamInfoJson['fallbackAudio']?['itag'];
          // Evict old heavy video streams (itag 18 or 22) so data saver gets pure 1-2 MB audio
          final isHeavyVideo = (highItag == 18 ||
              lowItag == 18 ||
              midItag == 18 ||
              fallbackItag == 18 ||
              highItag == 22 ||
              lowItag == 22 ||
              midItag == 22 ||
              fallbackItag == 22);
          if (testUrl.contains('googlevideo.com') && isHeavyVideo) {
            printINFO("Evicting heavy video stream from cache for ($songId) to save data");
            songsUrlCacheBox.delete(songId);
          } else {
            printINFO("Got cached stream Url ($songId)");
            streamInfo = HMStreamingData.fromJson(streamInfoJson);
          }
        } else {
          songsUrlCacheBox.delete(songId);
        }
      }
    }

    if (streamInfo == null || !streamInfo.playable) {
      final token = RootIsolateToken.instance;
      Map<String, dynamic> streamInfoJson;
      try {
        streamInfoJson = await Isolate.run(
          () => getStreamInfo(songId, token),
        ).timeout(const Duration(seconds: 28));
      } catch (e) {
        printERROR("YouTube stream lookup failed for $songId: $e");
        streamInfoJson = {"playable": false, "statusMSG": e.toString()};
      }
      streamInfo = HMStreamingData.fromJson(streamInfoJson);
      if (streamInfo.playable) {
        songsUrlCacheBox.put(songId, streamInfoJson);
      } else {
        printINFO(
            "Primary YouTube stream unavailable for $songId (${streamInfo.statusMSG}). Attempting smart auto-recovery...");
        final String rawTitle = targetSong?.title ?? '';
        final String rawArtist = targetSong?.artist ?? '';

        // 1. First recovery attempt: Search YouTube for an unblocked alternative upload of the exact same track
        if (rawTitle.isNotEmpty) {
          final query = '$rawTitle $rawArtist'.trim();
          printINFO("Searching YouTube for alternative unblocked stream: $query");
          final yt = YoutubeExplode();
          try {
            final searchResults =
                await yt.search.search(query).timeout(const Duration(seconds: 7));
            for (final candidate in searchResults.take(6)) {
              final candidateId = candidate.id.value;
              if (candidateId == songId) continue;

              final origDur = targetSong?.duration?.inSeconds ?? 0;
              final candDur = candidate.duration?.inSeconds ?? 0;
              if (origDur > 0 && candDur > 0 && (origDur - candDur).abs() > 35) {
                continue;
              }

              printINFO(
                  "Testing alternative YouTube upload: $candidateId (${candidate.title})");
              try {
                final candStream = await StreamProvider.fetch(candidateId);
                if (candStream.playable &&
                    candStream.highestQualityAudio != null) {
                  printINFO(
                      "Successfully recovered age-restricted song via alternative YouTube upload: $candidateId!");
                  songsUrlCacheBox.put(songId, candStream.hmStreamingData);
                  streamInfo =
                      HMStreamingData.fromJson(candStream.hmStreamingData);
                  break;
                }
              } catch (_) {}
            }
          } catch (e) {
            printERROR("YouTube alternative search error: $e");
          } finally {
            yt.close();
          }
        }

        streamInfo ??= HMStreamingData(
          playable: false,
          statusMSG: _isGerman
              ? "Kein abspielbarer Stream für diesen Track auf YouTube gefunden."
              : "No playable stream found for this track on YouTube.",
        );

        if (!streamInfo.playable) {
          final isAgeGated = streamInfo.statusMSG
                  .toLowerCase()
                  .contains("inappropriate") ||
              streamInfo.statusMSG.toLowerCase().contains("age") ||
              streamInfo.statusMSG.toLowerCase().contains("unplayable");
          if (isAgeGated) {
            streamInfo = HMStreamingData(
              playable: false,
              statusMSG: _isGerman
                  ? "Dieser Track ist auf YouTube altersbeschränkt (ab 18). YouTube sperrt anonyme Streams hierfür."
                  : "This track is age-restricted on YouTube (18+). YouTube blocks anonymous streams for this track.",
            );
          }
        }
      }
    }

    final finalStream = streamInfo;

    finalStream.setQualityIndex(qualityIndex);
    return finalStream;
  }
}

class UrlError extends Error {
  String message() => 'Unable to fetch url';
}

// for Android Auto
class MediaLibrary {
  static const albumsRootId = 'albums';
  static const songsRootId = 'songs';
  static const favoritesRootId = "LIBFAV";
  static const playlistsRootId = 'playlists';

  Future<List<MediaItem>> getByRootId(String id) async {
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case songsRootId:
        return getLibSongs("SongDownloads");
      case favoritesRootId:
        return getLibSongs("LIBFAV");
      case albumsRootId:
        return getAlbums();
      case playlistsRootId:
        return getPlaylists();
      case AudioService.recentRootId:
        return getLibSongs("LIBRP");
      default:
        return getLibSongs(id);
    }
  }

  List<MediaItem> getRoot() {
    return [
      MediaItem(
        id: songsRootId,
        title: "songs".tr,
        playable: false,
      ),
      MediaItem(
        id: favoritesRootId,
        title: "favorites".tr,
        playable: false,
      ),
      MediaItem(
        id: albumsRootId,
        title: "albums".tr,
        playable: false,
      ),
      MediaItem(
        id: playlistsRootId,
        title: "playlists".tr,
        playable: false,
      ),
    ];
  }

  Future<List<MediaItem>> getAlbums() async {
    final box = await Hive.openBox("LibraryAlbums");
    final albums =
        box.values.map((item) => Album.fromJson(item).toMediaItem()).toList();
    await box.close();
    return albums;
  }

  Future<List<MediaItem>> getPlaylists() async {
    final box = await Hive.openBox("LibraryPlaylists");
    final playlists = [
      ...LibraryPlaylistsController.initPlst.map((e) => e.toMediaItem()),
      ...(box.values
          .map((item) => Playlist.fromJson(item).toMediaItem())
          .toList())
    ];
    await box.close();
    return playlists;
  }

  Future<List<MediaItem>> getLibSongs(String libId) async {
    Box<dynamic> box;
    try {
      box = await Hive.openBox(libId);
    } catch (e) {
      box = await Hive.openBox(libId);
    }
    final songs = box.values.toList().map((e) {
      final song = MediaItemBuilder.fromJson(e);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: song.artUri,
        extras: {"libraryId": libId},
        playable: true,
      );
    }).toList();

    if (!libId.contains("SongDownloads")) {
      await box.close();
    }

    if (libId == "LIBRP") {
      return songs.reversed.toList();
    }

    return songs;
  }
}
