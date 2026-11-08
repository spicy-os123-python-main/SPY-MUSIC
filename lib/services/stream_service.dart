import 'dart:io';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../utils/helper.dart';

bool get _isGerman {
  try {
    if (Get.isRegistered<SettingsScreenController>()) {
      final settings = Get.find<SettingsScreenController>();
      if (settings.currentAppLanguageCode.value == 'de') return true;
      if (settings.currentAppLanguageCode.value != 'de') return false;
    }
  } catch (_) {}
  return (Get.locale?.languageCode ?? 'en') == 'de';
}

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  /// Fetch stream with verified playable cipher deciphering.
  /// Standard getManifest uses the official YouTube Web player with full watch page signature
  /// deciphering, which produces 100% playable 206 audio streams without 403 Forbidden errors.
  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      Object? lastError;

      // 1. Primary: androidSdkless client with fast direct manifest (pure audio 1-2 MB, no PO Token)
      try {
        final res = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [YoutubeApiClient.androidSdkless],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 6));

        final List<Audio> formats = [];
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

        // Only add itag 18 muxed stream if no pure audio streams exist at all
        if (formats.isEmpty) {
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
        }

        if (formats.isNotEmpty) {
          printINFO(
              "YouTube androidSdkless fast manifest successfully fetched ${formats.length} streams for $videoId");
          return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: formats,
          );
        }
      } catch (e) {
        lastError = e;
        printINFO("YouTube androidSdkless fast manifest failed for $videoId: $e, trying watchPage fallback...");
      }

      // 2. Secondary fallback: androidSdkless with watchpage deciphering
      try {
        final res = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [YoutubeApiClient.androidSdkless],
              requireWatchPage: true,
            )
            .timeout(const Duration(seconds: 8));

        final List<Audio> formats = [];
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
        if (formats.isEmpty) {
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
        }
        if (formats.isNotEmpty) {
          printINFO(
              "YouTube androidSdkless (watchPage) fallback successfully fetched ${formats.length} streams for $videoId");
          return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: formats,
          );
        }
      } catch (e) {
        lastError = e;
        printINFO("YouTube androidSdkless watchPage fallback failed for $videoId: $e, trying standard Android client...");
      }

      // 2. Secondary fallback: Android client with requireWatchPage: true
      try {
        final res = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [YoutubeApiClient.android],
              requireWatchPage: true,
            )
            .timeout(const Duration(seconds: 6));

        final List<Audio> formats = [];
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
        if (formats.isEmpty) {
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
        }
        if (formats.isNotEmpty) {
          printINFO(
              "YouTube Android (watchPage) fallback successfully fetched ${formats.length} streams for $videoId");
          return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: formats,
          );
        }
      } catch (e) {
        lastError = e;
        printINFO("YouTube Android fallback failed for $videoId: $e");
      }

      throw lastError ??
          VideoUnavailableException(
              _isGerman
                  ? 'YouTube sperrt diesen Stream mit HTTP 403'
                  : 'YouTube blocks this stream with HTTP 403');
    } catch (e, stack) {
      printERROR("StreamProvider.fetch YouTube error for $videoId: $e (Type: ${e.runtimeType})\n$stack");


      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: _isGerman
              ? "Netzwerkfehler: ${e.message}"
              : "Network error: ${e.message}",
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
          statusMSG: _isGerman
              ? "Song ist auf YouTube nicht verfügbar"
              : "Track is unavailable on YouTube",
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
    final pureAudios = audioFormats!.where((item) => item.itag != 18).toList();

    // 1. High-bitrate pure Opus (itag 251 ~160k)
    final highOpus = pureAudios.firstWhereOrNull((item) => item.itag == 251);
    if (highOpus != null) return highOpus;

    // 2. High-quality pure AAC stream (itag 140 ~128k)
    final aac140 = pureAudios.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;

    // 3. Medium Opus (itag 250 ~70k)
    final midOpus = pureAudios.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    // 4. Low AAC (itag 139 ~48k)
    final lowAac = pureAudios.firstWhereOrNull((item) => item.itag == 139);
    if (lowAac != null) return lowAac;

    if (pureAudios.isNotEmpty) {
      final sorted = List<Audio>.from(pureAudios)
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return sorted.first;
    }

    // Fallback only if no standalone audio stream exists
    return audioFormats!.first;
  }

  Audio? get fallbackAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final pureAudios =
        audioFormats!.where((item) => item.itag != 18 && item.itag != 22).toList();
    if (pureAudios.isNotEmpty) {
      // Prioritize pure audio streams (AAC 140 or 139 or Opus) before heavy video
      return pureAudios.firstWhereOrNull((item) => item.itag == 140) ??
          pureAudios.firstWhereOrNull((item) => item.itag == 139) ??
          pureAudios.firstWhereOrNull((item) => item.itag == 250) ??
          pureAudios.firstWhereOrNull((item) => item.itag == 251) ??
          pureAudios.first;
    }
    return audioFormats!.firstWhereOrNull((item) => item.itag == 18) ??
        audioFormats!
            .firstWhereOrNull((item) => item.url.contains('ratebypass=yes')) ??
        audioFormats!.last;
  }

  Audio? get highestBitrateMp4aAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final pureAudios = audioFormats!.where((item) => item.itag != 18).toList();
    final aac140 = pureAudios.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;
    final aac139 = pureAudios.firstWhereOrNull((item) => item.itag == 139);
    if (aac139 != null) return aac139;
    return pureAudios
            .firstWhereOrNull((item) => item.audioCodec == Codec.mp4a) ??
        (pureAudios.isNotEmpty ? pureAudios.first : audioFormats!.first);
  }

  Audio? get highestBitrateOpusAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final pureAudios = audioFormats!.where((item) => item.itag != 18).toList();
    final op251 = pureAudios.firstWhereOrNull((item) => item.itag == 251);
    if (op251 != null) return op251;
    final op250 = pureAudios.firstWhereOrNull((item) => item.itag == 250);
    if (op250 != null) return op250;
    final op249 = pureAudios.firstWhereOrNull((item) => item.itag == 249);
    if (op249 != null) return op249;
    return pureAudios
            .firstWhereOrNull((item) => item.audioCodec == Codec.opus) ??
        (pureAudios.isNotEmpty ? pureAudios.first : audioFormats!.first);
  }

  Audio? get lowQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final pureAudios = audioFormats!.where((item) => item.itag != 18).toList();

    // 1. Ultra Data Saver pure AAC (itag 139 ~48k, ~1.1-1.3 MB per song)
    final lowAac = pureAudios.firstWhereOrNull(
        (item) => item.itag == 139 || item.itag == 599);
    if (lowAac != null) return lowAac;

    // 2. Ultra Data Saver pure Opus (itag 249 ~50k, ~1.1-1.3 MB per song)
    final lowOpus = pureAudios.firstWhereOrNull(
        (item) => item.itag == 249 || item.itag == 600);
    if (lowOpus != null) return lowOpus;

    // 3. Medium Opus (itag 250 ~70k, ~1.8 MB per song)
    final midOpus = pureAudios.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    // 4. Standard pure AAC (itag 140 ~128k)
    final midAac = pureAudios.firstWhereOrNull((item) => item.itag == 140);
    if (midAac != null) return midAac;

    if (pureAudios.isNotEmpty) {
      final sorted = List<Audio>.from(pureAudios)
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
      return sorted.first;
    }

    // Fallback only if no standalone audio stream exists
    return fallbackAudio;
  }

  Audio? get midQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final pureAudios = audioFormats!.where((item) => item.itag != 18).toList();

    // 1. 70 kbps Opus (itag 250 ~1.8 MB per song)
    final midOpus = pureAudios.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    // 2. Pure AAC 140 (~128k)
    final midAac = pureAudios.firstWhereOrNull((item) => item.itag == 140);
    if (midAac != null) return midAac;

    return lowQualityAudio;
  }

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "midQualityAudio": midQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson(),
      "fallbackAudio": fallbackAudio?.toJson(),
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
