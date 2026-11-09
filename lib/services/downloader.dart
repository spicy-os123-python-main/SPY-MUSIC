import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../ui/screens/Album/album_screen_controller.dart';
import '../ui/screens/Playlist/playlist_screen_controller.dart';
import '/services/stream_service.dart';
import '../ui/widgets/snackbar.dart';
import '../ui/widgets/image_widget.dart';
import '/services/permission_service.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '/utils/helper.dart';
import '/models/media_Item_builder.dart';
import '../ui/screens/Library/library_controller.dart';
import 'music_service.dart';
//import '../models/thumbnail.dart' as th;

class Downloader extends GetxService {
  final _dio = Dio();
  MediaItem? currentSong;
  RxMap<String, List<MediaItem>> playlistQueue =
      <String, List<MediaItem>>{}.obs;
  final currentPlaylistId = "".obs;
  final songDownloadingProgress = 0.obs;
  final playlistDownloadingProgress = 0.obs;
  final isJobRunning = false.obs;

  RxList<MediaItem> songQueue = <MediaItem>[].obs;

  Future<bool> checkPermissionNDir() async {
    final settingsScreenController = Get.find<SettingsScreenController>();

    if (!settingsScreenController.isCurrentPathsupportDownDir &&
        !await PermissionService.getExtStoragePermission()) {
      return false;
    }

    final dirPath =
        Get.find<SettingsScreenController>().downloadLocationPath.string;
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return true;
  }

  Future<void> downloadPlaylist(
      String playlistId, List<MediaItem> songList) async {
    if (!(await checkPermissionNDir())) return;

    // for toggle between downloading request & cancelling
    if (playlistQueue.containsKey(playlistId)) {
      songQueue.removeWhere((element) => songList.contains(element));
      playlistQueue.remove(playlistId);
      return;
    }

    playlistQueue[playlistId] = songList;
    songQueue.addAll(songList);

    if (isJobRunning.isFalse) {
      await triggerDownloadingJob();
    }
  }

  Future<void> download(MediaItem? song, {List<MediaItem>? songList}) async {
    if (!(await checkPermissionNDir())) return;
    if (songList != null) {
      songQueue.addAll(songList);
    } else {
      songQueue.add(song!);
    }
    if (isJobRunning.isFalse) {
      await triggerDownloadingJob();
    }
  }

  Future<void> triggerDownloadingJob() async {
    //check if playlist download in queue => download playlistsongs else download from general songs queue
    if (playlistQueue.isNotEmpty) {
      isJobRunning.value = true;
      for (String playlistId in playlistQueue.keys.toList()) {
        //checked in case download cancel request
        if (playlistQueue.containsKey(playlistId)) {
          currentPlaylistId.value = playlistId;
          await downloadSongList((playlistQueue[playlistId]!).toList(),
              isPlaylist: true);
          if (Get.isRegistered<PlaylistScreenController>(
                  tag: Key(playlistId).hashCode.toString()) &&
              playlistQueue.containsKey(playlistId)) {
            Get.find<PlaylistScreenController>(
                    tag: Key(playlistId).hashCode.toString())
                .isDownloaded
                .value = true;
          } 
          // in case of album
          else if (Get.isRegistered<AlbumScreenController>(
                  tag: Key(playlistId).hashCode.toString()) &&
              playlistQueue.containsKey(playlistId)) {
            Get.find<AlbumScreenController>(
                    tag: Key(playlistId).hashCode.toString())
                .isDownloaded
                .value = true;
          }
          playlistQueue.remove(playlistId);
        }
        currentPlaylistId.value = "";
        playlistDownloadingProgress.value = 0;
      }
    } else {
      isJobRunning.value = true;
      await downloadSongList(songQueue.toList());
    }

    if (songQueue.isNotEmpty) {
      triggerDownloadingJob();
    } else {
      isJobRunning.value = false;
      currentSong = null;
    }
  }

