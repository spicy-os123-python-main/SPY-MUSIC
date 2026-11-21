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
    } on PlatformException catch (e) {
      printERROR("PlatformException invoking native APK installer: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      printERROR("Failed to invoke native APK installer: $e");
      return false;
    }
  }

  /// Get list of supported ABIs by the current Android device (e.g. ['arm64-v8a', 'armeabi-v7a'])
  static Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return [];
    try {
      final abis = await _channel.invokeMethod<List<dynamic>>('getSupportedAbis');
      return abis?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      printWarning("Could not query supported ABIs: $e");
      return [];
    }
  }

  /// Check whether unknown apps installation permission is granted on Android 8+
  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open system settings screen to allow installing unknown apps
  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      printWarning("Could not open install permission settings: $e");
    }
  }

  /// Determines the best path to store downloaded update APKs.
  /// Prefers external cache directory where system package installer has full access.
  static Future<String> getOptimalApkSavePath() async {
    try {
      if (Platform.isAndroid) {
        final externalDirs = await getExternalCacheDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final dir = externalDirs.first;
          if (await dir.exists()) {
            return "${dir.path}/spymusic_update.apk";
          }
        }
      }
    } catch (e) {
      printWarning("Could not access external cache directory: $e");
    }
    final tempDir = await getTemporaryDirectory();
    return "${tempDir.path}/spymusic_update.apk";
  }

  /// Validates that a downloaded file is a complete, uncorrupted ZIP/APK archive.
  /// Checks:
  /// 1. File exists and size >= 15 MB
  /// 2. Matches expected Content-Length if provided
  /// 3. Starts with ZIP Local File Header magic bytes PK\x03\x04
  /// 4. Contains ZIP End of Central Directory (EOCD) signature PK\x05\x06 in tail
  static Future<bool> verifyApkFile(File file, {int? expectedBytes}) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 15 * 1024 * 1024) {
        printERROR("APK file size ($length bytes) is suspiciously small (expected > 15MB)");
        return false;
      }
      if (expectedBytes != null && expectedBytes > 0) {
        if (length != expectedBytes) {
          printERROR("APK size mismatch: got $length bytes, expected $expectedBytes bytes");
          return false;
        }
      }

      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(4);
        if (header.length < 4 ||
            header[0] != 0x50 ||
            header[1] != 0x4B ||
            header[2] != 0x03 ||
            header[3] != 0x04) {
          printERROR("APK missing ZIP magic bytes PK\\x03\\x04");
          return false;
        }

        final checkLen = length < 2048 ? length : 2048;
        await raf.setPosition(length - checkLen);
        final tail = await raf.read(checkLen);
        bool hasEocd = false;
        for (int i = 0; i <= tail.length - 4; i++) {
          if (tail[i] == 0x50 &&
              tail[i + 1] == 0x4B &&
              tail[i + 2] == 0x05 &&
              tail[i + 3] == 0x06) {
            hasEocd = true;
            break;
          }
        }
        if (!hasEocd) {
          printERROR("APK missing ZIP End-of-Central-Directory record (truncated download)");
          return false;
        }
      } finally {
        await raf.close();
      }

      return true;
    } catch (e) {
      printERROR("Failed to verify APK file integrity: $e");
      return false;
    }
  }

  /// Cancel any currently active APK download
  static void cancelDownload() {
    _activeCancelToken?.cancel("User cancelled");
    _activeCancelToken = null;
  }

  /// Downloads the APK directly inside the app with live progress reporting,
  /// verifies file integrity, then immediately launches Android's native installer dialog.
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
      final savePath = await getOptimalApkSavePath();
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
          followRedirects: true,
          maxRedirects: 8,
        ),
      );

      onProgress(0.01, "0%");

      int? expectedTotalBytes;

      await dio.download(
        downloadUrl,
        savePath,
        cancelToken: _activeCancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            expectedTotalBytes = total;
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

      // Verify the downloaded file integrity before giving it to PackageInstaller
      final isValidApk = await verifyApkFile(file, expectedBytes: expectedTotalBytes);
      if (!isValidApk) {
        try {
          await file.delete();
        } catch (_) {}
        const errorText =
            "Download war unvollständig oder beschädigt. Bitte versuche es erneut oder nutze die Universal-APK.";
        onError(errorText);
        return false;
      }

      // Check permission on Android 8+
      final hasInstallPerm = await canRequestPackageInstalls();
      if (!hasInstallPerm) {
        await openInstallPermissionSettings();
        onError("Bitte aktiviere 'Unbekannte Apps installieren' für SPY MUSIC und tippe erneut auf Installieren.");
        return false;
      }

      final success = await installApk(savePath);
      if (!success) {
        onError("Installation konnte nicht gestartet werden. Öffne Browser-Download...");
        await openInBrowser(downloadUrl);
        return false;
      }
      return true;
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
