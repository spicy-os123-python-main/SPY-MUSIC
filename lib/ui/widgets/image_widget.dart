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
    } catch (_) {}
    final bool isDataSaver = dataSaverMode > 0;
    final bool isUltraSaver = dataSaverMode == 2;

    final finalImageUrl = _optimizeThumbnailUrl(imageUrl, isPlayerArtImage,
        isDataSaver: isDataSaver, isUltraSaver: isUltraSaver);
    final uri = Uri.tryParse(finalImageUrl);
    final bool hasValidNetworkUrl = finalImageUrl.isNotEmpty &&
        finalImageUrl != "null" &&
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (hasValidNetworkUrl) {
      final estimatedBytes = isPlayerArtImage
          ? (isUltraSaver ? 35 * 1024 : (isDataSaver ? 60 * 1024 : 140 * 1024))
          : (isDataSaver ? 9 * 1024 : 18 * 1024);
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

    /// only valid for offline songs
    final bool offlineAvailable =
        song != null && (song?.extras?["url"] ?? "").contains("file");

    final int? diskCacheLimit = isPlayerArtImage
        ? (isUltraSaver ? 320 : (isDataSaver ? 500 : null))
        : (isDataSaver ? 100 : 160);
    final int? memCacheLimit = isPlayerArtImage
        ? (isUltraSaver ? 300 : (isDataSaver ? 450 : null))
        : (isDataSaver ? 90 : 140);

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
      child: offlineAvailable
          ? Image.file(
              File(
                  "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${song!.id}.png"),
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

  static String _optimizeThumbnailUrl(String url, bool isPlayerArtImage,
      {bool isDataSaver = false, bool isUltraSaver = false}) {
    if (url.isEmpty) return url;

    if (isPlayerArtImage) {
      if (isUltraSaver) {
        if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
          return url
              .replaceAll('/maxresdefault.jpg', '/mqdefault.jpg')
              .replaceAll('/hq720.jpg', '/mqdefault.jpg')
              .replaceAll('/sddefault.jpg', '/mqdefault.jpg');
        }
        if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
          final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
          if (sizeRegex.hasMatch(url)) {
            return url.replaceAll(sizeRegex, '=w320-h320-l80-rj');
          }
        }
      } else if (isDataSaver) {
        if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
          return url
              .replaceAll('/maxresdefault.jpg', '/hqdefault.jpg')
              .replaceAll('/hq720.jpg', '/hqdefault.jpg');
        }
        if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
          final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
          if (sizeRegex.hasMatch(url)) {
            return url.replaceAll(sizeRegex, '=w500-h500-l80-rj');
          }
        }
      }
      return url;
    }

    // List thumbnails (save massive mobile data during browsing!)
    // YouTube Video thumbnail (save up to 2MB per track!)
    if (url.contains('i.ytimg.com/vi/') || url.contains('img.youtube.com/vi/')) {
      return url
          .replaceAll('/maxresdefault.jpg', '/mqdefault.jpg')
          .replaceAll('/hq720.jpg', '/mqdefault.jpg')
          .replaceAll('/sddefault.jpg', '/mqdefault.jpg')
          .replaceAll('/hqdefault.jpg', '/mqdefault.jpg');
    }

    // Google User Content / YouTube Music thumbnails
    if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
      final sizeRegex = RegExp(r'=(?:w\d+-h\d+|s\d+)(-[^=]*)?$');
      if (sizeRegex.hasMatch(url)) {
        return url.replaceAll(
            sizeRegex, isDataSaver ? '=w90-h90-l80-rj' : '=w140-h140-l80-rj');
      }
    }

    // SoundCloud track covers
    if (url.contains('sndcdn.com')) {
      return url
          .replaceAll('-t500x500.jpg', '-large.jpg')
          .replaceAll('-original.jpg', '-large.jpg')
          .replaceAll('-t300x300.jpg', '-large.jpg');
    }

    // Spotify image resizing
    if (url.contains('i.scdn.co/image/ab67616d0000b273')) {
      return url.replaceAll('ab67616d0000b273', 'ab67616d00001e02');
    }

    return url;
  }
}
