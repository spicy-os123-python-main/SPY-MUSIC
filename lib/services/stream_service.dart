import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/helper.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  /// Each client gets its own attempt. Android clients (androidSdkless, android)
  /// return muxed and audio streams reliably with ratebypass.
  static Future<StreamManifest> _manifestWithClients(
      YoutubeExplode yt, String videoId) async {
    final clients = <String, YoutubeApiClient>{
      'androidSdkless': YoutubeApiClient.androidSdkless,
      'android': YoutubeApiClient.android,
      'ios': YoutubeApiClient.ios,
      'tv': YoutubeApiClient.tv,
      'androidVr': YoutubeApiClient.androidVr,
    };
    final watch = Stopwatch()..start();
    Object? lastError;

    for (final entry in clients.entries) {
      if (watch.elapsed > const Duration(seconds: 14)) break;
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [entry.value],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 8));
        if (manifest.streams.isNotEmpty) {
          printINFO("YouTube client ${entry.key} worked for $videoId (${manifest.streams.length} streams)");
          return manifest;
        }
        printERROR("YouTube client ${entry.key} returned no streams for $videoId");
      } catch (e) {
        lastError = e;
        printERROR("YouTube client ${entry.key} failed for $videoId: $e");
      }
    }
    throw lastError ??
        VideoUnavailableException('No YouTube client returned audio for $videoId');
  }

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      final res = await _manifestWithClients(yt, videoId);
      final List<Audio> formats = [];

      // 1. Prioritize ratebypass muxed streams (itag 18 has AAC stereo audio and ratebypass=yes, immune to 403 blocks)
      for (final m in res.muxed) {
        if (m.tag == 18 || m.url.toString().contains('ratebypass=yes')) {
          formats.add(Audio(
            itag: m.tag,
            audioCodec: Codec.mp4a,
            bitrate: 128000,
            duration: 0,
            loudnessDb: 0.0,
            url: m.url.toString(),
            size: m.size.totalBytes,
          ));
        }
      }

      // 2. Also add standalone audio streams
      for (final a in res.audioOnly) {
        formats.add(Audio(
          itag: a.tag,
          audioCodec:
              a.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
          bitrate: a.bitrate.bitsPerSecond,
          duration: 0,
          loudnessDb: 0.0,
          url: a.url.toString(),
          size: a.size.totalBytes,
        ));
      }

      // Fallback: any other muxed stream if formats still empty
      if (formats.isEmpty && res.muxed.isNotEmpty) {
        final m = res.muxed.first;
        formats.add(Audio(
          itag: m.tag,
          audioCodec: Codec.mp4a,
          bitrate: 128000,
          duration: 0,
          loudnessDb: 0.0,
          url: m.url.toString(),
          size: m.size.totalBytes,
        ));
      }

      if (formats.isEmpty) {
        throw VideoUnavailableException('Keine abspielbaren Audio-Streams für $videoId gefunden');
      }

      return StreamProvider(
        playable: true,
        statusMSG: "OK",
        audioFormats: formats,
      );
    } catch (e, stack) {
      printERROR("StreamProvider.fetch YouTube error for $videoId: $e (Type: ${e.runtimeType})\n$stack");


      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Netzwerkfehler: ${e.message}",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song ist auf YouTube nicht verfügbar",
        );
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: e.toString(),
        );
      }
    } finally {
      yt.close();
    }
  }



  static Future<String?> getVideoUrl(String videoId) async {
    final cleanId = videoId.replaceAll("MPED", "").trim();
    if (cleanId.startsWith("sc_") ||
        cleanId.startsWith("sp_") ||
        cleanId.startsWith("az_")) {
      return null;
    }
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        cleanId,
        ytClients: [
          YoutubeApiClient.androidSdkless,
          YoutubeApiClient.android,
        ],
        requireWatchPage: false,
      );
      final muxed = manifest.muxed;
      if (muxed.isNotEmpty) {
        return muxed.withHighestBitrate().url.toString();
      }
      final videoOnly = manifest.videoOnly;
      if (videoOnly.isNotEmpty) {
        return videoOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      printERROR("getVideoUrl failed for $cleanId: $e");
    } finally {
      yt.close();
    }
    return null;
  }

  Audio? get highestQualityAudio {
    final rateBypass = audioFormats?.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    return audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
        orElse: () => audioFormats!.first);
  }

  Audio? get highestBitrateMp4aAudio {
    final rateBypass = audioFormats?.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    return audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
        orElse: () => audioFormats!.first);
  }

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio {
    final rateBypass = audioFormats?.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    return audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
        orElse: () => audioFormats!.first);
  }

  Audio? get midQualityAudio {
    final rateBypass = audioFormats?.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    return audioFormats?.lastWhere(
        (item) => item.itag == 250 || item.itag == 140,
        orElse: () => lowQualityAudio ?? audioFormats!.first);
  }

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "midQualityAudio": midQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
