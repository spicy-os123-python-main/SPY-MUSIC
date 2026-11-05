import 'dart:io';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class DataUsageTracker extends GetxService {
  static final DataUsageTracker instance = DataUsageTracker._();
  DataUsageTracker._() {
    _loadPersistedStats();
  }

  final RxInt sessionAudioBytes = 0.obs;
  final RxInt sessionAudioCount = 0.obs;

  final RxInt sessionImageBytes = 0.obs;
  final RxInt sessionImageCount = 0.obs;

  final RxInt sessionApiBytes = 0.obs;
  final RxInt sessionApiCount = 0.obs;

  final RxInt totalAudioBytes = 0.obs;
  final RxInt totalAudioCount = 0.obs;

  final RxInt totalImageBytes = 0.obs;
  final RxInt totalImageCount = 0.obs;

  final RxInt totalApiBytes = 0.obs;
  final RxInt totalApiCount = 0.obs;

  final RxString lastTrackTitle = "".obs;
  final RxString lastTrackArtist = "".obs;
  final RxString lastTrackCodec = "".obs;
  final RxInt lastTrackBitrate = 0.obs;
  final RxInt lastTrackItag = 0.obs;
  final RxInt lastTrackBytes = 0.obs;
  final RxString lastTrackSource = "".obs;

  final RxDouble diskImageCacheMb = 0.0.obs;
  final RxDouble diskAudioCacheMb = 0.0.obs;

  final Set<String> _sessionTrackedImages = {};

  int get sessionTotalBytes =>
      sessionAudioBytes.value + sessionImageBytes.value + sessionApiBytes.value;

  int get totalAllBytes =>
      totalAudioBytes.value + totalImageBytes.value + totalApiBytes.value;

  void _loadPersistedStats() {
    try {
      final box = Hive.box('AppPrefs');
      totalAudioBytes.value =
          box.get('dev_total_audio_bytes', defaultValue: 0) as int;
      totalAudioCount.value =
          box.get('dev_total_audio_count', defaultValue: 0) as int;
      totalImageBytes.value =
          box.get('dev_total_image_bytes', defaultValue: 0) as int;
      totalImageCount.value =
          box.get('dev_total_image_count', defaultValue: 0) as int;
      totalApiBytes.value =
          box.get('dev_total_api_bytes', defaultValue: 0) as int;
      totalApiCount.value =
          box.get('dev_total_api_count', defaultValue: 0) as int;

      lastTrackTitle.value =
          box.get('dev_last_track_title', defaultValue: '') as String;
      lastTrackArtist.value =
          box.get('dev_last_track_artist', defaultValue: '') as String;
      lastTrackCodec.value =
          box.get('dev_last_track_codec', defaultValue: '') as String;
      lastTrackBitrate.value =
          box.get('dev_last_track_bitrate', defaultValue: 0) as int;
      lastTrackItag.value =
          box.get('dev_last_track_itag', defaultValue: 0) as int;
      lastTrackBytes.value =
          box.get('dev_last_track_bytes', defaultValue: 0) as int;
      lastTrackSource.value =
          box.get('dev_last_track_source', defaultValue: '') as String;
    } catch (_) {}
    refreshDiskCaches();
  }

  void _savePersistedStats() {
    try {
      final box = Hive.box('AppPrefs');
      box.put('dev_total_audio_bytes', totalAudioBytes.value);
      box.put('dev_total_audio_count', totalAudioCount.value);
      box.put('dev_total_image_bytes', totalImageBytes.value);
      box.put('dev_total_image_count', totalImageCount.value);
      box.put('dev_total_api_bytes', totalApiBytes.value);
      box.put('dev_total_api_count', totalApiCount.value);

      box.put('dev_last_track_title', lastTrackTitle.value);
      box.put('dev_last_track_artist', lastTrackArtist.value);
      box.put('dev_last_track_codec', lastTrackCodec.value);
      box.put('dev_last_track_bitrate', lastTrackBitrate.value);
      box.put('dev_last_track_itag', lastTrackItag.value);
      box.put('dev_last_track_bytes', lastTrackBytes.value);
      box.put('dev_last_track_source', lastTrackSource.value);
    } catch (_) {}
  }

  void recordAudioStream({
    required String title,
    required String artist,
    required int itag,
    required String codec,
    required int bitrate,
    required int sizeBytes,
    int durationSeconds = 0,
    String source = 'YouTube',
    bool isCached = false,
  }) {
    if (isCached) {
      sessionAudioCount.value += 1;
      totalAudioCount.value += 1;
      lastTrackTitle.value = title;
      lastTrackArtist.value = artist;
      lastTrackCodec.value = codec;
      lastTrackBitrate.value = bitrate;
      lastTrackItag.value = itag;
      lastTrackBytes.value = 0;
      lastTrackSource.value = 'Offline Cache (0 MB)';
      _savePersistedStats();
      refreshDiskCaches();
      return;
    }

    int effectiveBytes = sizeBytes;
    if (effectiveBytes <= 0 && bitrate > 0) {
      final dur = durationSeconds > 0 ? durationSeconds : 210;
      effectiveBytes = (bitrate * dur / 8).round();
    }
    if (effectiveBytes <= 0) {
      effectiveBytes = 1250000;
    }

    sessionAudioBytes.value += effectiveBytes;
    sessionAudioCount.value += 1;
    totalAudioBytes.value += effectiveBytes;
    totalAudioCount.value += 1;

    lastTrackTitle.value = title;
    lastTrackArtist.value = artist;
    lastTrackCodec.value = codec;
    lastTrackBitrate.value = bitrate;
    lastTrackItag.value = itag;
    lastTrackBytes.value = effectiveBytes;
    lastTrackSource.value = source;

    _savePersistedStats();
    refreshDiskCaches();
  }

  void recordImageLoad({required String url, required int estimatedBytes}) {
    if (url.isEmpty || _sessionTrackedImages.contains(url)) return;
    _sessionTrackedImages.add(url);

    sessionImageBytes.value += estimatedBytes;
    sessionImageCount.value += 1;
    totalImageBytes.value += estimatedBytes;
    totalImageCount.value += 1;

    _savePersistedStats();
  }

  void recordApiRequest({required int bytes}) {
    if (bytes <= 0) return;
    sessionApiBytes.value += bytes;
    sessionApiCount.value += 1;
    totalApiBytes.value += bytes;
    totalApiCount.value += 1;

    _savePersistedStats();
  }

  Future<void> refreshDiskCaches() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final tempImgDir = Directory("${cacheDir.path}/libCachedImageData");
      final imgBytes = await _calculateDirSize(tempImgDir);
      diskImageCacheMb.value = imgBytes / (1024 * 1024);

      final tempDir = await getTemporaryDirectory();
      final cachedSongsDir = Directory("${tempDir.path}/cachedSongs");
      final justAudioCache = Directory("${tempDir.path}/just_audio_cache");
      final audioBytes = await _calculateDirSize(cachedSongsDir) +
          await _calculateDirSize(justAudioCache);
      diskAudioCacheMb.value = audioBytes / (1024 * 1024);
    } catch (_) {}
  }

  static Future<int> _calculateDirSize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  void resetStats() {
    sessionAudioBytes.value = 0;
    sessionAudioCount.value = 0;
    sessionImageBytes.value = 0;
    sessionImageCount.value = 0;
    sessionApiBytes.value = 0;
    sessionApiCount.value = 0;

    totalAudioBytes.value = 0;
    totalAudioCount.value = 0;
    totalImageBytes.value = 0;
    totalImageCount.value = 0;
    totalApiBytes.value = 0;
    totalApiCount.value = 0;

    _sessionTrackedImages.clear();

    _savePersistedStats();
    refreshDiskCaches();
  }

  static String formatBytes(num bytes) {
    if (bytes <= 0) return "0 KB";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }
}