  Future<void> downloadSongList(List<MediaItem> jobSongList,
      {bool isPlaylist = false}) async {
    for (MediaItem song in jobSongList) {
      // intrrupt downloading task in case of playlist download cancel request
      if (isPlaylist && !playlistQueue.containsKey(currentPlaylistId.value)) {
        currentPlaylistId.value = "";
        playlistDownloadingProgress.value = 0;
        return;
      }

      if (!Hive.box("SongDownloads").containsKey(song.id)) {
        currentSong = song;
        songDownloadingProgress.value = 0;
        await writeFileStream(song);
      }
      songQueue.remove(song);
      //for playlist downloading counter update
      if (isPlaylist) {
        playlistDownloadingProgress.value = jobSongList.indexOf(song) + 1;
      }
    }
  }

  Future<void> writeFileStream(MediaItem song) async {
    Completer<void> complete = Completer();

    final settingsScreenController = Get.find<SettingsScreenController>();
    final downloadingFormat = settingsScreenController.downloadingFormat.string;

    final playerResponse = await StreamProvider.fetch(song.id);
    // if (!playerResponse.playable) {
    //   printINFO("Network error! Check your network connection.");
    //   ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
    //       Get.context!, playerResponse.statusMSG,
    //       size: SanckBarSize.BIG,
    //       duration: const Duration(seconds: 2),
    //       top: !GetPlatform.isDesktop));
    //   complete.complete();
    //   return complete.future;
    // }

    if (!playerResponse.playable) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!,
          playerResponse.statusMSG == "networkError"
              ? playerResponse.statusMSG.tr
              : playerResponse.statusMSG,
          size: SanckBarSize.BIG,
          duration: const Duration(seconds: 2),
          top: !GetPlatform.isDesktop));
      printINFO("Requested song is not downloadable. You may try again");
      complete.complete();
      return complete.future;
    }

    Audio? selectedStream = downloadingFormat == "opus"
        ? (playerResponse.highestBitrateOpusAudio ?? playerResponse.highestQualityAudio)
        : (playerResponse.highestQualityAudio ?? playerResponse.highestBitrateMp4aAudio);
    selectedStream ??= playerResponse.highestQualityAudio;
    if (selectedStream == null) {
      complete.complete();
      return complete.future;
    }
    final Audio requiredAudioStream = selectedStream;

    final dirPath = settingsScreenController.downloadLocationPath.string;
    final actualDownformat =
        requiredAudioStream.audioCodec.name.contains("mp") ? "m4a" : "opus";
    final RegExp invalidChar =
        RegExp(r'Container.|\/|\\|\"|\<|\>|\*|\?|\:|\!|\[|\]|\¡|\||\%');
    final songTitle = "${song.title.trim()} (${song.artist?.trim()})"
        .replaceAll(invalidChar, "");
    String filePath = "$dirPath/$songTitle.$actualDownformat";
    printINFO("Downloading filePath: $filePath");
    final totalBytes = requiredAudioStream.size;

    final downloadHeaders = <String, dynamic>{
      if (totalBytes > 0) "Range": 'bytes=0-$totalBytes',
      if (requiredAudioStream.url.contains('googlevideo.com'))
        'User-Agent':
            'com.google.android.youtube/19.09.37 (Linux; U; Android 11; US) gzip',
    };

    _dio.download(
        requiredAudioStream.url,
        options: Options(headers: downloadHeaders),
        filePath, onReceiveProgress: (count, total) {
      if (total <= 0) return;
      songDownloadingProgress.value = ((count / total) * 100).toInt();
    }).then(
      (value) async {
        printINFO(value.data);

        String? year;
        try {
          if (song.extras?['year'] != null) {
            year = song.extras?['year'];
          } else {
            if (song.album != null) {
              final musicServ = Get.find<MusicServices>();
              year = await musicServ.getSongYear(song.id);
            }
          }
        } catch (_) {}

        // Save Thumbnail locally with compact size (~40-80 KB)
        String thumbnailPath = "";
        try {
          final supportDir = settingsScreenController.supportDirPath;
          final thumbDir = Directory("$supportDir/thumbnails");
          if (!thumbDir.existsSync()) {
            thumbDir.createSync(recursive: true);
          }
          thumbnailPath = "$supportDir/thumbnails/${song.id}.png";
          String artUriStr = song.artUri?.toString() ?? '';
          if (artUriStr.isEmpty || artUriStr == 'null') {
            artUriStr = (song.extras?['thumbnailUrl'] ??
                song.extras?['artworkUrl'] ??
                '') as String;
          }
          if (artUriStr.isEmpty &&
              song.extras?['thumbnails'] is List &&
              (song.extras!['thumbnails'] as List).isNotEmpty) {
            final first = (song.extras!['thumbnails'] as List).first;
            if (first is Map && first['url'] != null) {
              artUriStr = first['url'].toString();
            } else if (first is String) {
              artUriStr = first;
            }
          }
          if (artUriStr.isNotEmpty &&
              (artUriStr.startsWith('http://') ||
                  artUriStr.startsWith('https://'))) {
            final optimizedThumb = ImageWidget.optimizeThumbnailUrl(
                artUriStr, true,
                isDataSaver: true);
            await _dio.download(
              optimizedThumb,
              thumbnailPath,
              options: Options(receiveTimeout: const Duration(seconds: 12)),
            );
          }
        } catch (e) {
          printERROR("Thumbnail download error for ${song.id}: $e");
        }

        final bool hasLocalThumb = thumbnailPath.isNotEmpty &&
            File(thumbnailPath).existsSync() &&
            File(thumbnailPath).lengthSync() > 100;

        song.extras?['url'] = filePath;
        final songJson = MediaItemBuilder.toJson(song);
        songJson['url'] = filePath;
        if (hasLocalThumb) {
          songJson['artUri'] = "file://$thumbnailPath";
          songJson['localThumbnail'] = thumbnailPath;
          songJson['artworkUrl'] = "file://$thumbnailPath";
          songJson['thumbnails'] = [
            {'url': "file://$thumbnailPath"}
          ];
        }
        final streamInfoJson = requiredAudioStream.toJson();
        streamInfoJson['url'] = filePath;
        // [playbility status, info map]
        songJson["streamInfo"] = [true, streamInfoJson];

        Hive.box("SongDownloads").put(song.id, songJson);
        final downloadedMediaItem = song.copyWith(
          artUri: hasLocalThumb ? Uri.file(thumbnailPath) : song.artUri,
          extras: {
            ...Map<String, dynamic>.from(song.extras ?? {}),
            'url': filePath,
            if (hasLocalThumb) 'localThumbnail': thumbnailPath,
          },
        );
        Get.find<LibrarySongsController>()
            .librarySongsList
            .add(downloadedMediaItem);
        printINFO(
            "Downloaded successfully: ${(File(filePath).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB");

        final trackDetails = (song.extras?['trackDetails'])?.split("/");
        final int? trackNumber = int.tryParse(trackDetails?[0] ?? "");
        final int? totalTracks = int.tryParse(trackDetails?[1] ?? "");

        try {
          List<Picture> pictures = [];
          if (hasLocalThumb) {
            final thumbBytes = await File(thumbnailPath).readAsBytes();
            pictures.add(Picture(
                bytes: thumbBytes,
                mimeType: MimeType.png,
                pictureType: PictureType.coverFront));
          }
          Tag tag = Tag(
              title: song.title,
              trackArtist: song.artist,
              album: song.album,
              year: int.tryParse(year ?? ""),
              trackNumber: trackNumber,
              trackTotal: totalTracks,
              albumArtist: song.artist,
              genre: song.genre,
              pictures: pictures);

          await AudioTags.write(filePath, tag);
        } catch (e) {
          printERROR("$e");
        }
        complete.complete();
      },
    ).onError(
      (error, stackTrace) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
            Get.context!, "downloadError3".tr,
            size: SanckBarSize.BIG,
            duration: const Duration(seconds: 2),
            top: !GetPlatform.isDesktop));
        printINFO(
            "Downloading failed due to network/stream error! Please try again");
        complete.complete();
      },
    );

    return complete.future;
  }
}
