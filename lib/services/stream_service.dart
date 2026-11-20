import 'dart:io';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../utils/helper.dart';
import 'audio_handler.dart';

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

  static List<Audio> _extractAudioFormats(StreamManifest res) {
    final List<Audio> formats = [];
    // 1. Pure audio streams (itag 250, 140, 251, 139, 249, etc.)
    for (final a in res.audioOnly) {
      formats.add(Audio(
        itag: a.tag,
        audioCodec: a.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
        bitrate: a.bitrate.bitsPerSecond,
        duration: 0,
        loudnessDb: 0.0,
        url: a.url.toString(),
        size: a.size.totalBytes,
      ));
    }
    // 2. Muxed streams only as emergency last resort
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
    return formats;
  }

  /// Validates an audio stream URL with a range request (bytes=0-1) using
  /// the exact same headers that the audio player uses. Returns true on HTTP 200 or 206.
  /// Rejects on explicit HTTP 401/403/404/410 block codes.
  static Future<bool> verifyStreamPlayable(String streamUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client
          .getUrl(Uri.parse(streamUrl))
          .timeout(const Duration(seconds: 4));
      req.headers.set('Range', 'bytes=0-1');
      final headers = MyAudioHandler.buildStreamHeaders(streamUrl);
      headers?.forEach((key, value) {
        req.headers.set(key, value);
      });
      final resp = await req.close().timeout(const Duration(seconds: 4));
      final status = resp.statusCode;
      await resp.drain().timeout(const Duration(seconds: 1)).catchError((_) {});
      if (status == 403 || status == 401 || status == 404 || status == 410) {
        return false;
      }
      return status == 200 || status == 206;
    } catch (e) {
      // On probe timeout or transient connection error during probe, do not fail
      // a stream that getManifest already returned.
      printINFO("Stream verification probe warning: $e");
      return true;
    } finally {
      client.close(force: true);
    }
  }

  /// Fetch stream with verified playable cipher deciphering.
  /// Iterates sequentially through clients with androidSdkless as primary fast path (<300ms, no bot gating):
  /// 1. androidSdkless, 2. androidVr, 3. android, 4. ios, 5. androidMusic, 6. mweb.
  /// Before returning, performs a Range-Request (bytes=0-1) with buildStreamHeaders.
  /// Only on HTTP 200/206 is the client considered successful, otherwise tries next client.
  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      Object? lastError;

      final clients = [
        ('androidSdkless', YoutubeApiClient.androidSdkless),
        ('androidVr', YoutubeApiClient.androidVr),
        ('android', YoutubeApiClient.android),
        ('ios', YoutubeApiClient.ios),
        ('androidMusic', YoutubeApiClient.androidMusic),
        ('mweb', YoutubeApiClient.mweb),
      ];

      for (final (name, client) in clients) {
        final sw = Stopwatch()..start();
        try {
          final manifest = await yt.videos.streamsClient
              .getManifest(
                videoId,
                ytClients: [client],
                requireWatchPage: false,
              )
              .timeout(const Duration(seconds: 4));
          sw.stop();

          final formats = _extractAudioFormats(manifest);
          if (formats.isNotEmpty) {
            final candidate = StreamProvider(
              playable: true,
              statusMSG: "OK",
              audioFormats: formats,
            );
            final testAudio = candidate.highestQualityAudio ?? formats.first;
            final isVerified = await verifyStreamPlayable(testAudio.url);
            if (isVerified) {
              printINFO(
                  "YouTube client '$name' succeeded in ${sw.elapsedMilliseconds}ms (${formats.length} streams, range verified) for $videoId");
              return candidate;
            } else {
              printINFO(
                  "YouTube client '$name' range check failed in ${sw.elapsedMilliseconds}ms (not 200/206), trying next client...");
              lastError = VideoUnavailableException(
                  "Client $name range check failed (HTTP 403 / non-206)");
            }
          } else {
            printINFO(
                "YouTube client '$name' returned 0 audio formats in ${sw.elapsedMilliseconds}ms for $videoId");
            lastError =
                VideoUnavailableException("Client $name returned 0 audio formats");
          }
        } catch (e) {
          sw.stop();
          lastError = e;
          printINFO(
              "YouTube client '$name' failed in ${sw.elapsedMilliseconds}ms for $videoId: [${e.runtimeType}] $e");
        }
      }

      // Secondary fallback with watchpage deciphering (for VEVO / age-restricted / signature cipher)
      try {
        final sw = Stopwatch()..start();
        final manifest = await yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [
                YoutubeApiClient.androidSdkless,
                YoutubeApiClient.android,
              ],
              requireWatchPage: true,
            )
            .timeout(const Duration(seconds: 5));
        sw.stop();

        final formats = _extractAudioFormats(manifest);
        if (formats.isNotEmpty) {
          printINFO(
              "YouTube watchpage deciphering succeeded in ${sw.elapsedMilliseconds}ms (${formats.length} streams) for $videoId");
          return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: formats,
          );
        }
      } catch (e) {
        printINFO("YouTube watchPage deciphering fallback failed for $videoId: $e");
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
          YoutubeApiClient.androidVr,
          YoutubeApiClient.androidSdkless,
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
      printERROR("getVideoUrl failed for $cleanId: $e");
    } finally {
      yt.close();
    }
    return null;
  }

  Audio? get highestQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;

    final pureAudio = audioFormats!
        .where((item) => item.itag != 18 && item.itag != 22)
        .toList();

    if (pureAudio.isEmpty) {
      return audioFormats!.firstWhereOrNull(
              (item) => item.itag == 18 || item.url.contains('ratebypass=yes')) ??
          audioFormats!.first;
    }

    // Strict 1-3 MB data limit per normal song (<= 3.25 MB)
    final targetSizeStreams =
        pureAudio.where((a) => a.size > 0 && a.size <= 3250000).toList();

    if (targetSizeStreams.isNotEmpty) {
      // 1. Transparent Opus 250 (~70k, ~1.5 - 2.2 MB per standard song)
      final op250 = targetSizeStreams.firstWhereOrNull((a) => a.itag == 250);
      if (op250 != null) return op250;

      // 2. High-quality AAC 140 (when <= 3.25 MB)
      final aac140 = targetSizeStreams.firstWhereOrNull((a) => a.itag == 140);
      if (aac140 != null) return aac140;

      // 3. High-quality Opus 251 (when <= 3.25 MB)
      final op251 = targetSizeStreams.firstWhereOrNull((a) => a.itag == 251);
      if (op251 != null) return op251;

      // 4. Low Opus 249 (~50k, ~1.2 - 1.6 MB)
      final op249 = targetSizeStreams.firstWhereOrNull((a) => a.itag == 249);
      if (op249 != null) return op249;

      // 5. Low AAC 139 (~48k, ~1.2 - 1.5 MB)
      final aac139 = targetSizeStreams.firstWhereOrNull((a) => a.itag == 139);
      if (aac139 != null) return aac139;

      targetSizeStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return targetSizeStreams.first;
    }

    // Fallback if song is very long and all streams exceed 3.25 MB:
    // Choose the most data-efficient pure audio format
    final midOpus = pureAudio.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    final lowOpus = pureAudio.firstWhereOrNull((item) => item.itag == 249);
    if (lowOpus != null) return lowOpus;

    final lowAac = pureAudio.firstWhereOrNull((item) => item.itag == 139);
    if (lowAac != null) return lowAac;

    final aac140 = pureAudio.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;

    final highOpus = pureAudio.firstWhereOrNull((item) => item.itag == 251);
    if (highOpus != null) return highOpus;

    return pureAudio.first;
  }

  Audio? get fallbackAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final primary = highestQualityAudio;
    final primaryItag = primary?.itag;
    final primaryUrl = primary?.url;

    // Pick an alternative pure audio format with different itag/url
    final altPure = audioFormats!.firstWhereOrNull(
        (a) => a.itag != 18 && a.itag != 22 && a.itag != primaryItag && a.url != primaryUrl);
    if (altPure != null) return altPure;

    // If no alternative pure audio, try any format with different itag/url
    final altAny = audioFormats!.firstWhereOrNull(
        (a) => a.itag != primaryItag && a.url != primaryUrl);
    if (altAny != null) return altAny;

    return audioFormats!.first;
  }

  Audio? get highestBitrateMp4aAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    // 1. Pure AAC 140
    final aac140 = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (aac140 != null) return aac140;
    // 2. Pure AAC 139
    final aac139 = audioFormats!.firstWhereOrNull((item) => item.itag == 139);
    if (aac139 != null) return aac139;
    // 3. Fallback to muxed stream if no pure aac
    final rateBypass = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;
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

    // 1. Ultra Data Saver pure AAC (itag 139 ~48k, ~1.1-1.3 MB per song, 0 video overhead)
    final lowAac = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 139 || item.itag == 599);
    if (lowAac != null) return lowAac;

    // 2. Ultra Data Saver pure Opus (itag 249 ~50k, ~1.1-1.3 MB per song, 0 video overhead)
    final lowOpus = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 249 || item.itag == 600);
    if (lowOpus != null) return lowOpus;

    // 3. Medium Opus (itag 250 ~70k, ~1.8 MB per song)
    final midOpus = audioFormats!.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    // 4. Standard pure AAC (itag 140 ~128k, ~3 MB)
    final midAac = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (midAac != null) return midAac;

    // 5. Emergency fallback only: muxed video stream (itag 18)
    final rateBypass = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

    return fallbackAudio;
  }

  Audio? get midQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;

    // 1. Pure AAC 140 (~128k, ~3 MB, 0 video overhead)
    final midAac = audioFormats!.firstWhereOrNull((item) => item.itag == 140);
    if (midAac != null) return midAac;

    // 2. 70 kbps Opus (itag 250 ~1.8 MB per song)
    final midOpus = audioFormats!.firstWhereOrNull((item) => item.itag == 250);
    if (midOpus != null) return midOpus;

    // 3. 160 kbps Opus (itag 251 ~3 MB per song)
    final highOpus = audioFormats!.firstWhereOrNull((item) => item.itag == 251);
    if (highOpus != null) return highOpus;

    // 4. Low AAC (itag 139)
    final lowAac = audioFormats!.firstWhereOrNull((item) => item.itag == 139);
    if (lowAac != null) return lowAac;

    // 5. Emergency fallback: muxed video stream (itag 18)
    final rateBypass = audioFormats!.firstWhereOrNull(
        (item) => item.itag == 18 || item.url.contains('ratebypass=yes'));
    if (rateBypass != null) return rateBypass;

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

  Map<String, dynamic> toJson() => hmStreamingData;
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
