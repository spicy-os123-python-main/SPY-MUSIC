import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../utils/helper.dart';

/// Custom StreamAudioSource that proxies YouTube audio streams using
/// NewPipe's proven streaming parameters (rn sequence, range parameter,
/// YouTube Origin/Referer headers, and matching User-Agents).
class ChunkedStreamAudioSource extends StreamAudioSource {
  final String url;
  final int totalBytes;
  final String contentType;
  final Map<String, String>? customHeaders;
  final String? songId;
  final void Function(String id)? onStreamError;

  ChunkedStreamAudioSource({
    required this.url,
    required this.totalBytes,
    this.contentType = 'audio/mp4',
    this.customHeaders,
    this.songId,
    this.onStreamError,
    super.tag,
  });

  static String _resolveUserAgent(String streamUrl) {
    if (streamUrl.contains('c=IOS')) {
      return 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
    } else if (streamUrl.contains('c=WEB')) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:153.0) Gecko/20100101 Firefox/153.0';
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
    int chunkIndex = 0;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final defaultUa = _resolveUserAgent(url);
    final isAndroid = url.contains('c=ANDROID');

    try {
      while (targetEnd == null || current <= targetEnd) {
        final nextEnd = targetEnd != null
            ? min(current + chunkSize - 1, targetEnd)
            : current + chunkSize - 1;

        HttpClientResponse? resp;
        int attempts = 0;

        while (attempts < 3) {
          // Attempt 0: Use NewPipe pattern (query range for iOS/Web, header Range for Android)
          // Attempt 1: Swap range mechanism (header vs query)
          // Attempt 2: Use NewPipe desktop Firefox User-Agent
          final useQueryRange = attempts == 0 ? !isAndroid : isAndroid;
          final ua = attempts < 2
              ? defaultUa
              : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:153.0) Gecko/20100101 Firefox/153.0';

          Uri reqUri = Uri.parse(url);
          final qParams = Map<String, String>.from(reqUri.queryParameters);
          qParams['rn'] = '$chunkIndex';
          if (useQueryRange) {
            qParams['range'] = '$current-$nextEnd';
          } else {
            qParams.remove('range');
          }
          reqUri = reqUri.replace(queryParameters: qParams);

          final req = await client.getUrl(reqUri);
          req.headers.set('User-Agent', ua);
          req.headers.set('Origin', 'https://www.youtube.com');
          req.headers.set('Referer', 'https://www.youtube.com');
          req.headers.set('Sec-Fetch-Dest', 'empty');
          req.headers.set('Sec-Fetch-Mode', 'cors');
          req.headers.set('Sec-Fetch-Site', 'cross-site');
          req.headers.set('TE', 'trailers');
          req.headers.set('Connection', 'keep-alive');

          if (!useQueryRange) {
            req.headers.set('Range', 'bytes=$current-$nextEnd');
          }

          if (customHeaders != null) {
            customHeaders!.forEach((k, v) {
              final lower = k.toLowerCase();
              if (lower != 'user-agent' && lower != 'range') {
                req.headers.set(k, v);
              }
            });
          }

          resp = await req.close();
          if (resp.statusCode == 200 || resp.statusCode == 206) {
            break;
          }

          printERROR(
              "ChunkedStreamAudioSource HTTP ${resp.statusCode} for chunk $chunkIndex ($current-$nextEnd, attempt ${attempts + 1})");
          await resp.drain();
          attempts++;
          if (attempts < 3) {
            await Future.delayed(const Duration(milliseconds: 250));
          }
        }

        if (resp == null || (resp.statusCode != 200 && resp.statusCode != 206)) {
          final sCode = resp?.statusCode ?? 500;
          printERROR("ChunkedStreamAudioSource unrecoverable HTTP $sCode at offset $current for song: $songId");
          if (songId != null) {
            onStreamError?.call(songId!);
          }
          throw HttpException("YouTube chunked streaming failed with HTTP $sCode at byte $current");
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
        chunkIndex++;
        if (targetEnd != null && current > targetEnd) {
          break;
        }
      }
    } catch (e) {
      printERROR("ChunkedStreamAudioSource streaming error: $e");
      if (songId != null) {
        onStreamError?.call(songId!);
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
