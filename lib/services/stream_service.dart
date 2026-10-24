import 'dart:io';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/helper.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  /// Each client gets its own short attempt. The library retries a failing
  /// client up to five times, so a single dead client used to eat the whole
  /// time budget before the next one was even tried.
  static Future<StreamManifest> _manifestWithClients(
      YoutubeExplode yt, String videoId) async {
    final clients = <String, YoutubeApiClient>{
      'androidSdkless': YoutubeApiClient.androidSdkless,
      'androidVr': YoutubeApiClient.androidVr,
      'ios': YoutubeApiClient.ios,
      'androidMusic': YoutubeApiClient.androidMusic,
    };
    final watch = Stopwatch()..start();
    Object? lastError;

    for (final entry in clients.entries) {
      if (watch.elapsed > const Duration(seconds: 8)) break;
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [entry.value],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 4));
        if (manifest.audioOnly.isNotEmpty) {
          printINFO("YouTube client ${entry.key} worked for $videoId");
          return manifest;
        }
        printERROR("YouTube client ${entry.key} returned no audio for $videoId");
      } catch (e) {
        lastError = e;
        printERROR("YouTube client ${entry.key} failed for $videoId: $e");
      }
    }
    throw lastError ??
        VideoUnavailableException('No YouTube client returned audio for $videoId');
  }

  static Future<StreamProvider> fetch(String videoId, {List<String>? pipedInstances}) async {
    final yt = YoutubeExplode();

    try {
      final res = await _manifestWithClients(yt, videoId);
      final audio = res.audioOnly;
      return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: audio
              .map((e) => Audio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: 0,
                  loudnessDb: 0.0,
                  url: e.url.toString(),
                  size: e.size.totalBytes))
              .toList());
    } catch (e, stack) {
      printERROR("StreamProvider.fetch YouTube error for $videoId: $e (Type: ${e.runtimeType})\n$stack");

      // Robust Fallback: try fallback stream APIs (Piped instances)
      final fallbackResult = await _fetchFromPiped(videoId,
              pipedInstances: pipedInstances)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (fallbackResult != null && fallbackResult.playable) {
        return fallbackResult;
      }

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

  /// Fallback stream provider using configurable/decentralized Piped endpoints (max 2 instances, 3s timeout)
  static Future<StreamProvider?> _fetchFromPiped(String videoId, {List<String>? pipedInstances}) async {
    final cleanId = videoId.replaceAll("MPED", "").trim();
    List<String> instances;
    if (pipedInstances != null && pipedInstances.isNotEmpty) {
      instances = pipedInstances.take(2).toList();
    } else {
      instances = [
        "https://pipedapi.adminforge.de",
        "https://api.piped.private.coffee",
      ];
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );

    for (final host in instances) {
      try {
        final res = await dio.get("$host/streams/$cleanId");
        final previewBody = res.data != null ? res.data.toString() : '';
        final truncated = previewBody.length > 150 ? '${previewBody.substring(0, 150)}...' : previewBody;
        printINFO("Piped [$host] status ${res.statusCode} for $cleanId: $truncated");

        if (res.statusCode == 200 && res.data != null) {
          final data = res.data;
          final audioList = data['audioStreams'] as List?;
          final int durSec = (data['duration'] is int) ? data['duration'] : 0;
          final int durMs = durSec * 1000;

          if (audioList != null && audioList.isNotEmpty) {
            final List<Audio> formats = [];
            for (var a in audioList) {
              final streamUrl = a['url']?.toString();
              if (streamUrl == null || streamUrl.isEmpty) continue;
              final codecStr = a['codec']?.toString().toLowerCase() ?? '';
              final isMp4 = codecStr.contains('mp') ||
                  (a['format']?.toString().toLowerCase().contains('m4a') ?? false);
              final bitrate = (a['bitrate'] is int)
                  ? a['bitrate'] as int
                  : int.tryParse(a['bitrate']?.toString() ?? '128000') ?? 128000;

              formats.add(Audio(
                itag: isMp4 ? 140 : 251,
                audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
                bitrate: bitrate,
                duration: durMs,
                loudnessDb: 0.0,
                url: streamUrl,
                size: (a['contentLength'] is int) ? a['contentLength'] as int : 0,
              ));
            }

            if (formats.isNotEmpty) {
              return StreamProvider(
                playable: true,
                statusMSG: "OK",
                audioFormats: formats,
              );
            }
          }
        }
      } catch (e) {
        if (e is DioException) {
          final sCode = e.response?.statusCode;
          final errBody = e.response?.data?.toString();
          final trunc = errBody != null ? (errBody.length > 100 ? errBody.substring(0, 100) : errBody) : 'none';
          printERROR("Piped [$host] failed [HTTP $sCode]: ${e.message}, body: $trunc");
        } else {
          printERROR("Piped [$host] failed: $e");
        }
      }
    }
    return null;
  }

  static Future<String?> getVideoUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.androidSdkless,
          YoutubeApiClient.androidMusic,
          YoutubeApiClient.ios,
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
      printERROR("getVideoUrl failed for $videoId: $e");
    } finally {
      yt.close();
    }
    return null;
  }

  Audio? get highestQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get midQualityAudio => audioFormats?.lastWhere(
      (item) => item.itag == 250 || item.itag == 140,
      orElse: () => lowQualityAudio ?? audioFormats!.first);

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
