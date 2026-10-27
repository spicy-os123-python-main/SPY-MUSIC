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
import '../settings_screen_controller.dart';

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

  bool get _isGerman {
    try {
      final settingsController = Get.find<SettingsScreenController>();
      if (settingsController.currentAppLanguageCode.value == 'de') return true;
    } catch (_) {}
    return (Get.locale?.languageCode ?? 'en') == 'de';
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
            _isGerman
                ? "✅ Backup erfolgreich erstellt & altes gelöscht!"
                : "✅ Backup successfully created & old deleted!",
            size: SanckBarSize.MEDIUM,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            _isGerman
                ? "❌ Fehler beim Erstellen des Backups"
                : "❌ Error creating backup",
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
        _isGerman
            ? "Lade Backup für Google Drive vor..."
            : "Preparing backup for Google Drive...",
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
          _isGerman
              ? "ℹ️ Teilen / Google Drive Vorgang beendet"
              : "ℹ️ Share / Google Drive process finished",
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
          _isGerman
              ? "Kein automatisches Backup vorhanden"
              : "No automatic backup found",
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
          _isGerman
              ? "Aus Auto-Backup wiederherstellen?"
              : "Restore from Auto-Backup?",
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: Text(
          _isGerman
              ? "Deine Playlists und Einstellungen werden auf den Stand vom $backupDate zurückgesetzt.\n\nDie App wird danach automatisch neu gestartet."
              : "Your playlists and settings will be restored from $backupDate.\n\nThe app will restart automatically.",
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              _isGerman ? "Abbrechen" : "Cancel",
              style: TextStyle(color: Theme.of(ctx).hintColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_isGerman ? "Wiederherstellen" : "Restore"),
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
            _isGerman
                ? "❌ Wiederherstellung fehlgeschlagen"
                : "❌ Restore failed",
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromCustomFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: _isGerman ? "Backup-Datei auswählen" : "Select backup file",
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
          _isGerman ? "Backup einspielen?" : "Import Backup?",
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: Text(
          _isGerman
              ? "Möchtest du das Backup aus der ausgewählten Datei einspielen? Die App wird danach neu gestartet."
              : "Do you want to import the backup from the selected file? The app will restart afterwards.",
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_isGerman ? "Abbrechen" : "Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_isGerman ? "Einspielen" : "Import"),
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
            _isGerman
                ? "❌ Fehler beim Einspielen der Datei"
                : "❌ Error importing backup file",
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackup = _backupInfo != null;
    final backupDate = _backupInfo?["date"] ?? (_isGerman ? "Noch kein Backup vorhanden" : "No backup yet");
    final backupSize = _backupInfo?["size"] ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Daily Auto-Backup Toggle
        ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 10),
          title: Text(
            _isGerman
                ? "Automatisches Backup (1x täglich)"
                : "Daily Auto-Backup (1x per day)",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? "Sichert 1x am Tag automatisch alle Playlists & Einstellungen. Das alte Backup wird gelöscht, sobald das neue fertig ist."
                : "Automatically backs up playlists & settings once daily. The old backup is deleted once the new one is complete.",
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
                    : Colors.white12,
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
                        _isGerman
                            ? "Rolling-Backup Status"
                            : "Rolling Backup Status",
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
                        _isGerman
                            ? "Alte Backups werden automatisch ersetzt (kein Datenmüll)"
                            : "Old backups are auto-replaced (no clutter)",
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
            _isGerman ? "In Google Drive sichern" : "Save to Google Drive",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? "Aktuelles Backup direkt in deinem Google Drive ablegen oder teilen."
                : "Directly save or share the current backup in your Google Drive.",
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
            _isGerman ? "Jetzt manuell sichern" : "Back up now manually",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? "Erstellt sofort ein neues Backup und überschreibt das vorherige."
                : "Creates a new backup now and overwrites the previous one.",
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
            _isGerman
                ? "Aus letztem Auto-Backup wiederherstellen"
                : "Restore from latest Auto-Backup",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? (hasBackup
                    ? "Stellt alle Daten vom Stand $backupDate wieder her."
                    : "Kein gespeichertes Auto-Backup vorhanden.")
                : (hasBackup
                    ? "Restores all data from $backupDate."
                    : "No saved auto-backup available."),
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
            _isGerman
                ? "Aus Datei wiederherstellen..."
                : "Restore from file...",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? "Wähle eine .spymusic oder .hmb Backup-Datei von deinem Gerät aus."
                : "Pick a .spymusic or .hmb backup file from your device.",
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
            _isGerman
                ? "Playlists reparieren & bereinigen"
                : "Repair & clean playlists",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isGerman
                ? "Korrigiert 0:00-Laufzeiten, repariert Streams und bereinigt fehlerhafte Downloads."
                : "Fixes 0:00 durations, repairs streams and cleans up faulty downloads.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          isThreeLine: true,
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              snackbar(
                context,
                _isGerman
                    ? "Repariere Playlists..."
                    : "Repairing playlists...",
                size: SanckBarSize.MEDIUM,
              ),
            );
            final repaired = await PlaylistRepairService().autoRepairOnLaunch();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                snackbar(
                  context,
                  _isGerman
                      ? "✅ $repaired Songs in Playlists erfolgreich repariert!"
                      : "✅ $repaired songs in playlists successfully repaired!",
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
