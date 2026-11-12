import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateDetails;

  const AppUpdateDialog({super.key, required this.updateDetails});

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("couldNotOpenLink".tr.replaceAll("{url}", url)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = updateDetails['current']?.toString() ?? "v1.0.0";
    final latest = updateDetails['latest']?.toString() ?? current;
    final hasUpdate = updateDetails['hasUpdate'] == true;
    final isSuccess =
        updateDetails['success'] != false && updateDetails['error'] == null;
    final errorMsg = updateDetails['error']?.toString();
    final releaseBody = updateDetails['body']?.toString() ?? '';
    final arm64Url = updateDetails['downloadUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/v1.0.0/spymusic-arm64-v8a.apk";
    final universalUrl = updateDetails['universalUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/v1.0.0/spymusic.apk";
    final htmlUrl = updateDetails['htmlUrl']?.toString() ??
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D2FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _openUrl(context, arm64Url),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      "ARM64 APK",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF00D2FF)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _openUrl(context, universalUrl),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      "Universal APK",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("close".tr, style: const TextStyle(color: Colors.white60)),
        ),
        TextButton.icon(
          onPressed: () => _openUrl(context, htmlUrl),
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
