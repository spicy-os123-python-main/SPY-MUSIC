import 'package:spymusic/services/stream_service.dart' show Audio;

class HMStreamingData {
  final bool playable;
  final String statusMSG;
  final Audio? lowQualityAudio;
  final Audio? midQualityAudio;
  final Audio? highQualityAudio;
  int qualityIndex = 0; // 0: Normal, 1: Mid, 2: Ultra

  HMStreamingData({
    required this.playable,
    required this.statusMSG,
    this.lowQualityAudio,
    this.midQualityAudio,
    this.highQualityAudio,
  });

  setQualityIndex(int index) {
    qualityIndex = index;
  }

  Audio? get audio {
    if (qualityIndex == 2) {
      // Ultra Data Saver
      return lowQualityAudio ?? midQualityAudio ?? highQualityAudio;
    } else if (qualityIndex == 1) {
      // Mid Data Saver
      return midQualityAudio ?? highQualityAudio ?? lowQualityAudio;
    } else {
      // Normal: Highest Quality (Default)
      return highQualityAudio ?? midQualityAudio ?? lowQualityAudio;
    }
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

    return HMStreamingData(
        playable: json['playable'],
        statusMSG: json['statusMSG'],
        lowQualityAudio: lowQualityAudio,
        midQualityAudio: midQualityAudio,
        highQualityAudio: highQualityAudio);
  }

  Map<String, dynamic> toJson() => {
        "playable": playable,
        "statusMSG": statusMSG,
        "lowQualityAudio": lowQualityAudio?.toJson(),
        "midQualityAudio": midQualityAudio?.toJson(),
        "highQualityAudio": highQualityAudio?.toJson(),
      };
}
