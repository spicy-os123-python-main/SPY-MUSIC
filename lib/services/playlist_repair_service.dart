import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../ui/screens/Playlist/playlist_screen_controller.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/screens/Library/library_controller.dart';
import 'device_music_service.dart';
import 'stream_service.dart';

class PlaylistRepairService {
  static final PlaylistRepairService _instance =
      PlaylistRepairService._internal();
  factory PlaylistRepairService() => _instance;
  PlaylistRepairService._internal();

  bool _isRepairing = false;

  /// Automatically repair playlists in the background on startup.
  /// NOTE: NEVER auto-deletes SongDownloads on launch to prevent wiping downloads
  /// if storage mounting is delayed or path formats differ across app launches!
  Future<int> autoRepairOnLaunch() async {
    if (_isRepairing) return 0;
    _isRepairing = true;
    int totalRepaired = 0;

    try {
      final box = await Hive.openBox("LibraryPlaylists");
      final playlistKeys = box.keys.toList();

      for (var key in playlistKeys) {
        try {
          final repaired = await _repairBox(key.toString());
          totalRepaired += repaired;
        } catch (e) {
          debugPrint("[PlaylistRepair] Error repairing playlist $key: $e");
        }
      }
    } catch (e) {
      debugPrint("[PlaylistRepair] Error during launch repair: $e");
    } finally {
      _isRepairing = false;
    }

    if (totalRepaired > 0) {
      debugPrint(
          "[PlaylistRepair] Auto-repaired $totalRepaired songs across playlists.");
    }
    return totalRepaired;
  }

  /// Repair a single playlist by ID
  Future<int> repairSinglePlaylist(String playlistId) async {
    final repaired = await _repairBox(playlistId, forceDeepRepair: true);

    // Refresh open controller if available
    if (Get.isRegistered<PlaylistScreenController>(
        tag: Key(playlistId).hashCode.toString())) {
      final controller = Get.find<PlaylistScreenController>(
          tag: Key(playlistId).hashCode.toString());
      controller.fetchSongsfromDatabase(playlistId);
    }

    return repaired;
  }

