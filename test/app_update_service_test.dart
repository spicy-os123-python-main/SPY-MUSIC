import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('update_test_');
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AppUpdateService APK Integrity Tests', () {
    test('Non-existent file fails verification', () async {
      final file = File('${tempDir.path}/non_existent.apk');
      final valid = await AppUpdateService.verifyApkFile(file);
      expect(valid, isFalse);
    });

    test('File under 15MB fails verification', () async {
      final file = File('${tempDir.path}/small.apk');
      await file.writeAsBytes(Uint8List(1024)); // 1 KB
      final valid = await AppUpdateService.verifyApkFile(file);
      expect(valid, isFalse);
    });

    test('File without ZIP magic bytes fails verification', () async {
      final file = File('${tempDir.path}/fake.apk');
      // Create a 16MB file with non-ZIP header
      final raf = await file.open(mode: FileMode.write);
      await raf.writeFrom(Uint8List.fromList([0x3c, 0x68, 0x74, 0x6d])); // "<htm"
      await raf.setPosition(16 * 1024 * 1024 - 1);
      await raf.writeByte(0);
      await raf.close();

      final valid = await AppUpdateService.verifyApkFile(file);
      expect(valid, isFalse);
    });

    test('File missing EOCD record fails verification (truncated download simulation)', () async {
      final file = File('${tempDir.path}/truncated.apk');
      final raf = await file.open(mode: FileMode.write);
      // Valid ZIP magic header PK\x03\x04
      await raf.writeFrom(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]));
      await raf.setPosition(16 * 1024 * 1024 - 1);
      await raf.writeByte(0);
      await raf.close();

      final valid = await AppUpdateService.verifyApkFile(file);
      expect(valid, isFalse);
    });

    test('Valid simulated APK with PK header, size >= 15MB and EOCD passes verification', () async {
      final file = File('${tempDir.path}/valid_mock.apk');
      final raf = await file.open(mode: FileMode.write);
      // Valid ZIP magic header PK\x03\x04
      await raf.writeFrom(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]));
      await raf.setPosition(16 * 1024 * 1024 - 22);
      // Valid EOCD record PK\x05\x06
      await raf.writeFrom(Uint8List.fromList([
        0x50, 0x4B, 0x05, 0x06, // signature
        0x00, 0x00, // disk number
        0x00, 0x00, // start disk
        0x01, 0x00, // total entries this disk
        0x01, 0x00, // total entries
        0x10, 0x00, 0x00, 0x00, // central directory size
        0x20, 0x00, 0x00, 0x00, // central directory offset
        0x00, 0x00, // comment length
      ]));
      await raf.close();

      final valid = await AppUpdateService.verifyApkFile(file);
      expect(valid, isTrue);

      // Verify with size check
      final validWithSize = await AppUpdateService.verifyApkFile(file, expectedBytes: 16 * 1024 * 1024);
      expect(validWithSize, isTrue);

      // Mismatched size fails
      final invalidSize = await AppUpdateService.verifyApkFile(file, expectedBytes: 20 * 1024 * 1024);
      expect(invalidSize, isFalse);
    });
  });
}
