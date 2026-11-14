import 'dart:typed_data';

class DecodedAudio {
  final Uint8List data;
  final int channelCount;
  final int sampleRate;

  DecodedAudio({
    required this.data,
    required this.channelCount,
    required this.sampleRate,
  });
}

/// Resamples 16-bit PCM audio data using linear interpolation.
class AudioResampler {
  static DecodedAudio resample(DecodedAudio decodedAudio, int outputSampleRate) {
    if (decodedAudio.sampleRate == outputSampleRate) {
      return decodedAudio;
    }

    final inputData = decodedAudio.data;
    final byteData = ByteData.sublistView(inputData);
    final inputLength = inputData.length ~/ 2;
    if (inputLength == 0) {
      return DecodedAudio(
        data: Uint8List(0),
        channelCount: decodedAudio.channelCount,
        sampleRate: outputSampleRate,
      );
    }

    final inputSamples = Int16List(inputLength);
    for (int i = 0; i < inputLength; i++) {
      inputSamples[i] = byteData.getInt16(i * 2, Endian.little);
    }

    final ratio = outputSampleRate / decodedAudio.sampleRate;
    final outputLength = (inputSamples.length * ratio).toInt();
    final outputSamples = Int16List(outputLength);

    for (int i = 0; i < outputLength; i++) {
      final srcPos = i / ratio;
      final srcIndex = srcPos.toInt();
      final fraction = srcPos - srcIndex;

      int sample;
      if (srcIndex + 1 < inputSamples.length) {
        sample = (inputSamples[srcIndex] * (1.0 - fraction) +
                inputSamples[srcIndex + 1] * fraction)
            .toInt();
      } else {
        sample = inputSamples[srcIndex];
      }
      outputSamples[i] = sample.clamp(-32768, 32767);
    }

    final outputBytes = Uint8List(outputLength * 2);
    final outByteData = ByteData.sublistView(outputBytes);
    for (int i = 0; i < outputLength; i++) {
      outByteData.setInt16(i * 2, outputSamples[i], Endian.little);
    }

    return DecodedAudio(
      data: outputBytes,
      channelCount: decodedAudio.channelCount,
      sampleRate: outputSampleRate,
    );
  }
}