  /// Deep repair for all offline downloads requested by user in Settings.
  /// 1. Verifies and relinks moved/relocated files for existing SongDownloads entries.
  /// 2. Discovers orphan audio files on device and restores them to SongDownloads.
  /// 3. Updates playlists and refreshes library controllers.
  Future<Map<String, int>> repairDownloadsDeep() async {
    int repairedCount = 0;
    int restoredCount = 0;

    final downloadsBox = Hive.box("SongDownloads");
    final List<Directory> candidateDirs = [];

    // 1. Collect candidate directories
    try {
      if (Get.isRegistered<SettingsScreenController>()) {
        final settings = Get.find<SettingsScreenController>();
        final loc = settings.downloadLocationPath.value;
        if (loc.isNotEmpty) {
          final d = Directory(loc);
          if (d.existsSync()) candidateDirs.add(d);
        }
        final sup = settings.supportDirPath;
        if (sup.isNotEmpty) {
          final m = Directory("$sup/Music");
          if (m.existsSync()) candidateDirs.add(m);
          final s = Directory(sup);
          if (s.existsSync()) candidateDirs.add(s);
        }
      }
    } catch (_) {}

    try {
      final devDirs = DeviceMusicService.instance.getSearchDirectories();
      for (final d in devDirs) {
        if (!candidateDirs.any((c) => c.path == d.path) && d.existsSync()) {
          candidateDirs.add(d);
        }
      }
    } catch (_) {}

    const audioExtensions = [
      '.opus',
      '.m4a',
      '.mp3',
      '.ogg',
      '.flac',
      '.aac',
      '.wav'
    ];

    // Build map of found files on disk: base filename -> File
    final Map<String, File> filesByBasename = {};
    final List<File> allFoundAudioFiles = [];

    for (final dir in candidateDirs) {
      try {
        if (!dir.existsSync()) continue;
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final p = entity.path;
            final lower = p.toLowerCase();
            if (audioExtensions.any((ext) => lower.endsWith(ext))) {
              try {
                if (entity.lengthSync() > 1024) {
                  final base = p.split('/').last.toLowerCase();
                  filesByBasename.putIfAbsent(base, () => entity);
                  allFoundAudioFiles.add(entity);
                }
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint("[PlaylistRepair] Error scanning dir ${dir.path}: $e");
      }
    }

    // 2. Validate and relink existing entries in SongDownloads
    final dlKeys = downloadsBox.keys.toList();
    final Set<String> indexedFilePaths = {};

    for (final key in dlKeys) {
      final raw = downloadsBox.get(key);
      if (raw is! Map) continue;
      final songMap = Map<String, dynamic>.from(raw);
      final rawUrl = songMap['url']?.toString() ?? '';
      final cleanPath = rawUrl.replaceFirst("file://", "");
      bool fileOk = false;

      if (cleanPath.isNotEmpty) {
        final f = File(cleanPath);
        if (f.existsSync() && f.lengthSync() > 1024) {
          fileOk = true;
          indexedFilePaths.add(f.path);
        }
      }

      if (!fileOk) {
        // Try to relink
        File? matchedFile;
        // A: Match by basename
        if (cleanPath.isNotEmpty) {
          final base = cleanPath.split('/').last.toLowerCase();
          if (filesByBasename.containsKey(base)) {
            matchedFile = filesByBasename[base];
          }
        }
        // B: Match by videoId in filename
        if (matchedFile == null) {
          final vId = songMap['videoId']?.toString() ?? key.toString();
          for (final f in allFoundAudioFiles) {
            if (f.path.contains(vId)) {
              matchedFile = f;
              break;
            }
          }
        }
        // C: Match by title & artist
        if (matchedFile == null) {
          final title =
              (songMap['title']?.toString() ?? '').toLowerCase().trim();
          final artist =
              (songMap['artist']?.toString() ?? '').toLowerCase().trim();
          if (title.isNotEmpty) {
            for (final f in allFoundAudioFiles) {
              final fname = f.path.split('/').last.toLowerCase();
              if (fname.contains(title) &&
                  (artist.isEmpty || fname.contains(artist))) {
                matchedFile = f;
                break;
              }
            }
          }
        }

        if (matchedFile != null && matchedFile.existsSync()) {
          songMap['url'] = matchedFile.path;
          if (songMap['streamInfo'] is List &&
              (songMap['streamInfo'] as List).length > 1) {
            final info = Map<String, dynamic>.from(songMap['streamInfo'][1]);
            info['url'] = matchedFile.path;
            songMap['streamInfo'][1] = info;
          }
          songMap['date'] ??=
              matchedFile.lastModifiedSync().millisecondsSinceEpoch;
          songMap['dateAdded'] ??= songMap['date'];
          songMap['downloadDate'] ??= songMap['date'];
          await downloadsBox.put(key, songMap);
          indexedFilePaths.add(matchedFile.path);
          repairedCount++;
          debugPrint("[PlaylistRepair] Relinked $key to ${matchedFile.path}");
        }
      } else {
        bool updated = false;
        if (songMap['date'] == null) {
          songMap['date'] =
              File(cleanPath).lastModifiedSync().millisecondsSinceEpoch;
          songMap['dateAdded'] = songMap['date'];
          songMap['downloadDate'] = songMap['date'];
          updated = true;
        }
        if (updated) {
          await downloadsBox.put(key, songMap);
        }
      }
    }

    // 3. Recover orphan audio files that exist on disk but not in SongDownloads
    for (final file in allFoundAudioFiles) {
      if (indexedFilePaths.contains(file.path)) continue;

      final nameWithExt = file.path.split('/').last;
      final dotIdx = nameWithExt.lastIndexOf('.');
      final nameNoExt =
          dotIdx > 0 ? nameWithExt.substring(0, dotIdx) : nameWithExt;

      String title = nameNoExt;
      String artist = "Offline Artist";
      if (nameNoExt.contains('(') && nameNoExt.endsWith(')')) {
        final openIdx = nameNoExt.lastIndexOf('(');
        title = nameNoExt.substring(0, openIdx).trim();
        artist = nameNoExt.substring(openIdx + 1, nameNoExt.length - 1).trim();
      } else if (nameNoExt.contains(' - ')) {
        final parts = nameNoExt.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }

      final songId = "rec_${file.path.hashCode.abs().toRadixString(16)}";
      if (!downloadsBox.containsKey(songId)) {
        final nowMs = file.lastModifiedSync().millisecondsSinceEpoch;
        final recoveredMap = {
          'id': songId,
          'videoId': songId,
          'title': title.isNotEmpty ? title : nameNoExt,
          'artist': artist,
          'album': 'Downloads',
          'url': file.path,
          'date': nowMs,
          'dateAdded': nowMs,
          'downloadDate': nowMs,
          'streamInfo': [
            true,
            {
              'url': file.path,
              'itag': 140,
              'audioCodec': 'mp4a',
              'bitrate': 0,
              'duration': 0,
              'loudnessDb': 0,
              'size': file.lengthSync(),
            }
          ],
        };
        await downloadsBox.put(songId, recoveredMap);
        indexedFilePaths.add(file.path);
        restoredCount++;
        debugPrint("[PlaylistRepair] Restored orphan download: ${file.path}");
      }
    }

    // 4. Update playlists that reference any of these repaired/restored songs
    try {
      final libPlaylists = await Hive.openBox("LibraryPlaylists");
      for (var plKey in libPlaylists.keys) {
        final plBox = await Hive.openBox(plKey.toString());
        for (int i = 0; i < plBox.length; i++) {
          final item = plBox.getAt(i);
          if (item is Map) {
            final vId =
                item['videoId']?.toString() ?? item['id']?.toString() ?? '';
            if (vId.isNotEmpty && downloadsBox.containsKey(vId)) {
              final dlData = downloadsBox.get(vId);
              if (dlData is Map && dlData['url'] != null) {
                final dlUrl = dlData['url'].toString();
                if (item['url'] != dlUrl) {
                  final updatedItem = Map<String, dynamic>.from(item);
                  updatedItem['url'] = dlUrl;
                  await plBox.putAt(i, updatedItem);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[PlaylistRepair] Error updating playlist links: $e");
    }

    // 5. Refresh controllers if registered
    try {
      if (Get.isRegistered<LibrarySongsController>()) {
        Get.find<LibrarySongsController>().init();
      }
    } catch (_) {}
    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        Get.find<LibraryPlaylistsController>().refreshLib();
      }
    } catch (_) {}

    return {
      'repaired': repairedCount,
      'restored': restoredCount,
      'total': downloadsBox.length,
    };
  }

  /// Internal repair logic for a playlist box
  Future<int> _repairBox(String playlistId,
      {bool forceDeepRepair = false}) async {
    int repairedInBox = 0;
    final box = await Hive.openBox(playlistId);
    final songsCacheBox = Hive.box("SongsUrlCache");
    final downloadsBox = Hive.box("SongDownloads");

    for (int i = 0; i < box.length; i++) {
      final rawItem = box.getAt(i);
      if (rawItem == null || rawItem is! Map) continue;

      final songMap = Map<String, dynamic>.from(rawItem);
      final String videoId = songMap['videoId']?.toString() ?? '';
      if (videoId.isEmpty) continue;

      bool itemModified = false;
      int? durSeconds = songMap['duration'] is int
          ? songMap['duration'] as int
          : int.tryParse(songMap['duration']?.toString() ?? '');
      String? lengthStr = songMap['length']?.toString();

      // Check if duration is missing or 0:00
      final bool needsDurationFix = durSeconds == null ||
          durSeconds <= 0 ||
          lengthStr == null ||
          lengthStr.isEmpty ||
          lengthStr == "0:00";

      if (needsDurationFix) {
        // 1. Try SongsUrlCache
        if (songsCacheBox.containsKey(videoId)) {
          final cached = songsCacheBox.get(videoId);
          final approxMs = cached?['highQualityAudio']?['approxDurationMs'] ??
              cached?['lowQualityAudio']?['approxDurationMs'];
          if (approxMs is int && approxMs > 0) {
            durSeconds = approxMs ~/ 1000;
            lengthStr = _formatDuration(durSeconds);
            songMap['duration'] = durSeconds;
            songMap['length'] = lengthStr;
            itemModified = true;
          }
        }

        // 2. Try SongDownloads
        if (!itemModified && downloadsBox.containsKey(videoId)) {
          final downData = downloadsBox.get(videoId);
          final d = downData?['duration'];
          if (d is int && d > 0) {
            durSeconds = d;
            lengthStr = _formatDuration(durSeconds);
            songMap['duration'] = durSeconds;
            songMap['length'] = lengthStr;
            itemModified = true;
          }
        }

        // 3. Fallback: Query StreamProvider if deep repair requested
        if (!itemModified && forceDeepRepair) {
          try {
            final stream = await StreamProvider.fetch(videoId);
            if (stream.playable && stream.audioFormats != null) {
              final firstAudio = stream.audioFormats!.first;
              if (firstAudio.duration > 0) {
                durSeconds = firstAudio.duration ~/ 1000;
                lengthStr = _formatDuration(durSeconds);
                songMap['duration'] = durSeconds;
                songMap['length'] = lengthStr;
                itemModified = true;
              }
            }
          } catch (_) {}
        }
      }

      // Check if this song is supposed to be downloaded
      if (downloadsBox.containsKey(videoId)) {
        final downData = downloadsBox.get(videoId);
        final downPath = downData?['url']?.toString();
        if (downPath != null && downPath.isNotEmpty) {
          final cleanPath = downPath.replaceFirst("file://", "");
          final file = File(cleanPath);
          if (file.existsSync() && file.lengthSync() > 1000) {
            if (songMap['url'] != cleanPath) {
              songMap['url'] = cleanPath;
              itemModified = true;
            }
          } else {
            // Do NOT delete from downloadsBox! Only clear stale playlist url
            // so online stream can be used if offline file is temporarily missing
            if (songMap['url'] != null) {
              songMap.remove('url');
              itemModified = true;
            }
          }
        }
      }

      // Ensure date is present in playlist item
      if (songMap['date'] == null) {
        songMap['date'] = i * 1000;
        itemModified = true;
      }

      if (itemModified) {
        await box.putAt(i, songMap);
        repairedInBox++;
      }
    }

    return repairedInBox;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
