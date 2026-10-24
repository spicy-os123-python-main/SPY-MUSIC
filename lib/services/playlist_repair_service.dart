import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../ui/screens/Playlist/playlist_screen_controller.dart';
import 'stream_service.dart';

class PlaylistRepairService {
  static final PlaylistRepairService _instance =
      PlaylistRepairService._internal();
  factory PlaylistRepairService() => _instance;
  PlaylistRepairService._internal();

  bool _isRepairing = false;

  /// Automatically repair all playlists in the background on startup
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

      // Also clean up SongDownloads orphaned/dead files
      await _cleanupDeadDownloads();
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
        if (durSeconds == null || durSeconds <= 0) {
          if (downloadsBox.containsKey(videoId)) {
            final downData = downloadsBox.get(videoId);
            final streamInfo = downData?['streamInfo'];
            dynamic approxMs;
            if (streamInfo != null && streamInfo is List && streamInfo.length > 1 && streamInfo[1] is Map) {
              approxMs = streamInfo[1]['approxDurationMs'];
            }
            if (approxMs is int && approxMs > 0) {
              durSeconds = approxMs ~/ 1000;
              lengthStr = _formatDuration(durSeconds);
              songMap['duration'] = durSeconds;
              songMap['length'] = lengthStr;
              itemModified = true;
            }
          }
        }

        // 3. If deep repair is requested, fetch from StreamProvider / Piped
        if ((durSeconds == null || durSeconds <= 0) && forceDeepRepair) {
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
            // Dead file download - remove from SongDownloads so online stream works
            downloadsBox.delete(videoId);
            if (songMap['url'] != null) {
              songMap.remove('url');
              itemModified = true;
            }
          }
        }
      }

      if (itemModified) {
        await box.putAt(i, songMap);
        repairedInBox++;
      }
    }

    return repairedInBox;
  }

  /// Clean up SongDownloads box for non-existent local files
  Future<void> _cleanupDeadDownloads() async {
    final downloadsBox = Hive.box("SongDownloads");
    final keys = downloadsBox.keys.toList();

    for (var key in keys) {
      final item = downloadsBox.get(key);
      if (item is Map) {
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) {
          final clean = url.replaceFirst("file://", "");
          final file = File(clean);
          if (!file.existsSync() || file.lengthSync() < 1000) {
            debugPrint("[PlaylistRepair] Removing dead download: $key");
            downloadsBox.delete(key);
          }
        }
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}

