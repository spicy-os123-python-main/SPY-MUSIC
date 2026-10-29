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

  /// Each client gets its own attempt. Android & iOS clients
  /// return pure audio streams reliably.
  static Future<StreamManifest> _manifestWithClients(
      YoutubeExplode yt, String videoId) async {
    final clients = <String, YoutubeApiClient>{
      'android': YoutubeApiClient.android,
      'ios': YoutubeApiClient.ios,
      'androidSdkless': YoutubeApiClient.androidSdkless,
      'tv': YoutubeApiClient.tv,
      'androidVr': YoutubeApiClient.androidVr,
    };
    final watch = Stopwatch()..start();
    Object? lastError;
    StreamManifest? fallbackManifest;

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
        if (manifest.audioOnly.isNotEmpty) {
          printINFO(
              "YouTube client ${entry.key} returned ${manifest.audioOnly.length} pure audio streams for $videoId");
          return manifest;
        }
        if (manifest.streams.isNotEmpty && fallbackManifest == null) {
          fallbackManifest = manifest;
        }
      } catch (e) {
        lastError = e;
        printERROR("YouTube client ${entry.key} failed for $videoId: $e");
      }
    }
    if (fallbackManifest != null) {
      return fallbackManifest;
    }
    throw lastError ??
        VideoUnavailableException('No YouTube client returned audio for $videoId');
  }

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      final res = await _manifestWithClients(yt, videoId);
      final List<Audio> formats = [];

      // 1. Add pure standalone audio streams (STRICTLY NO VIDEO DATA!)
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

      // 2. Also add itag 18 muxed stream as reliable fallback so formats is never empty and playback never fails
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

      if (formats.isEmpty) {
        throw VideoUnavailableException(
            'Keine abspielbaren Audio-Streams für $videoId gefunden');
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
    if (audioFormats == null || audioFormats!.isEmpty) return null;

    // 1. Standard pure AAC 128k (itag 140): ~3.5MB per track, 100% stable across Android & iOS,
    // saves ~87% data compared to video streams without any playback issues.
    final aac140 = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;

    // 2. High-bitrate Opus (itag 251 ~160k)
    final highOpus = audioFormats!.firstWhereOrNull((item) => item.itag == 251);
    if (highOpus != null) return highOpus;

    // 3. Any pure AAC audio stream (e.g. itag 139)
    final otherAac = audioFormats!.firstWhereOrNull(
        (item) => item.audioCodec == Codec.mp4a && item.itag != 18);
    if (otherAac != null) return otherAac;

    // 4. Rate-bypass muxed stream (itag 18) as fallback
    final rateBypass = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    final sorted = List<Audio>.from(audioFormats!)
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return sorted.first;
  }

  Audio? get highestBitrateMp4aAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final aac140 = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;
    final aac139 = audioFormats!.firstWhereOrNull((item) => item.itag == 139);
    if (aac139 != null) return aac139;
    return audioFormats!
            .firstWhereOrNull((item) => item.audioCodec == Codec.mp4a) ??
        audioFormats!.first;
  }

  Audio? get highestBitrateOpusAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final op251 = audioFormats!.firstWhereOrNull((item) => item.itag == 251);
    if (op251 != null) return op251;
    final op250 = audioFormats!.firstWhereOrNull((item) => item.itag == 250);
    if (op250 != null) return op250;
    final op249 = audioFormats!.firstWhereOrNull((item) => item.itag == 249);
    if (op249 != null) return op249;
    return audioFormats!
            .firstWhereOrNull((item) => item.audioCodec == Codec.opus) ??
        audioFormats!.first;
  }

  Audio? get lowQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;

    // Ultra Data Saver (-85% to -96% data savings):
    // 1. Low-bitrate AAC (itag 139 ~48 kbps, ~1.2 MB per track)
    final lowAac = audioFormats!.firstWhereOrNull((item) => item.itag == 139);
    if (lowAac != null) return lowAac;

    // 2. Opus itag 250 (~70 kbps, ~1.6 MB) or itag 249 (~50 kbps, ~1.2 MB)
    final cleanOpus =
        audioFormats!.firstWhereOrNull((item) => item.itag == 250) ??
            audioFormats!.firstWhereOrNull((item) => item.itag == 249);
    if (cleanOpus != null) return cleanOpus;

    // 3. Fallback to standard AAC 128k (itag 140 ~3.5 MB)
    final aac140 = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;

    // 4. Fallback to any audio stream <= 96 kbps
    final anyLow = audioFormats!
        .firstWhereOrNull((item) => item.bitrate > 0 && item.bitrate <= 96000);
    if (anyLow != null) return anyLow;

    // 5. Lowest bitrate available
    final sorted = List<Audio>.from(audioFormats!)
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
    return sorted.first;
  }

  Audio? get midQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;

    // Mid Data Saver:
    // 1. Prefer itag 140 (AAC ~128 kbps) or itag 250 (Opus ~70 kbps)
    final midAac = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (midAac != null) return midAac;

    final midOpus = audioFormats!.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    return lowQualityAudio;
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
