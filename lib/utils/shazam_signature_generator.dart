import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'crc32.dart';

class VibraSignature {
  static const int requiredSampleRate = 16000;

  /// Generates a Shazam signature from raw PCM audio data.
  /// [samples] Raw PCM audio data (mono, 16-bit signed little-endian, 16kHz)
  static String fromI16(Uint8List samples) {
    return ShazamSignatureGenerator.fromI16(samples);
  }
}

class ShazamSignatureGenerator {
  static const int sampleRate = 16000;
  static const int fftSize = 2048;
  static const int fftOutputSize = fftSize ~/ 2 + 1; // 1025
  static const int maxPeaks = 255;
  static const double maxTimeSeconds = 12.0;

  static const int ringBufSize = 256;

  static const int band250To520 = 0;
  static const int band520To1450 = 1;
  static const int band1450To3500 = 2;
  static const int band3500To5500 = 3;

  static final Float64List hanning = Float64List.fromList(
    List.generate(fftSize, (i) => 0.5 * (1.0 - cos(2.0 * pi * (i + 1) / 2049.0))),
  );

  static String fromI16(Uint8List samples) {
    if (samples.length < 2 || samples.length % 2 != 0) {
      throw ArgumentError("samples must be a non-empty byte array with even length (16-bit PCM)");
    }
    final byteData = ByteData.sublistView(samples);
    final pcm = Int16List(samples.length ~/ 2);
    for (int i = 0; i < pcm.length; i++) {
      pcm[i] = byteData.getInt16(i * 2, Endian.little);
    }
    return _SignatureGeneratorState().process(pcm);
  }
}

class _FrequencyPeak {
  final int fftPassNumber;
  final int peakMagnitude;
  final int correctedPeakFrequencyBin;

  _FrequencyPeak({
    required this.fftPassNumber,
    required this.peakMagnitude,
    required this.correctedPeakFrequencyBin,
  });
}

class _SignatureGeneratorState {
  final Int32List samplesRing = Int32List(ShazamSignatureGenerator.fftSize);
  int samplesPos = 0;

  final List<Float64List> fftOutputs = List.generate(
    ShazamSignatureGenerator.ringBufSize,
    (_) => Float64List(ShazamSignatureGenerator.fftOutputSize),
  );
  int fftPos = 0;
  int fftNumWritten = 0;

  final List<Float64List> spreadFfts = List.generate(
    ShazamSignatureGenerator.ringBufSize,
    (_) => Float64List(ShazamSignatureGenerator.fftOutputSize),
  );
  int spreadPos = 0;
  int spreadNumWritten = 0;

  int numSamples = 0;

  final List<List<_FrequencyPeak>> bandPeaks = List.generate(4, (_) => []);
  int totalPeaks = 0;

  String process(Int16List pcm) {
    int offset = 0;
    while (offset + 128 <= pcm.length) {
      final elapsedSec = numSamples / ShazamSignatureGenerator.sampleRate;
      if (elapsedSec >= ShazamSignatureGenerator.maxTimeSeconds &&
          totalPeaks >= ShazamSignatureGenerator.maxPeaks) {
        break;
      }

      numSamples += 128;
      feedSamples(pcm, offset, 128);
      doFFT();
      doPeakSpreadingAndRecognition();
      offset += 128;
    }
    return encodeSignature();
  }

  void feedSamples(Int16List pcm, int start, int count) {
    for (int k = start; k < start + count; k++) {
      samplesRing[samplesPos] = pcm[k];
      samplesPos = (samplesPos + 1) % ShazamSignatureGenerator.fftSize;
    }
  }

  void doFFT() {
    final windowed = Float64List(ShazamSignatureGenerator.fftSize);
    for (int i = 0; i < ShazamSignatureGenerator.fftSize; i++) {
      final ringIdx = (samplesPos + i) % ShazamSignatureGenerator.fftSize;
      windowed[i] = samplesRing[ringIdx].toDouble() * ShazamSignatureGenerator.hanning[i];
    }
    final result = computeRfft(windowed);
    fftOutputs[fftPos].setAll(0, result);
    fftPos = (fftPos + 1) % ShazamSignatureGenerator.ringBufSize;
    fftNumWritten++;
  }

  void doPeakSpreadingAndRecognition() {
    doPeakSpreading();
    if (spreadNumWritten >= 47) {
      doPeakRecognition();
    }
  }

