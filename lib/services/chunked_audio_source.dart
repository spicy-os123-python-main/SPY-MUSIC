import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../utils/helper.dart';

/// Custom StreamAudioSource that proxies YouTube audio streams through
/// bounded 512KB HTTP range chunks with authentic client headers.
/// Automatically matches client platform (iOS/Android/Web) and gracefully retries.
class ChunkedStreamAudioSource extends StreamAudioSource {
  final String url;
  final int totalBytes;
  final String contentType;
  final Map<String, String>? customHeaders;

  ChunkedStreamAudioSource({
    required this.url,
    required this.totalBytes,
    this.contentType = 'audio/mp4',
    this.customHeaders,
    super.tag,
  });

  static String _resolveUserAgent(String streamUrl) {
    if (streamUrl.contains('c=IOS')) {
      return 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
    } else if (streamUrl.contains('c=WEB')) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
    }
    return 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final startOffset = start ?? 0;
    final endOffset = (end != null && end < totalBytes && end >= startOffset)
        ? end
        : (totalBytes > 0 ? totalBytes - 1 : null);
    final contentLength =
        endOffset != null ? (endOffset - startOffset + 1) : null;

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: totalBytes > 0 ? totalBytes : null,
      contentLength: contentLength,
      offset: startOffset,
      stream: _fetchChunks(startOffset, endOffset),
      contentType: contentType,
    );
  }

  Stream<List<int>> _fetchChunks(int start, int? end) async* {
    final targetEnd = (end != null && end < totalBytes && end >= start)
        ? end
        : (totalBytes > 0 ? totalBytes - 1 : null);
    const chunkSize = 1024 * 512; // 512 KB chunks
    int current = start;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final defaultUa = _resolveUserAgent(url);

    try {
      while (targetEnd == null || current <= targetEnd) {
        final nextEnd = targetEnd != null
            ? min(current + chunkSize - 1, targetEnd)
            : current + chunkSize - 1;

        HttpClientResponse? resp;
        int attempts = 0;
        final candidateUas = [
          defaultUa,
          defaultUa.contains('IOS')
              ? 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip'
              : 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
          '', // No User-Agent fallback
        ];

        while (attempts < candidateUas.length) {
          final ua = candidateUas[attempts];
          final req = await client.getUrl(Uri.parse(url));
          if (ua.isNotEmpty) {
            req.headers.set('User-Agent', ua);
          }
          req.headers.set('Range', 'bytes=$current-$nextEnd');
          req.headers.set('Connection', 'keep-alive');

          if (customHeaders != null) {
            customHeaders!.forEach((k, v) {
              final lower = k.toLowerCase();
              if (lower != 'user-agent' && lower != 'range') {
                req.headers.set(k, v);
              }
            });
          }

          resp = await req.close();
          if (resp.statusCode == 206 || resp.statusCode == 200) {
            break;
          }

          printERROR(
              "ChunkedStreamAudioSource HTTP ${resp.statusCode} for range $current-$nextEnd (attempt ${attempts + 1}, UA: $ua)");
          await resp.drain();
          attempts++;
          if (attempts < candidateUas.length) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }

        if (resp == null || (resp.statusCode != 206 && resp.statusCode != 200)) {
          final sCode = resp?.statusCode ?? 500;
          printERROR("ChunkedStreamAudioSource unrecoverable HTTP $sCode at offset $current");
          throw HttpException("ChunkedStreamAudioSource HTTP $sCode at offset $current");
        }

        int bytesInChunk = 0;
        await for (final data in resp) {
          bytesInChunk += data.length;
          yield data;
        }

        if (bytesInChunk == 0) {
          break; // EOF
        }

        current += bytesInChunk;
        if (targetEnd != null && current > targetEnd) {
          break;
        }
      }
    } catch (e) {
      printERROR("ChunkedStreamAudioSource streaming error: $e");
      rethrow;
    } finally {
      client.close();
    }
  }
}
