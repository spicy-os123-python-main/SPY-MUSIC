import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateDetails;

  const AppUpdateDialog({super.key, required this.updateDetails});

  @override
  Widget build(BuildContext context) {
    final current = updateDetails['current']?.toString() ?? "v1.0.0";
    final latest = updateDetails['latest']?.toString() ?? current;
    final hasUpdate = updateDetails['hasUpdate'] == true;
    final releaseBody = updateDetails['body']?.toString() ?? '';
    final downloadUrl = updateDetails['downloadUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/download/v1.0.0/spymusic-arm64-v8a.apk";
    final htmlUrl = updateDetails['htmlUrl']?.toString() ??
        "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest";

    return AlertDialog(
      backgroundColor: const Color(0xFF16161F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF00D2FF), width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D2FF), Color(0xFF0055FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Update-Prüfung",
              style: TextStyle(
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
                color: hasUpdate
                    ? const Color(0xFF1DB954).withOpacity(0.15)
                    : const Color(0xFF00D2FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasUpdate
                      ? const Color(0xFF1DB954)
                      : const Color(0xFF00D2FF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasUpdate
                        ? Icons.new_releases_rounded
                        : Icons.check_circle_rounded,
                    color: hasUpdate
                        ? const Color(0xFF1DB954)
                        : const Color(0xFF00D2FF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasUpdate
                          ? "Neue Version verfügbar! ($latest)"
                          : "✅ SPY MUSIC ist aktuell!",
                      style: TextStyle(
                        color: hasUpdate
                            ? const Color(0xFF1DB954)
                            : const Color(0xFF00D2FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Installierte Version:", current),
            const SizedBox(height: 6),
            _buildInfoRow("Neueste Release:", latest),
            if (releaseBody.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                "Changelog / Details:",
                style: TextStyle(
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Schließen", style: TextStyle(color: Colors.white60)),
        ),
        TextButton.icon(
          onPressed: () {
            launchUrl(Uri.parse(htmlUrl), mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_browser_rounded, size: 16),
          label: const Text("GitHub"),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            launchUrl(
              Uri.parse(downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text(
            "APK Download",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
