import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:terminate_restart/terminate_restart.dart';

import '/services/backup_service.dart';
import '/services/playlist_repair_service.dart';
import '/ui/widgets/cust_switch.dart';
import '/ui/widgets/snackbar.dart';

class AutoBackupSettingsWidget extends StatefulWidget {
  const AutoBackupSettingsWidget({super.key});

  @override
  State<AutoBackupSettingsWidget> createState() =>
      _AutoBackupSettingsWidgetState();
}

class _AutoBackupSettingsWidgetState extends State<AutoBackupSettingsWidget> {
  final BackupService _backupService = BackupService();
  final Box _appPrefs = Hive.box("AppPrefs");

  bool _isAutoBackupEnabled = true;
  bool _isLoading = false;
  Map<String, dynamic>? _backupInfo;

  @override
  void initState() {
    super.initState();
    _isAutoBackupEnabled =
        _appPrefs.get("autoBackupEnabled", defaultValue: true);
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    final info = await _backupService.getLatestBackupInfo();
    if (mounted) {
      setState(() {
        _backupInfo = info;
      });
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() {
      _isAutoBackupEnabled = value;
    });
    await _appPrefs.put("autoBackupEnabled", value);
    if (value) {
      // Trigger auto-backup check immediately
      await _backupService.checkAndRunAutoBackup();
      await _loadBackupInfo();
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _isLoading = true);
    final file = await _backupService.createBackup();
    await _loadBackupInfo();
    setState(() => _isLoading = false);

    if (mounted) {
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "autoBackupCreatedMsg".tr,
            size: SanckBarSize.MEDIUM,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "autoBackupErrorMsg".tr,
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }

  Future<void> _shareToGoogleDrive() async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(
        context,
        "preparingDriveBackup".tr,
        size: SanckBarSize.SMALL,
      ),
    );

    final success = await _backupService.shareToGoogleDrive();
    await _loadBackupInfo();
    setState(() => _isLoading = false);

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(
          context,
          "driveShareFinished".tr,
          size: SanckBarSize.SMALL,
        ),
      );
    }
  }

  Future<void> _restoreLatestBackup() async {
    if (_backupInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(
          context,
          "noAutoBackupFound".tr,
          size: SanckBarSize.SMALL,
        ),
      );
      return;
    }

    final backupDate = _backupInfo?["date"] ?? "";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "restoreAutoBackupTitle".tr,
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: Text(
          "restoreAutoBackupMsg".tr.replaceAll("{date}", "$backupDate"),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              "cancel".tr,
              style: TextStyle(color: Theme.of(ctx).hintColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("restore".tr),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final restored = await _backupService.restoreFromLatestBackup();
    setState(() => _isLoading = false);

    if (restored) {
      if (GetPlatform.isAndroid) {
        TerminateRestart.instance.restartApp(
          options: const TerminateRestartOptions(terminate: true),
        );
      } else {
        exit(0);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "restoreFailed".tr,
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromCustomFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: "selectBackupFile".tr,
      type: FileType.any,
      allowMultiple: false,
    );

    final path = result?.files.first.path;
    if (path == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "importBackupTitle".tr,
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: Text(
          "importBackupMsg".tr,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("cancel".tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("importBackupAction".tr),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final restored = await _backupService.restoreFromFile(path);
    setState(() => _isLoading = false);

    if (restored) {
      if (GetPlatform.isAndroid) {
        TerminateRestart.instance.restartApp(
          options: const TerminateRestartOptions(terminate: true),
        );
      } else {
        exit(0);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "errorImportingFile".tr,
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackup = _backupInfo != null;
    final backupDate = _backupInfo?["date"] ?? "noBackupYet".tr;
    final backupSize = _backupInfo?["size"] ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Daily Auto-Backup Toggle
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          title: Text(
            "autoBackupTitle".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "autoBackupDesc".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          trailing: CustSwitch(
            value: _isAutoBackupEnabled,
            onChanged: _toggleAutoBackup,
          ),
        ),

        // 2. Status card of the rolling backup
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasBackup
                    ? const Color(0xFF00D2FF).withAlpha(100)
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  hasBackup
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: hasBackup
                      ? const Color(0xFF00E676)
                      : Theme.of(context).hintColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "rollingBackupStatus".tr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBackup
                            ? "$backupDate • $backupSize"
                            : backupDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "autoReplaceBackupsHint".tr,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasBackup
                              ? const Color(0xFF00D2FF)
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),

        // 3. Google Drive Linking / Export
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          leading: const Icon(
            Icons.cloud_upload_rounded,
            color: Color(0xFF4285F4),
            size: 26,
          ),
          title: Text(
            "saveToGoogleDrive".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "saveToGoogleDriveDesc".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: _isLoading ? null : _shareToGoogleDrive,
        ),

        // 4. Manual Backup Now
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          leading: const Icon(
            Icons.save_rounded,
            color: Color(0xFF00D2FF),
            size: 26,
          ),
          title: Text(
            "manualBackupNow".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "manualBackupNowDesc".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          onTap: _isLoading ? null : _manualBackup,
        ),

        // 5. Restore from latest backup (1-Click)
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          leading: Icon(
            Icons.history_rounded,
            color: hasBackup ? const Color(0xFFFF9100) : Colors.grey,
            size: 26,
          ),
          title: Text(
            "restoreLatestAutoBackup".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            hasBackup
                ? "restoreLatestAutoBackupDesc".tr.replaceAll("{date}", "$backupDate")
                : "noSavedAutoBackup".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          onTap: (_isLoading || !hasBackup) ? null : _restoreLatestBackup,
        ),

        // 6. Restore from file...
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          leading: const Icon(
            Icons.folder_open_rounded,
            color: Color(0xFFAB47BC),
            size: 26,
          ),
          title: Text(
            "restoreFromFile".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "restoreFromFileDesc".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          onTap: _isLoading ? null : _restoreFromCustomFile,
        ),

        // 7. Playlist repair & cleanup
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          leading: const Icon(
            Icons.auto_fix_high_rounded,
            color: Color(0xFF00D2FF),
            size: 26,
          ),
          title: Text(
            "repairCleanPlaylists".tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "repairCleanPlaylistsDesc".tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              snackbar(
                context,
                "repairingPlaylistsMsg".tr,
                size: SanckBarSize.MEDIUM,
              ),
            );
            final repaired = await PlaylistRepairService().autoRepairOnLaunch();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                snackbar(
                  context,
                  "playlistsRepairedCount".tr.replaceAll("{count}", "$repaired"),
                  size: SanckBarSize.BIG,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
