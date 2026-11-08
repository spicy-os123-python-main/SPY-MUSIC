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

  /// Get intelligent fallback stream respecting Data Saver mode and avoiding heavy video streams
  Audio? getFallbackFor(Audio? currentAudio) {
    final currentUrl = currentAudio?.url;
    final currentItag = currentAudio?.itag;

    // Preference order based on qualityIndex
    final candidates = <Audio?>[];
    if (qualityIndex == 2) {
      // Ultra Data Saver: low -> mid -> high
      candidates.addAll([lowQualityAudio, midQualityAudio, highQualityAudio]);
    } else if (qualityIndex == 1) {
      // Mid Data Saver: mid -> low -> high
      candidates.addAll([midQualityAudio, lowQualityAudio, highQualityAudio]);
    } else {
      // Normal: high -> mid -> low
      candidates.addAll([highQualityAudio, midQualityAudio, lowQualityAudio]);
    }

    // Try candidates that are pure audio (not itag 18/22) and different from current
    for (final cand in candidates) {
      if (cand != null &&
          cand.url.isNotEmpty &&
          cand.url != currentUrl &&
          cand.itag != currentItag &&
          cand.itag != 18 &&
          cand.itag != 22) {
        return cand;
      }
    }

    // In Ultra Data Saver and Mid Data Saver mode, NEVER fall back to heavy video streams (itag 18 or 22)
    if (qualityIndex == 2 || qualityIndex == 1) {
      return null;
    }

    // Otherwise, as an absolute last resort, return fallbackAudio if different and not heavy video
    if (fallbackAudio != null &&
        fallbackAudio!.url != currentUrl &&
        fallbackAudio!.itag != 18 &&
        fallbackAudio!.itag != 22) {
      return fallbackAudio;
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
