import 'dart:async';
import 'dart:io';
import 'dart:math';

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
import 'audio_handler.dart';
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

    Audio? requiredAudioStream;
    String streamUrl = "";

    // 1. If song already has a valid remote URL in extras:
    if (song.extras?['url'] != null &&
        song.extras!['url'].toString().startsWith('http')) {
      streamUrl = song.extras!['url'].toString();
    }

    // 2. Multi-platform stream resolution via AudioHandler (Spotify, SoundCloud, Amazon, YouTube)
    if (streamUrl.isEmpty ||
        song.id.startsWith("sp_") ||
        song.id.startsWith("sc_") ||
        song.id.startsWith("az_")) {
      try {
        final audioHandler = Get.find<AudioHandler>() as MyAudioHandler;
        final streamInfo =
            await audioHandler.checkNGetUrl(song.id, targetMediaItem: song);
        if (streamInfo.playable && streamInfo.audio != null) {
          requiredAudioStream = streamInfo.audio;
          streamUrl = streamInfo.audio!.url;
        }
      } catch (e) {
        printERROR("Downloader: AudioHandler stream resolution failed for ${song.id}: $e");
      }
    }

    // 3. Fallback direct YouTube fetch if still empty
    if (streamUrl.isEmpty) {
      try {
        final playerResponse = await StreamProvider.fetch(song.id);
        if (playerResponse.playable) {
          // Prefer rateBypass (itag 18) because pure DASH (140/251) can be 403-blocked on mobile
          requiredAudioStream = playerResponse.highestQualityAudio ??
              playerResponse.highestBitrateMp4aAudio ??
              playerResponse.highestBitrateOpusAudio;
          if (requiredAudioStream != null) {
            streamUrl = requiredAudioStream.url;
          }
        }
      } catch (e) {
        printERROR("Downloader: StreamProvider.fetch failed for ${song.id}: $e");
      }
    }

    if (streamUrl.isEmpty) {
      printINFO("Requested song '${song.title}' (${song.id}) is not downloadable. Stream resolution failed.");
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
            Get.context!, "Stream konnte nicht geladen werden. Bitte erneut versuchen.",
            size: SanckBarSize.BIG,
            duration: const Duration(seconds: 2),
            top: !GetPlatform.isDesktop));
      }
      complete.complete();
      return complete.future;
    }

    requiredAudioStream ??= Audio(
      itag: 18,
      audioCodec: Codec.mp4a,
      bitrate: 128000,
      duration: song.duration?.inMilliseconds ?? 0,
      loudnessDb: 0.0,
      url: streamUrl,
      size: 0,
    );
    final Audio streamForDb = requiredAudioStream;

    final String actualDownformat = (requiredAudioStream.audioCodec == Codec.opus ||
            streamUrl.contains(".opus") ||
            downloadingFormat == "opus")
        ? "opus"
        : (streamUrl.contains(".mp3") ? "mp3" : "m4a");

    final RegExp invalidChar = RegExp(r'[\\/:*?"<>|%!\n\r\t]');
    String cleanTitle = song.title.replaceAll(invalidChar, '_').trim();
    if (cleanTitle.length > 50) cleanTitle = cleanTitle.substring(0, 50).trim();
    String cleanArtist = (song.artist ?? '').replaceAll(invalidChar, '_').trim();
    if (cleanArtist.length > 30) cleanArtist = cleanArtist.substring(0, 30).trim();
    final fileName = cleanArtist.isNotEmpty
        ? "$cleanTitle ($cleanArtist).$actualDownformat"
        : "$cleanTitle.$actualDownformat";

    String dirPath = settingsScreenController.downloadLocationPath.string;
    if (dirPath.isEmpty) {
      dirPath = settingsScreenController.supportDirPath.isNotEmpty
          ? "${settingsScreenController.supportDirPath}/Music"
          : "";
    }

    Directory downloadDir = Directory(dirPath);
    bool canWrite = false;
    try {
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }
      // Test write permission on target directory
      final testFile = File("${downloadDir.path}/.perm_test");
      testFile.writeAsStringSync("ok");
      testFile.deleteSync();
      canWrite = true;
    } catch (_) {
      canWrite = false;
    }

    if (!canWrite) {
      final supportDir = settingsScreenController.supportDirPath;
      downloadDir = Directory("$supportDir/Music");
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }
    }

    final String filePath = "${downloadDir.path}/$fileName";
    printINFO("Downloading filePath: $filePath from stream: ${streamUrl.substring(0, min(60, streamUrl.length))}...");

    final downloadHeaders = <String, String>{
      'accept': '*/*',
      'accept-encoding': 'gzip, deflate',
    };
    if (streamUrl.contains('googlevideo.com')) {
      downloadHeaders['User-Agent'] = streamUrl.contains('c=IOS')
          ? 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)'
          : 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
    }

    Future<void> performDownload() async {
      if (streamUrl.contains('.m3u8') || streamUrl.contains('/stream/hls')) {
        // Download and assemble HLS stream segments directly into audio file
        final m3u8Res = await _dio.get(streamUrl,
            options: Options(headers: downloadHeaders));
        final lines = m3u8Res.data.toString().split('\n');
        String? initUrl;
        final segmentUrls = <String>[];
        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('#EXT-X-MAP:URI=')) {
            final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
            if (match != null) initUrl = match.group(1);
          } else if (line.isNotEmpty && !line.startsWith('#')) {
            segmentUrls.add(line);
          }
        }
        final file = File(filePath);
        final sink = file.openWrite();
        try {
          if (initUrl != null) {
            final initRes = await _dio.get<List<int>>(initUrl,
                options: Options(
                    responseType: ResponseType.bytes, headers: downloadHeaders));
            if (initRes.data != null) sink.add(initRes.data!);
          }
          final total = segmentUrls.length;
          for (var i = 0; i < total; i++) {
            final segRes = await _dio.get<List<int>>(segmentUrls[i],
                options: Options(
                    responseType: ResponseType.bytes, headers: downloadHeaders));
            if (segRes.data != null) sink.add(segRes.data!);
            if (total > 0) {
              songDownloadingProgress.value = (((i + 1) / total) * 100).toInt();
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      } else {
        await _dio.download(
          streamUrl,
          filePath,
          options: Options(
            receiveTimeout: const Duration(minutes: 5),
            headers: downloadHeaders,
          ),
          onReceiveProgress: (count, total) {
            if (total <= 0) return;
            songDownloadingProgress.value = ((count / total) * 100).toInt();
          },
        );
      }
    }

    performDownload().then(
      (_) async {
        printINFO("Download completed for: $filePath");

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
        final streamInfoJson = streamForDb.toJson();
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
        printERROR("Download failed for '${song.title}' (${song.id}): $error");
        if (Get.context != null) {
          final is403 = error.toString().contains("403");
          final msg = is403
              ? "Download blockiert (HTTP 403). Stream wird aktualisiert, bitte erneut versuchen."
              : "downloadError3".tr;
          ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
              Get.context!, msg,
              size: SanckBarSize.BIG,
              duration: const Duration(seconds: 3),
              top: !GetPlatform.isDesktop));
        }
        complete.complete();
      },
    );

    return complete.future;
  }
}
