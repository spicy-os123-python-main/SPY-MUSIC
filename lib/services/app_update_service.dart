import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/helper.dart';

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('com.spymusic.app/installer');
  static CancelToken? _activeCancelToken;

  /// Trigger the native Android package installer for a downloaded APK file.
  static Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return result ?? false;
    } catch (e) {
      printERROR("Failed to invoke native APK installer: $e");
      return false;
    }
  }

  /// Cancel any currently active APK download
  static void cancelDownload() {
    _activeCancelToken?.cancel("User cancelled");
    _activeCancelToken = null;
  }

  /// Downloads the APK directly inside the app with live progress reporting,
  /// then immediately launches Android's native installer dialog.
  static Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required void Function(double progress, String statusText) onProgress,
    required void Function(String error) onError,
  }) async {
    if (!Platform.isAndroid) {
      // On non-Android platforms, open the direct download URL in the browser
      return openInBrowser(downloadUrl);
    }

    cancelDownload();
    _activeCancelToken = CancelToken();

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = "${tempDir.path}/spymusic_update.apk";

      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(minutes: 10),
          headers: {'User-Agent': 'SPY-MUSIC-App/1.0'},
        ),
      );

      onProgress(0.01, "0%");

      await dio.download(
        downloadUrl,
        savePath,
        cancelToken: _activeCancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
            final percent = (progress * 100).toInt();
            onProgress(progress, "$percent% ($mbReceived MB / $mbTotal MB)");
          } else {
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            onProgress(0.5, "$mbReceived MB");
          }
        },
      );

      _activeCancelToken = null;
      onProgress(1.0, "100%");

      // Verify the downloaded file exists and is not empty
      if (await file.exists() && (await file.length()) > 1024 * 1024) {
        final success = await installApk(savePath);
        if (!success) {
          onError("Installation could not be started. Opening browser fallback...");
          await openInBrowser(downloadUrl);
          return false;
        }
        return true;
      } else {
        onError("Downloaded APK file is incomplete or corrupted.");
        await openInBrowser(downloadUrl);
        return false;
      }
    } on DioException catch (e) {
      _activeCancelToken = null;
      if (CancelToken.isCancel(e)) {
        return false;
      }
      printERROR("APK download error: $e");
      onError(e.message ?? "Download error");
      await openInBrowser(downloadUrl);
      return false;
    } catch (e) {
      _activeCancelToken = null;
      printERROR("Unexpected error during APK update: $e");
      onError(e.toString());
      await openInBrowser(downloadUrl);
      return false;
    }
  }

  /// Launch external browser to download the file directly
  static Future<bool> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      return launched;
    } catch (e) {
      printERROR("Could not launch download URL: $url - $e");
      return false;
    }
  }
}
