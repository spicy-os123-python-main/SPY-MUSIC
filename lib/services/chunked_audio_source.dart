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
  final String? cacheDirPath;
  final void Function(String id)? onStreamError;

  ChunkedStreamAudioSource({
    required this.url,
    required this.totalBytes,
    this.contentType = 'audio/mp4',
    this.customHeaders,
    this.songId,
    this.cacheDirPath,
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
    // 256 KB chunks ensure fast initial response & rock-solid streaming on weak mobile networks
    const chunkSize = 1024 * 256;
    int current = start;
    int chunkIndex = (start / chunkSize).floor();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final defaultUa = _resolveUserAgent(url);
    final isAndroid = url.contains('c=ANDROID');

    try {
      while (targetEnd == null || current <= targetEnd) {
        final nextEnd = targetEnd != null
            ? min(current + chunkSize - 1, targetEnd)
            : current + chunkSize - 1;

        int attempts = 0;
        bool chunkComplete = false;

        while (attempts < 5 && !chunkComplete) {
          HttpClientResponse? resp;
          try {
            // Attempt 0: Use NewPipe pattern (query range for iOS/Web, header Range for Android)
            // Attempt 1: Swap range mechanism (header vs query)
            // Attempt 2+: Alternate user agent and range mechanism
            final useQueryRange = attempts == 0
                ? !isAndroid
                : (attempts % 2 == 1 ? isAndroid : !isAndroid);
            final ua = attempts < 2
                ? defaultUa
                : (attempts < 4
                    ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:153.0) Gecko/20100101 Firefox/153.0'
                    : 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');

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
            if (resp.statusCode != 200 && resp.statusCode != 206) {
              printERROR(
                  "ChunkedStreamAudioSource HTTP ${resp.statusCode} for chunk $chunkIndex ($current-$nextEnd, attempt ${attempts + 1})");
              await resp.drain();
              attempts++;
              if (attempts < 5) {
                await Future.delayed(Duration(milliseconds: 350 * attempts));
              }
              continue;
            }

            int bytesReadInChunk = 0;
            await for (final data in resp) {
              bytesReadInChunk += data.length;
              current += data.length;
              yield data;
            }

            if (bytesReadInChunk == 0) {
              // Reached EOF
              chunkComplete = true;
              break;
            }

            if (current > nextEnd ||
                (targetEnd != null && current > targetEnd)) {
              chunkComplete = true;
              chunkIndex++;
              break;
            }
          } catch (netErr) {
            attempts++;
            printERROR(
                "ChunkedStreamAudioSource network attempt $attempts failed at byte $current: $netErr");
            if (attempts >= 5) {
              if (songId != null) {
                onStreamError?.call(songId!);
              }
              rethrow;
            }
            // Resilient exponential backoff retry for poor/intermittent connectivity
            await Future.delayed(Duration(milliseconds: 350 * attempts));
          }
        }

        if (!chunkComplete && (targetEnd != null && current <= targetEnd)) {
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
