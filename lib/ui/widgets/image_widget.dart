import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/data_usage_tracker.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '/models/artist.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';

class ImageWidget extends StatelessWidget {
  const ImageWidget({
    super.key,
    this.song,
    this.playlist,
    this.album,
    this.artist,
    required this.size,
    this.isPlayerArtImage = false,
  });
  final MediaItem? song;
  final Playlist? playlist;
  final Album? album;
  final bool isPlayerArtImage;
  final Artist? artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    String imageUrl = song != null
        ? (song?.artUri?.toString() ?? "")
        : playlist != null
            ? (playlist?.thumbnailUrl ?? "")
            : album != null
                ? (album?.thumbnailUrl ?? "")
                : artist != null
                    ? (artist?.thumbnailUrl ?? "")
                    : "";

    int dataSaverMode = 0;
    try {
      final val = Hive.box('AppPrefs').get('dataSaverMode', defaultValue: 0);
      if (val is int) dataSaverMode = val;
      final qVal = Hive.box('AppPrefs').get('streamingQuality', defaultValue: 0);
      if (qVal is int && qVal > dataSaverMode) dataSaverMode = qVal;
    } catch (_) {}
    final bool isDataSaver = dataSaverMode > 0;
    final bool isUltraSaver = dataSaverMode == 2;

    final finalImageUrl = optimizeThumbnailUrl(imageUrl, isPlayerArtImage,
        isDataSaver: isDataSaver, isUltraSaver: isUltraSaver, displaySize: size);
    final uri = Uri.tryParse(finalImageUrl);
    final bool hasValidNetworkUrl = finalImageUrl.isNotEmpty &&
        finalImageUrl != "null" &&
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    final String supportDir = Get.isRegistered<SettingsScreenController>()
        ? Get.find<SettingsScreenController>().supportDirPath
        : '';
    final File localThumbFile = (song != null && supportDir.isNotEmpty)
        ? File("$supportDir/thumbnails/${song!.id}.png")
        : File("");
    final bool hasLocalThumb = localThumbFile.path.isNotEmpty &&
        localThumbFile.existsSync() &&
        localThumbFile.lengthSync() > 100;

    final bool isDownloaded =
        song != null && Hive.box("SongDownloads").containsKey(song!.id);
    final bool isArtUriLocal =
        song?.artUri?.toString().startsWith("file:") ?? false;

    /// only valid for offline songs
    final bool offlineAvailable = hasLocalThumb ||
        isArtUriLocal ||
        (song != null && (song?.extras?["url"] ?? "").contains("file")) ||
        isDownloaded;

    if (hasValidNetworkUrl &&
        !offlineAvailable &&
        !hasLocalThumb &&
        !isArtUriLocal) {
      final estimatedBytes = isPlayerArtImage
          ? (isUltraSaver
              ? 95 * 1024
              : (isDataSaver ? 110 * 1024 : 180 * 1024))
          : (isUltraSaver ? 5 * 1024 : (isDataSaver ? 9 * 1024 : 18 * 1024));
      DataUsageTracker.instance.recordImageLoad(
        url: finalImageUrl,
        estimatedBytes: estimatedBytes,
      );
    }

