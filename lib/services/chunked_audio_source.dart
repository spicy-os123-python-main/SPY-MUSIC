import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../utils/helper.dart';

/// Custom StreamAudioSource that proxies YouTube audio streams through
/// bounded 512KB HTTP range chunks with authentic YouTube Android headers.
/// This prevents Google Video CDN 403 Forbidden ("Source error" / ExoPlayer code 0).
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

    try {
      while (targetEnd == null || current <= targetEnd) {
        final nextEnd = targetEnd != null
            ? min(current + chunkSize - 1, targetEnd)
            : current + chunkSize - 1;

        final req = await client.getUrl(Uri.parse(url));
        req.headers.set('User-Agent',
            'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
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

        final resp = await req.close();
        if (resp.statusCode != 206 && resp.statusCode != 200) {
          printERROR(
              "ChunkedStreamAudioSource HTTP ${resp.statusCode} for range $current-$nextEnd");
          break;
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
    } finally {
      client.close();
    }
  }
}
