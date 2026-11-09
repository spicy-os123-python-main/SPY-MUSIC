import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import 'stream_service.dart';
import '../ui/screens/Library/library_controller.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import 'permission_service.dart';
import '../utils/helper.dart';

class DeviceMusicService extends GetxService {
  static DeviceMusicService get instance {
    if (!Get.isRegistered<DeviceMusicService>()) {
      return Get.put(DeviceMusicService(), permanent: true);
    }
    return Get.find<DeviceMusicService>();
  }

  final RxBool isScanning = false.obs;
  final RxInt scannedCount = 0.obs;
  DateTime? _lastScanTime;

  static const List<String> audioExtensions = [
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
  ];

  /// Get standard music directories on device (Android & Desktop)
  List<Directory> getSearchDirectories() {
    final List<Directory> dirs = [];

    if (Platform.isAndroid) {
      final paths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Download/SPY_MUSIC',
        '/storage/emulated/0/Samsung/Music',
        '/storage/emulated/0/Audio',
        '/storage/emulated/0/media/audio',
        '/storage/emulated/0/Documents',
      ];

      // Add user-defined download location
      if (Get.isRegistered<SettingsScreenController>()) {
        final customPath =
            Get.find<SettingsScreenController>().downloadLocationPath.string;
        if (customPath.isNotEmpty && !paths.contains(customPath)) {
          paths.add(customPath);
        }
      }

      for (final p in paths) {
        final d = Directory(p);
        if (d.existsSync()) dirs.add(d);
      }

      // Check for external SD cards
      try {
        final storageRoot = Directory('/storage');
        if (storageRoot.existsSync()) {
          for (final entity in storageRoot.listSync()) {
            if (entity is Directory) {
              final name = entity.path.split('/').last;
              if (name != 'emulated' && name != 'self') {
                final sdMusic = Directory('${entity.path}/Music');
                if (sdMusic.existsSync()) dirs.add(sdMusic);
                final sdDownload = Directory('${entity.path}/Download');
                if (sdDownload.existsSync()) dirs.add(sdDownload);
              }
            }
          }
        }
      } catch (_) {}
    } else {
      // Desktop / Linux / macOS / Windows
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isNotEmpty) {
        final music = Directory('$home/Music');
        if (music.existsSync()) dirs.add(music);
        final dl = Directory('$home/Downloads');
        if (dl.existsSync()) dirs.add(dl);
      }
    }

    return dirs;
  }

  /// Scans device for audio files, extracts metadata and adds to SongDownloads box
  Future<int> scanDeviceSongs({bool forceRescan = false}) async {
    if (isScanning.value) return scannedCount.value;

    // Throttle automatic scans to once every 60 seconds unless forced
    if (!forceRescan &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!).inSeconds < 60) {
      return scannedCount.value;
    }

    // Check permissions
    final hasPerm = await PermissionService.getExtStoragePermission();
    if (!hasPerm) {
      printINFO("[DeviceMusicService] Storage permission not granted. Skipping scan.");
      return 0;
    }

    isScanning.value = true;
    _lastScanTime = DateTime.now();
    int newSongsFound = 0;

    try {
      final searchDirs = getSearchDirectories();
      if (searchDirs.isEmpty) {
        isScanning.value = false;
        return 0;
      }

      final downloadsBox = Hive.box("SongDownloads");
      final existingPaths = <String>{};
      for (var key in downloadsBox.keys) {
        final item = downloadsBox.get(key);
        if (item is Map && item['url'] != null) {
          final p = item['url'].toString().replaceFirst('file://', '');
          existingPaths.add(p);
        }
      }

      final String supportDir = Get.isRegistered<SettingsScreenController>()
          ? Get.find<SettingsScreenController>().supportDirPath
          : '';
      final thumbDir = Directory("$supportDir/thumbnails");
      if (!thumbDir.existsSync() && supportDir.isNotEmpty) {
        thumbDir.createSync(recursive: true);
      }

      // Collect all candidate audio files
      final List<File> audioFiles = [];
      for (final dir in searchDirs) {
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
            if (entity is File) {
              final lowerPath = entity.path.toLowerCase();
              if (audioExtensions.any((ext) => lowerPath.endsWith(ext))) {
                // Ignore small sound effects, hidden files, cache
                if (lowerPath.contains('/.') ||
                    lowerPath.contains('/.cachedsongs') ||
                    lowerPath.contains('/thumbnails')) {
                  continue;
                }
                try {
                  if (entity.lengthSync() > 150 * 1024) {
                    audioFiles.add(entity);
                  }
                } catch (_) {}
              }
            }
          }
        } catch (e) {
          debugPrint("[DeviceMusicService] Error scanning dir ${dir.path}: $e");
        }
      }

      printINFO("[DeviceMusicService] Found ${audioFiles.length} audio files on device");

      // Process new files
      for (final file in audioFiles) {
        final filePath = file.path;
        if (existingPaths.contains(filePath)) continue;

        final songId = "dev_${filePath.hashCode.abs().toRadixString(16)}";
        if (downloadsBox.containsKey(songId)) continue;

        // Extract metadata via AudioTags
        String title = "";
        String artist = "";
        String album = "Gerätedateien";
        String? year;
        int durationSec = 0;
        String localThumbPath = "";

        try {
          final tag = await AudioTags.read(filePath);
          if (tag != null) {
            title = (tag.title ?? '').trim();
            artist = (tag.trackArtist ?? tag.albumArtist ?? '').trim();
            if (tag.album != null && tag.album!.trim().isNotEmpty) {
              album = tag.album!.trim();
            }
            if (tag.year != null) {
              year = tag.year.toString();
            }
            if (tag.duration != null && tag.duration! > 0) {
              durationSec = tag.duration!;
            }

            // Extract cover art if present
            if (supportDir.isNotEmpty &&
                tag.pictures.isNotEmpty &&
                tag.pictures.first.bytes.isNotEmpty) {
              final targetThumb = File("$supportDir/thumbnails/$songId.png");
              if (!targetThumb.existsSync()) {
                await targetThumb.writeAsBytes(tag.pictures.first.bytes);
              }
              localThumbPath = targetThumb.path;
            }
          }
        } catch (_) {}

        // Fallback title & artist from filename if missing
        if (title.isEmpty) {
          final fileName = file.uri.pathSegments.last;
          final baseName = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
          if (baseName.contains(' - ')) {
            final parts = baseName.split(' - ');
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          } else {
            title = baseName.replaceAll('_', ' ').trim();
          }
        }
        if (artist.isEmpty) {
          artist = "Unbekannt";
        }

        final duration = Duration(seconds: durationSec);
        final lengthStr = durationSec > 0
            ? "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}"
            : "NA";

        final hasThumb = localThumbPath.isNotEmpty && File(localThumbPath).existsSync();

        final mediaItem = MediaItem(
          id: songId,
          title: title,
          artist: artist,
          album: album,
          duration: duration,
          artUri: hasThumb ? Uri.file(localThumbPath) : null,
          extras: {
            'url': filePath,
            if (hasThumb) 'localThumbnail': localThumbPath,
            'isLocal': true,
            'isDeviceSong': true,
            'platform': 'Gerät',
            'length': lengthStr,
            'year': year,
            'size': file.lengthSync(),
          },
        );

        final songJson = MediaItemBuilder.toJson(mediaItem);
        songJson['url'] = filePath;
        if (hasThumb) {
          songJson['artUri'] = "file://$localThumbPath";
          songJson['localThumbnail'] = localThumbPath;
          songJson['artworkUrl'] = "file://$localThumbPath";
          songJson['thumbnails'] = [
            {'url': "file://$localThumbPath"}
          ];
        }

        final streamAudio = Audio(
          itag: 140,
          audioCodec: Codec.mp4a,
          bitrate: 0,
          duration: durationSec * 1000,
          loudnessDb: 0,
          url: "file://$filePath",
          size: file.lengthSync(),
        );
        songJson['streamInfo'] = [true, streamAudio.toJson()];

        await downloadsBox.put(songId, songJson);
        existingPaths.add(filePath);
        newSongsFound++;
      }

      scannedCount.value = existingPaths.length;
      printINFO("[DeviceMusicService] Scan completed. $newSongsFound new songs indexed (Total: ${existingPaths.length})");

      // Notify LibrarySongsController if registered
      if (newSongsFound > 0 && Get.isRegistered<LibrarySongsController>()) {
        try {
          Get.find<LibrarySongsController>().init();
        } catch (_) {}
      }
    } catch (e) {
      printERROR("[DeviceMusicService] scanDeviceSongs error: $e");
    } finally {
      isScanning.value = false;
    }

    return newSongsFound;
  }
}

