import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../services/app_update_service.dart';
import '../../utils/app_version.dart';

class AppUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateDetails;

  const AppUpdateDialog({super.key, required this.updateDetails});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = "";
  String? _errorMessage;
  bool _dontRemindAgain = false;

  @override
  void initState() {
    super.initState();
    final latest = widget.updateDetails['latest']?.toString() ?? '';
    final dismissed = Hive.box("AppPrefs").get("dismissedUpdateVersion");
    _dontRemindAgain = dismissed != null && dismissed.toString() == latest;
  }

  void _startInAppDownload(String downloadUrl) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.01;
      _downloadStatus = "downloadingUpdate".tr;
      _errorMessage = null;
    });

    final success = await AppUpdateService.downloadAndInstallApk(
      downloadUrl: downloadUrl,
      onProgress: (progress, statusText) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _downloadStatus = statusText;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = err;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  void _cancelDownload() {
    AppUpdateService.cancelDownload();
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _downloadStatus = "";
      });
    }
  }

  void _toggleDontRemind(bool? value, String latestVersion) {
    final next = value ?? false;
    setState(() {
      _dontRemindAgain = next;
    });
    if (next) {
      Hive.box("AppPrefs").put("dismissedUpdateVersion", latestVersion);
    } else {
      Hive.box("AppPrefs").delete("dismissedUpdateVersion");
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.updateDetails['current']?.toString() ?? AppVersion.value;
    final latest = widget.updateDetails['latest']?.toString() ?? current;
    final hasUpdate = widget.updateDetails['hasUpdate'] == true;
    final isSuccess = widget.updateDetails['success'] != false && widget.updateDetails['error'] == null;
    final errorMsg = widget.updateDetails['error']?.toString();
    final releaseBody = widget.updateDetails['body']?.toString() ?? '';
    final arm64Url = widget.updateDetails['downloadUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/spymusic-arm64-v8a.apk";
    final universalUrl = widget.updateDetails['universalUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/spymusic.apk";
    final htmlUrl = widget.updateDetails['htmlUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest";

    final Color statusColor = hasUpdate
        ? const Color(0xFF1DB954)
        : (!isSuccess ? const Color(0xFFFF9800) : const Color(0xFF00D2FF));

    return AlertDialog(
      backgroundColor: const Color(0xFF16161F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasUpdate
                    ? [const Color(0xFF1DB954), const Color(0xFF0D7333)]
                    : (!isSuccess
                        ? [const Color(0xFFFF9800), const Color(0xFFE65100)]
                        : [const Color(0xFF00D2FF), const Color(0xFF0055FF)]),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasUpdate
                  ? Icons.new_releases_rounded
                  : (!isSuccess
                      ? Icons.warning_amber_rounded
                      : Icons.system_update_rounded),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "updateCheckTitle".tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                children: [
                  Icon(
                    hasUpdate
                        ? Icons.download_rounded
                        : (!isSuccess
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_rounded),
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasUpdate
                          ? "${"newVersionAvailable".tr} ($latest)"
                          : (!isSuccess
                              ? "updateCheckError".tr
                              : "✅ ${"appUpToDate".tr}!"),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow("installedVersion".tr, current),
            const SizedBox(height: 6),
            _buildInfoRow("latestRelease".tr, latest),

            if (!isSuccess && errorMsg != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "githubConnectionError".tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => AppUpdateService.openInBrowser(arm64Url),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                      label: Text("browserDownload".tr, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            if (releaseBody.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "changelogDetails".tr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  releaseBody.length > 250
                      ? '${releaseBody.substring(0, 250)}...'
                      : releaseBody,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],

            // Active In-App Download Progress State
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D2FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "downloadingUpdate".tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          _downloadStatus,
                          style: const TextStyle(
                            color: Color(0xFF00D2FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D2FF)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelDownload,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: Text("cancel".tr, style: const TextStyle(fontSize: 11.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons when Update is available and not actively downloading
            if (hasUpdate && !_isDownloading) ...[
              const SizedBox(height: 16),
              if (Platform.isAndroid) ...[
                // Primary: One-Click Direct In-App Download & Install
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _startInAppDownload(arm64Url),
                    icon: const Icon(Icons.install_mobile_rounded, size: 20),
                    label: Text(
                      "directUpdateInstall".tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D2FF),
                        side: const BorderSide(color: Color(0xFF00D2FF)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Platform.isAndroid
                          ? _startInAppDownload(universalUrl)
                          : AppUpdateService.openInBrowser(universalUrl),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text(
                        "Universal APK",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => AppUpdateService.openInBrowser(arm64Url),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                      label: Text(
                        "browserDownload".tr,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // "Don't remind again for this version" checkbox
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _dontRemindAgain,
                      activeColor: const Color(0xFF00D2FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) => _toggleDontRemind(val, latest),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleDontRemind(!_dontRemindAgain, latest),
                      child: Text(
                        "dontRemindThisVersion".tr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isDownloading) {
              _cancelDownload();
            }
            Navigator.of(context).pop();
          },
          child: Text("close".tr, style: const TextStyle(color: Colors.white60)),
        ),
        TextButton.icon(
          onPressed: () => AppUpdateService.openInBrowser(htmlUrl),
          icon: const Icon(Icons.open_in_browser_rounded, size: 16),
          label: const Text("GitHub"),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
