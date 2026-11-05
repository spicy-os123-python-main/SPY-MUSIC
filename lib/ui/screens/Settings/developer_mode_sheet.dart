import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../services/data_usage_tracker.dart';
import '../../../services/music_service.dart';
import '../../widgets/snackbar.dart';
import 'settings_screen_controller.dart';

class DeveloperModeSheet extends StatelessWidget {
  const DeveloperModeSheet({super.key});

  static void show(BuildContext context) {
    DataUsageTracker.instance.refreshDiskCaches();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeveloperModeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracker = DataUsageTracker.instance;
    final settingsCon = Get.find<SettingsScreenController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF6F8FC);
    final cardColor = isDark ? const Color(0xFF141824) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.data_usage_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "devModeTitle".tr,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.6),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  "DIAGNOSTICS",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "devModeSubtitle".tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  children: [
                    // Mode Banner
                    Obx(() {
                      final quality = settingsCon.streamingQuality.value;
                      final isUltra = quality == AudioQuality.Ultra;
                      final isMid = quality == AudioQuality.Mid;

                      final color = isUltra
                          ? const Color(0xFF10B981)
                          : (isMid ? const Color(0xFF3B82F6) : Colors.orange);
                      final title = isUltra
                          ? "devUltraActiveTitle".tr
                          : (isMid
                              ? "devMidActiveTitle".tr
                              : "devNormalActiveTitle".tr);
                      final desc = isUltra
                          ? "devUltraActiveDesc".tr
                          : (isMid
                              ? "devMidActiveDesc".tr
                              : "devNormalActiveDesc".tr);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: color, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Summary Big Card
                    Obx(() {
                      final totalBytes = tracker.sessionTotalBytes;
                      final oldEstimatedBytes =
                          tracker.sessionAudioCount.value * 22 * 1024 * 1024;
                      final savedBytes = oldEstimatedBytes > totalBytes
                          ? oldEstimatedBytes - totalBytes
                          : 0;
                      final percentSaved = oldEstimatedBytes > 0
                          ? ((savedBytes / oldEstimatedBytes) * 100).round()
                          : 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "devSessionOverview".tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (percentSaved > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF10B981),
                                          width: 1),
                                    ),
                                    child: Text(
                                      "-$percentSaved% ${"devDataSaved".tr}",
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    label: "devCurrentSession".tr,
                                    value: DataUsageTracker.formatBytes(
                                        totalBytes),
                                    icon: Icons.speed_rounded,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    label: "devTotalAllTime".tr,
                                    value: DataUsageTracker.formatBytes(
                                        tracker.totalAllBytes),
                                    icon: Icons.history_rounded,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Category 1: Audio Streaming
                    _buildSectionHeader(
                      context,
                      title: "devCatAudioTitle".tr,
                      icon: Icons.music_note_rounded,
                      color: const Color(0xFFFF5722),
                    ),
                    Obx(() {
                      final audioBytes = tracker.sessionAudioBytes.value;
                      final count = tracker.sessionAudioCount.value;
                      final avgBytes =
                          count > 0 ? (audioBytes / count).round() : 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devSessionAudio".tr,
                                    value: DataUsageTracker.formatBytes(
                                        audioBytes),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devPlayedSongs".tr,
                                    value: "$count ${"songs".tr}",
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devAvgPerSong".tr,
                                    value: DataUsageTracker.formatBytes(avgBytes),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Last track stream specs
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "devLastStreamSpecs".tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.play_circle_fill_rounded,
                                          size: 16, color: Color(0xFFFF5722)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          tracker.lastTrackTitle.value.isNotEmpty
                                              ? "${tracker.lastTrackTitle.value} - ${tracker.lastTrackArtist.value}"
                                              : "devNoSongPlayedYet".tr,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tracker.lastTrackCodec.value.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _buildTag(
                                          "Codec: ${tracker.lastTrackCodec.value.toUpperCase()}",
                                          Colors.blue,
                                        ),
                                        _buildTag(
                                          "itag: ${tracker.lastTrackItag.value}",
                                          Colors.amber,
                                        ),
                                        _buildTag(
                                          "${(tracker.lastTrackBitrate.value / 1000).round()} kbps",
                                          Colors.green,
                                        ),
                                        _buildTag(
                                          DataUsageTracker.formatBytes(
                                              tracker.lastTrackBytes.value),
                                          Colors.purple,
                                        ),
                                        _buildTag(
                                          tracker.lastTrackSource.value,
                                          Colors.teal,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "devAudioCacheDisk".tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                                Text(
                                  "${tracker.diskAudioCacheMb.value.toStringAsFixed(1)} MB",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Category 2: Images & Cover Art
                    _buildSectionHeader(
                      context,
                      title: "devCatImagesTitle".tr,
                      icon: Icons.image_rounded,
                      color: const Color(0xFF00D2FF),
                    ),
                    Obx(() {
                      final imgBytes = tracker.sessionImageBytes.value;
                      final count = tracker.sessionImageCount.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devSessionImages".tr,
                                    value:
                                        DataUsageTracker.formatBytes(imgBytes),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devImagesLoaded".tr,
                                    value: "$count",
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devImageDiskCache".tr,
                                    value:
                                        "${tracker.diskImageCacheMb.value.toStringAsFixed(1)} MB",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "devImageOptimizationInfo".tr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Category 3: API & Metadata
                    _buildSectionHeader(
                      context,
                      title: "devCatApiTitle".tr,
                      icon: Icons.cloud_sync_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                    Obx(() {
                      final apiBytes = tracker.sessionApiBytes.value;
                      final count = tracker.sessionApiCount.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devSessionApi".tr,
                                    value:
                                        DataUsageTracker.formatBytes(apiBytes),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devApiRequests".tr,
                                    value: "$count",
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubItem(
                                    label: "devFeedCache".tr,
                                    value: "8 Std. aktiv",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "devApiOptimizationInfo".tr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Category 4: Tools & Actions
                    _buildSectionHeader(
                      context,
                      title: "devCatToolsTitle".tr,
                      icon: Icons.handyman_rounded,
                      color: Colors.tealAccent,
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          // Reset Counters Button
                          _buildActionButton(
                            context,
                            icon: Icons.restart_alt_rounded,
                            label: "devResetStatsBtn".tr,
                            subtitle: "devResetStatsSubtitle".tr,
                            color: Colors.amber,
                            onTap: () {
                              tracker.resetStats();
                              ScaffoldMessenger.of(context).showSnackBar(
                                snackbar(
                                  context,
                                  "devStatsResetSuccess".tr,
                                  size: SanckBarSize.BIG,
                                ),
                              );
                            },
                          ),
                          const Divider(height: 16),

                          // Clear Cache Button
                          _buildActionButton(
                            context,
                            icon: Icons.delete_sweep_rounded,
                            label: "devClearCacheBtn".tr,
                            subtitle: "devClearCacheSubtitle".tr,
                            color: Colors.redAccent,
                            onTap: () async {
                              await settingsCon.clearImagesCache();
                              await tracker.refreshDiskCaches();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  snackbar(
                                    context,
                                    "clearImgCacheAlert".tr,
                                    size: SanckBarSize.BIG,
                                  ),
                                );
                              }
                            },
                          ),
                          const Divider(height: 16),

                          // Copy Report Button
                          _buildActionButton(
                            context,
                            icon: Icons.copy_rounded,
                            label: "devCopyReportBtn".tr,
                            subtitle: "devCopyReportSubtitle".tr,
                            color: theme.colorScheme.primary,
                            onTap: () {
                              final report = _generateDiagnosticReport(tracker);
                              Clipboard.setData(ClipboardData(text: report));
                              ScaffoldMessenger.of(context).showSnackBar(
                                snackbar(
                                  context,
                                  "devReportCopied".tr,
                                  size: SanckBarSize.BIG,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0E14) : const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Get.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Get.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  String _generateDiagnosticReport(DataUsageTracker tracker) {
    return """
=== SPY MUSIC DEVELOPER DIAGNOSTICS ===
Session Audio: ${DataUsageTracker.formatBytes(tracker.sessionAudioBytes.value)} (${tracker.sessionAudioCount.value} Songs)
Session Images: ${DataUsageTracker.formatBytes(tracker.sessionImageBytes.value)} (${tracker.sessionImageCount.value} Thumbnails)
Session API: ${DataUsageTracker.formatBytes(tracker.sessionApiBytes.value)} (${tracker.sessionApiCount.value} Requests)
Total Session: ${DataUsageTracker.formatBytes(tracker.sessionTotalBytes)}
Lifetime Total: ${DataUsageTracker.formatBytes(tracker.totalAllBytes)}

Last Streamed Song: ${tracker.lastTrackTitle.value} - ${tracker.lastTrackArtist.value}
Codec: ${tracker.lastTrackCodec.value} | itag: ${tracker.lastTrackItag.value} | Bitrate: ${(tracker.lastTrackBitrate.value / 1000).round()}k | Stream: ${DataUsageTracker.formatBytes(tracker.lastTrackBytes.value)}
Source: ${tracker.lastTrackSource.value}

Disk Cache:
- Images: ${tracker.diskImageCacheMb.value.toStringAsFixed(1)} MB
- Audio: ${tracker.diskAudioCacheMb.value.toStringAsFixed(1)} MB
=======================================
""";
  }
}
