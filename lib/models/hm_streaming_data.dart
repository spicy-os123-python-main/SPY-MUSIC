import 'package:spymusic/services/stream_service.dart' show Audio;

class HMStreamingData {
  final bool playable;
  final String statusMSG;
  final Audio? lowQualityAudio;
  final Audio? midQualityAudio;
  final Audio? highQualityAudio;
  final Audio? fallbackAudio;
  int qualityIndex = 0; // 0: Normal, 1: Mid, 2: Ultra

  HMStreamingData({
    required this.playable,
    required this.statusMSG,
    this.lowQualityAudio,
    this.midQualityAudio,
    this.highQualityAudio,
    this.fallbackAudio,
  });

  setQualityIndex(int index) {
    qualityIndex = index;
  }

  Audio? get audio {
    if (qualityIndex == 2) {
      // Ultra Data Saver
      return lowQualityAudio ?? midQualityAudio ?? highQualityAudio ?? fallbackAudio;
    } else if (qualityIndex == 1) {
      // Mid Data Saver
      return midQualityAudio ?? highQualityAudio ?? lowQualityAudio ?? fallbackAudio;
    } else {
      // Normal: Highest Quality (Default)
      return highQualityAudio ?? midQualityAudio ?? lowQualityAudio ?? fallbackAudio;
    }
  }

  /// Get intelligent fallback stream respecting unthrottled ratebypass stream
  Audio? getFallbackFor(Audio? currentAudio) {
    final currentUrl = currentAudio?.url;
    final currentItag = currentAudio?.itag;

    // 1. Guaranteed unthrottled fallback: fallbackAudio (itag 18 with ratebypass=yes)
    if (fallbackAudio != null &&
        fallbackAudio!.url.isNotEmpty &&
        fallbackAudio!.url != currentUrl) {
      return fallbackAudio;
    }

    // 2. Try any other format that has a different URL/itag
    final candidates = <Audio?>[];
    if (qualityIndex == 2) {
      candidates.addAll([lowQualityAudio, midQualityAudio, highQualityAudio]);
    } else if (qualityIndex == 1) {
      candidates.addAll([midQualityAudio, lowQualityAudio, highQualityAudio]);
    } else {
      candidates.addAll([highQualityAudio, midQualityAudio, lowQualityAudio]);
    }

    for (final cand in candidates) {
      if (cand != null &&
          cand.url.isNotEmpty &&
          cand.url != currentUrl &&
          cand.itag != currentItag) {
        return cand;
      }
    }

    return null;
  }

  factory HMStreamingData.fromJson(json) {
    if (!json['playable']) {
      return HMStreamingData(
        playable: false,
        statusMSG: json['statusMSG'],
      );
    }
    final lowQualityAudio = json['lowQualityAudio'] != null
        ? Audio.fromJson(json['lowQualityAudio'])
        : null;
    final midQualityAudio = json['midQualityAudio'] != null
        ? Audio.fromJson(json['midQualityAudio'])
        : null;
    final highQualityAudio = json['highQualityAudio'] != null
        ? Audio.fromJson(json['highQualityAudio'])
        : null;
    final fallbackAudio = json['fallbackAudio'] != null
        ? Audio.fromJson(json['fallbackAudio'])
        : null;

    return HMStreamingData(
        playable: json['playable'],
        statusMSG: json['statusMSG'],
        lowQualityAudio: lowQualityAudio,
        midQualityAudio: midQualityAudio,
        highQualityAudio: highQualityAudio,
        fallbackAudio: fallbackAudio);
  }

  Map<String, dynamic> toJson() => {
        "playable": playable,
        "statusMSG": statusMSG,
        "lowQualityAudio": lowQualityAudio?.toJson(),
        "midQualityAudio": midQualityAudio?.toJson(),
        "highQualityAudio": highQualityAudio?.toJson(),
        "fallbackAudio": fallbackAudio?.toJson(),
      };
}
