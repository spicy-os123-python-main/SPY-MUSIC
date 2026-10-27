import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/helper.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String backupFileName = "spymusic_backup_latest.spymusic";
  static const String backupTempName = "spymusic_backup_temp.spymusic";

  /// Gets the persistent backup directory on the device
  Future<Directory> getBackupDirectory() async {
    Directory? backupDir;

    if (Platform.isAndroid) {
      // 1. Standard public Download folder - persists even when app is uninstalled/reinstalled!
      const downloadPath = "/storage/emulated/0/Download/SPY_MUSIC";
      final dir = Directory(downloadPath);
      try {
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        if (dir.existsSync()) {
          backupDir = dir;
        }
      } catch (_) {}

      // 2. Secondary public Documents folder fallback
      if (backupDir == null) {
        try {
          const docPath = "/storage/emulated/0/Documents/SPY_MUSIC";
          final dDir = Directory(docPath);
          if (!dDir.existsSync()) {
            dDir.createSync(recursive: true);
          }
          if (dDir.existsSync()) {
            backupDir = dDir;
          }
        } catch (_) {}
      }

      // 3. External storage directory fallback
      if (backupDir == null) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final appExtDir = Directory("${extDir.path}/SPY_MUSIC");
            if (!appExtDir.existsSync()) {
              appExtDir.createSync(recursive: true);
            }
            backupDir = appExtDir;
          }
        } catch (_) {}
      }
    }

    // Fallback for Windows, Linux, iOS or restricted Android sandbox
    backupDir ??= await getApplicationDocumentsDirectory();
    final finalDir = Directory("${backupDir.path}/SPY_MUSIC_Backups");
    if (!finalDir.existsSync()) {
      finalDir.createSync(recursive: true);
    }
    return finalDir;
  }

  /// Target path for Hive database files based on platform
  Future<String> getDbDirectoryPath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final sup = await getApplicationSupportDirectory();
      final db = Directory("${sup.path}/db");
      if (!db.existsSync()) {
        db.createSync(recursive: true);
      }
      return db.path;
    } else {
      final doc = await getApplicationDocumentsDirectory();
      return doc.path;
    }
  }

  /// Collects all Hive database files from all possible app data directories
  Future<List<File>> _collectDatabaseFiles() async {
    final List<File> hiveFiles = [];
    final Set<String> visitedPaths = {};

    List<Directory> searchDirs = [];

    try {
      final docDir = await getApplicationDocumentsDirectory();
      searchDirs.add(docDir);
    } catch (_) {}

    try {
      final supportDir = await getApplicationSupportDirectory();
      searchDirs.add(supportDir);
      final dbDir = Directory("${supportDir.path}/db");
      if (dbDir.existsSync()) {
        searchDirs.add(dbDir);
      }
    } catch (_) {}

    for (final dir in searchDirs) {
      if (dir.existsSync()) {
        try {
          for (final entity in dir.listSync(recursive: false)) {
            if (entity is File &&
                entity.path.endsWith('.hive') &&
                !visitedPaths.contains(entity.path)) {
              visitedPaths.add(entity.path);
              hiveFiles.add(entity);
            }
          }
        } catch (_) {}
      }
    }

    return hiveFiles;
  }

  /// Checks if 24 hours have passed since the last backup and runs auto-backup
  Future<void> checkAndRunAutoBackup() async {
    try {
      final box = Hive.box("AppPrefs");
      final bool isEnabled = box.get("autoBackupEnabled", defaultValue: true);
      if (!isEnabled) return;

      final int lastBackupMs = box.get("lastAutoBackupTime", defaultValue: 0);
      final lastBackupDate = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
      final now = DateTime.now();

      // If at least 24 hours have passed (or first time)
      if (now.difference(lastBackupDate).inHours >= 24 || lastBackupMs == 0) {
        printINFO("[SPY MUSIC Backup] Starting daily auto-backup (24h interval)...");
        await createBackup(isAutoBackup: true);
      }
    } catch (e) {
      printERROR("[SPY MUSIC Backup] Auto-backup check failed: $e");
    }
  }

  /// Creates a rolling backup (old backup is deleted only when new backup is successful)
  Future<File?> createBackup({bool isAutoBackup = false}) async {
    try {
      final backupDir = await getBackupDirectory();
      final tempFile = File("${backupDir.path}/$backupTempName");
      final targetFile = File("${backupDir.path}/$backupFileName");

      // 1. Collect all .hive database files
      final hiveFiles = await _collectDatabaseFiles();

      if (hiveFiles.isEmpty) {
        printINFO("[SPY MUSIC Backup] No database files found to backup");
        return null;
      }

      // 2. Compress files into archive in memory / temp file
      final archive = Archive();
      for (var file in hiveFiles) {
        final bytes = await file.readAsBytes();
        final fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }

      // Add a manifest file with metadata
      final manifestContent = {
        "appName": "SPY MUSIC",
        "timestamp": DateTime.now().toIso8601String(),
        "filesCount": hiveFiles.length,
      };
      final manifestBytes = Uint8List.fromList(
          manifestContent.toString().codeUnits);
      archive.addFile(ArchiveFile("manifest.json", manifestBytes.length, manifestBytes));

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null || zipData.isEmpty) {
        throw Exception("ZipEncoder failed to compress backup data");
      }

      // 3. Write to temporary file first
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      await tempFile.writeAsBytes(zipData);

      // 4. Atomic rolling replacement: delete old backup only AFTER temp is completely written
      if (targetFile.existsSync()) {
        try {
          targetFile.deleteSync();
        } catch (_) {}
      }
      await tempFile.rename(targetFile.path);

      // 5. Save last backup info in Hive
      final box = Hive.box("AppPrefs");
      await box.put("lastAutoBackupTime", DateTime.now().millisecondsSinceEpoch);
      await box.put("lastAutoBackupPath", targetFile.path);

      printINFO("[SPY MUSIC Backup] Backup created successfully: ${targetFile.path} (${targetFile.lengthSync()} bytes)");
      return targetFile;
    } catch (e) {
      printERROR("[SPY MUSIC Backup] Backup failed: $e");
      return null;
    }
  }

  static String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$d.$m.$y $h:$min";
  }

  static String _formatFileDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "${d}_${m}_${y}_$h$min";
  }

  /// Share or upload the latest backup directly to Google Drive / Cloud
  Future<bool> shareToGoogleDrive() async {
    try {
      final backupDir = await getBackupDirectory();
      var targetFile = File("${backupDir.path}/$backupFileName");

      // If no backup exists yet, create one now
      if (!targetFile.existsSync()) {
        final created = await createBackup();
        if (created == null) return false;
        targetFile = created;
      }

      final dateStr = _formatFileDate(targetFile.lastModifiedSync());
      final shareText = "SPY MUSIC Backup ($dateStr) - In Google Drive sichern";

      final result = await Share.shareXFiles(
        [XFile(targetFile.path, name: "spymusic_backup_$dateStr.spymusic")],
        text: shareText,
        subject: "SPY MUSIC Backup",
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      printERROR("[SPY MUSIC Backup] Share to Google Drive error: $e");
      return false;
    }
  }

  /// Restores all databases from the latest backup file
  Future<bool> restoreFromLatestBackup() async {
    try {
      final backupDir = await getBackupDirectory();
      final backupFile = File("${backupDir.path}/$backupFileName");

      if (!backupFile.existsSync()) {
        printERROR("[SPY MUSIC Backup] No backup file found to restore");
        return false;
      }

      return await restoreFromFile(backupFile.path);
    } catch (e) {
      printERROR("[SPY MUSIC Backup] Restore error: $e");
      return false;
    }
  }

  /// Restores from a specific file path
  Future<bool> restoreFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dbDirPath = await getDbDirectoryPath();
      final dbDir = Directory(dbDirPath);
      if (!dbDir.existsSync()) {
        await dbDir.create(recursive: true);
      }

      // Close open Hive boxes if needed
      await Hive.close();

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          final fileName = archiveFile.name;
          if (fileName.endsWith('.hive')) {
            final outFile = File('$dbDirPath/$fileName');
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(archiveFile.content as List<int>);
          }
        }
      }

      printINFO("[SPY MUSIC Backup] Restore completed successfully from: $filePath");
      return true;
    } catch (e) {
      printERROR("[SPY MUSIC Backup] RestoreFromFile error: $e");
      return false;
    }
  }

  /// Check if a valid auto-backup file exists
  Future<Map<String, dynamic>?> getLatestBackupInfo() async {
    try {
      final backupDir = await getBackupDirectory();
      final file = File("${backupDir.path}/$backupFileName");

      if (file.existsSync()) {
        final lastModified = file.lastModifiedSync();
        final sizeBytes = file.lengthSync();
        final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);

        return {
          "exists": true,
          "path": file.path,
          "size": "$sizeKb KB",
          "date": _formatDate(lastModified),
          "lastModified": lastModified,
        };
      }
    } catch (_) {}
    return null;
  }
}