  void doPeakSpreading() {
    final lastFftIdx = (fftPos - 1 + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;
    final spread = Float64List.fromList(fftOutputs[lastFftIdx]);

    for (int pos = 0; pos < ShazamSignatureGenerator.fftOutputSize - 2; pos++) {
      spread[pos] = max(spread[pos], max(spread[pos + 1], spread[pos + 2]));
    }

    for (int pos = 0; pos < ShazamSignatureGenerator.fftOutputSize; pos++) {
      double maxVal = spread[pos];
      for (final offset in const [-1, -3, -6]) {
        final idx = ((spreadPos + offset) % ShazamSignatureGenerator.ringBufSize + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;
        final oldVal = spreadFfts[idx][pos];
        if (oldVal > maxVal) maxVal = oldVal;
        spreadFfts[idx][pos] = maxVal;
      }
    }

    spreadFfts[spreadPos].setAll(0, spread);
    spreadPos = (spreadPos + 1) % ShazamSignatureGenerator.ringBufSize;
    spreadNumWritten++;
  }

  void doPeakRecognition() {
    final fftMinus46 = fftOutputs[(fftPos - 46 + ShazamSignatureGenerator.ringBufSize * 2) % ShazamSignatureGenerator.ringBufSize];
    final spreadMinus49 = spreadFfts[(spreadPos - 49 + ShazamSignatureGenerator.ringBufSize * 2) % ShazamSignatureGenerator.ringBufSize];

    const otherOffsets = [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249];
    const neighbors = [-10, -7, -4, -3, 1, 2, 5, 8];

    for (int binPos = 10; binPos < ShazamSignatureGenerator.fftOutputSize - 8; binPos++) {
      final fftVal = fftMinus46[binPos];
      if (fftVal < 1.0 / 64.0 || fftVal < spreadMinus49[binPos]) continue;

      double maxNeighborSpread49 = 0.0;
      for (final neighborOffset in neighbors) {
        final v = spreadMinus49[binPos + neighborOffset];
        if (v > maxNeighborSpread49) maxNeighborSpread49 = v;
      }
      if (fftVal <= maxNeighborSpread49) continue;

      double maxNeighborOther = maxNeighborSpread49;
      for (final otherOffset in otherOffsets) {
        final spreadIdx = ((spreadPos + otherOffset) % ShazamSignatureGenerator.ringBufSize + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;
        final v = spreadFfts[spreadIdx][binPos - 1];
        if (v > maxNeighborOther) maxNeighborOther = v;
      }
      if (fftVal <= maxNeighborOther) continue;

      final fftNumber = spreadNumWritten - 46;

      final peakMag = log(max(1.0 / 64.0, fftVal)) * 1477.3 + 6144;
      final peakMagBefore = log(max(1.0 / 64.0, fftMinus46[binPos - 1])) * 1477.3 + 6144;
      final peakMagAfter = log(max(1.0 / 64.0, fftMinus46[binPos + 1])) * 1477.3 + 6144;

      final peakVariation1 = peakMag * 2 - peakMagBefore - peakMagAfter;
      final peakVariation2 = (peakMagAfter - peakMagBefore) * 32 / peakVariation1;

      final correctedBin = binPos * 64.0 + peakVariation2;
      final frequencyHz = correctedBin * (16000.0 / 2.0 / 1024.0 / 64.0);

      int band;
      if (frequencyHz < 250.0) {
        continue;
      } else if (frequencyHz < 520.0) {
        band = ShazamSignatureGenerator.band250To520;
      } else if (frequencyHz < 1450.0) {
        band = ShazamSignatureGenerator.band520To1450;
      } else if (frequencyHz < 3500.0) {
        band = ShazamSignatureGenerator.band1450To3500;
      } else if (frequencyHz <= 5500.0) {
        band = ShazamSignatureGenerator.band3500To5500;
      } else {
        continue;
      }

      bandPeaks[band].add(
        _FrequencyPeak(
          fftPassNumber: fftNumber,
          peakMagnitude: peakMag.toInt(),
          correctedPeakFrequencyBin: correctedBin.toInt(),
        ),
      );
      totalPeaks++;
    }
  }

  String encodeSignature() {
    final contentsBuilder = BytesBuilder();

    for (int bandId = 0; bandId < 4; bandId++) {
      final peaks = bandPeaks[bandId];
      if (peaks.isEmpty) continue;

      final peakBuilder = BytesBuilder();
      int prevFftPassNumber = 0;

      for (final peak in peaks) {
        final diff = peak.fftPassNumber - prevFftPassNumber;
        if (diff >= 255) {
          peakBuilder.addByte(0xFF);
          _writeLittleEndian32(peakBuilder, peak.fftPassNumber);
          prevFftPassNumber = peak.fftPassNumber;
        }
        peakBuilder.addByte(peak.fftPassNumber - prevFftPassNumber);
        _writeLittleEndian16(peakBuilder, peak.peakMagnitude);
        _writeLittleEndian16(peakBuilder, peak.correctedPeakFrequencyBin);
        prevFftPassNumber = peak.fftPassNumber;
      }

      final peakBytes = peakBuilder.toBytes();

      _writeLittleEndian32(contentsBuilder, 0x60030040 + bandId);
      _writeLittleEndian32(contentsBuilder, peakBytes.length);
      contentsBuilder.add(peakBytes);

      final padBytes = (4 - peakBytes.length % 4) % 4;
      for (int i = 0; i < padBytes; i++) {
        contentsBuilder.addByte(0);
      }
    }

    final contents = contentsBuilder.toBytes();
    final sizeMinusHeader = contents.length + 8;
    final samplesAndOffset = (numSamples + ShazamSignatureGenerator.sampleRate * 0.24).toInt();

    final headerData = ByteData(48);
    headerData.setInt32(0, 0xcafe2580, Endian.little);
    headerData.setInt32(4, 0, Endian.little);
    headerData.setInt32(8, sizeMinusHeader, Endian.little);
    headerData.setInt32(12, 0x94119c00, Endian.little);
    headerData.setInt32(16, 0, Endian.little);
    headerData.setInt32(20, 0, Endian.little);
    headerData.setInt32(24, 0, Endian.little);
    headerData.setInt32(28, 3 << 27, Endian.little);
    headerData.setInt32(32, 0, Endian.little);
    headerData.setInt32(36, 0, Endian.little);
    headerData.setInt32(40, samplesAndOffset, Endian.little);
    headerData.setInt32(44, (15 << 19) + 0x40000, Endian.little);

    final fullBuilder = BytesBuilder();
    fullBuilder.add(headerData.buffer.asUint8List());
    _writeLittleEndian32(fullBuilder, 0x40000000);
    _writeLittleEndian32(fullBuilder, contents.length + 8);
    fullBuilder.add(contents);

    final fullBytes = fullBuilder.toBytes();

    final crcValue = Crc32.compute(fullBytes, 8, fullBytes.length - 8);
    final crcData = ByteData(4)..setInt32(0, crcValue, Endian.little);
    fullBytes[4] = crcData.getUint8(0);
    fullBytes[5] = crcData.getUint8(1);
    fullBytes[6] = crcData.getUint8(2);
    fullBytes[7] = crcData.getUint8(3);

    final base64 = base64Encode(fullBytes);
    return "data:audio/vnd.shazam.sig;base64,$base64";
  }

  void _writeLittleEndian32(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
    builder.addByte((value >> 16) & 0xFF);
    builder.addByte((value >> 24) & 0xFF);
  }

  void _writeLittleEndian16(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
  }

  Float64List computeRfft(Float64List windowed) {
    final n = windowed.length;
    final re = Float64List.fromList(windowed);
    final im = Float64List(n);

    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmpRe = re[i];
        re[i] = re[j];
        re[j] = tmpRe;

        final tmpIm = im[i];
        im[i] = im[j];
        im[j] = tmpIm;
      }
    }

    int len = 2;
    while (len <= n) {
      final halfLen = len >> 1;
      final ang = -pi / halfLen;
      final wBaseRe = cos(ang);
      final wBaseIm = sin(ang);
      int i = 0;
      while (i < n) {
        double wRe = 1.0;
        double wIm = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final u = i + k;
          final v = u + halfLen;
          final evenRe = re[u];
          final evenIm = im[u];
          final oddRe = re[v] * wRe - im[v] * wIm;
          final oddIm = re[v] * wIm + im[v] * wRe;
          re[u] = evenRe + oddRe;
          im[u] = evenIm + oddIm;
          re[v] = evenRe - oddRe;
          im[v] = evenIm - oddIm;
          final newWRe = wRe * wBaseRe - wIm * wBaseIm;
          wIm = wRe * wBaseIm + wIm * wBaseRe;
          wRe = newWRe;
        }
        i += len;
      }
      len <<= 1;
    }

    const scaleFactor = 1.0 / (1 << 17);
    const minVal = 1e-10;
    final magnitudes = Float64List(ShazamSignatureGenerator.fftOutputSize);
    for (int idx = 0; idx < ShazamSignatureGenerator.fftOutputSize; idx++) {
      final r = re[idx];
      final img = im[idx];
      final mag = (r * r + img * img) * scaleFactor;
      magnitudes[idx] = mag < minVal ? minVal : mag;
    }
    return magnitudes;
  }
}