    final Widget placeholderWidget = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: artist != null ? null : BorderRadius.circular(10),
      ),
      child: Image.asset(
          "assets/icons/${song != null ? "song" : artist != null ? "artist" : "album"}.png"),
    );

    final int diskCacheLimit = isPlayerArtImage
        ? 720
        : (isUltraSaver ? 180 : (isDataSaver ? 220 : 300));
    final int memCacheLimit = isPlayerArtImage
        ? 720
        : (isUltraSaver ? 144 : (isDataSaver ? 180 : 260));

    return Container(
      height: size,
      width: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: artist != null
            ? null
            : BorderRadius.circular(isPlayerArtImage ? 18 : 10),
        boxShadow: isPlayerArtImage
            ? [
                BoxShadow(
                  color: const Color(0xFFFF0055).withOpacity(0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF00D2FF).withOpacity(0.35),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: hasLocalThumb
          ? Image.file(
              localThumbFile,
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholderWidget,
            )
          : isArtUriLocal && song?.artUri != null
              ? Image.file(
                  File(song!.artUri!.toFilePath()),
                  height: size,
                  width: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholderWidget,
                )
              : (hasValidNetworkUrl
              ? CachedNetworkImage(
                  height: size,
                  width: size,
                  maxWidthDiskCache: diskCacheLimit,
                  maxHeightDiskCache: diskCacheLimit,
                  memCacheWidth: memCacheLimit,
                  memCacheHeight: memCacheLimit,
                  imageUrl: finalImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => placeholderWidget,
                  progressIndicatorBuilder: ((_, __, ___) => Shimmer.fromColors(
                      baseColor: Colors.grey[500]!,
                      highlightColor: Colors.grey[300]!,
                      enabled: true,
                      direction: ShimmerDirection.ltr,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: artist != null
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                          borderRadius:
                              artist != null ? null : BorderRadius.circular(10),
                          color: Colors.white54,
                        ),
                      ))),
                )
              : placeholderWidget),
    );
  }

  static String optimizeThumbnailUrl(String url, bool isPlayerArtImage,
      {bool isDataSaver = false,
      bool isUltraSaver = false,
      double? displaySize}) {
    if (url.isEmpty) return url;

    // 1. Full Player Screen Cover Artwork ("richtigen bilder in 720p wenn man das bild so sieht")
    if (isPlayerArtImage) {
      if (isUltraSaver || isDataSaver) {
        // Enforce clean 720p HD (saves ~95% data vs uncompressed 4K maxresdefault while looking crisp)
        if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
          return url
              .replaceAll('/maxresdefault.jpg', '/hq720.jpg')
              .replaceAll('/sddefault.jpg', '/hq720.jpg')
              .replaceAll('/mqdefault.jpg', '/hq720.jpg')
              .replaceAll('/default.jpg', '/hq720.jpg');
        }
        if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
          final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
          if (sizeRegex.hasMatch(url)) {
            return url.replaceAll(sizeRegex, '=w720-h720-l80-rj');
          }
        }
        if (url.contains('sndcdn.com')) {
          return url
              .replaceAll('-large.jpg', '-t500x500.jpg')
              .replaceAll('-original.jpg', '-t500x500.jpg');
        }
      }
      return url;
    }

    // 2. Track / Song Thumbnails in Lists, Search, Library, Miniplayer ("titel bildern in 240p oder 144p")
    if (isUltraSaver) {
      // 85% Data Saver Mode: 240p (mqdefault ~8KB) or 144p (default ~3KB for small tiles)
      final bool use144p = (displaySize != null && displaySize <= 65);

      if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
        final targetFormat = use144p ? '/default.jpg' : '/mqdefault.jpg';
        return url
            .replaceAll('/maxresdefault.jpg', targetFormat)
            .replaceAll('/hq720.jpg', targetFormat)
            .replaceAll('/sddefault.jpg', targetFormat)
            .replaceAll('/hqdefault.jpg', targetFormat)
            .replaceAll('/mqdefault.jpg', targetFormat);
      }

      if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
        final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
        if (sizeRegex.hasMatch(url)) {
          return url.replaceAll(
              sizeRegex, use144p ? '=w120-h120-l80-rj' : '=w180-h180-l80-rj');
        }
      }

      if (url.contains('sndcdn.com')) {
        return url
            .replaceAll('-t500x500.jpg', '-large.jpg')
            .replaceAll('-original.jpg', '-large.jpg')
            .replaceAll('-t300x300.jpg', '-large.jpg');
      }

      if (url.contains('i.scdn.co/image/ab67616d0000b273')) {
        return url.replaceAll('ab67616d0000b273',
            use144p ? 'ab67616d00004851' : 'ab67616d00001e02');
      }

      return url;
    }

    // Standard list optimization (saves massive mobile data during browsing)
    if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
      return url
          .replaceAll('/maxresdefault.jpg', '/mqdefault.jpg')
          .replaceAll('/hq720.jpg', '/mqdefault.jpg')
          .replaceAll('/sddefault.jpg', '/mqdefault.jpg')
          .replaceAll('/hqdefault.jpg', '/mqdefault.jpg');
    }

    if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
      final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
      if (sizeRegex.hasMatch(url)) {
        return url.replaceAll(
            sizeRegex, isDataSaver ? '=w120-h120-l80-rj' : '=w180-h180-l80-rj');
      }
    }

    if (url.contains('sndcdn.com')) {
      return url
          .replaceAll('-t500x500.jpg', '-large.jpg')
          .replaceAll('-original.jpg', '-large.jpg')
          .replaceAll('-t300x300.jpg', '-large.jpg');
    }

    if (url.contains('i.scdn.co/image/ab67616d0000b273')) {
      return url.replaceAll('ab67616d0000b273', 'ab67616d00001e02');
    }

    return url;
  }
}
