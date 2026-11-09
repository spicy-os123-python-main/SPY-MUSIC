import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '/native_bindings/andrid_utils.dart' show SDKInt;
class PermissionService {
  static Future<bool> getExtStoragePermission() async {
    if (GetPlatform.isDesktop) {
      return Future.value(true);
    }
    final sdk = SDKInt.Companion.getSDKInt();
    if (sdk < 30) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        await [
          Permission.storage,
          Permission.accessMediaLocation,
          Permission.mediaLibrary,
        ].request();
      }

      if (await Permission.storage.isPermanentlyDenied) {
        await openAppSettings();
      }

      return (await Permission.storage.status).isGranted;
    } else {
      // Android 13+ (API 33+) supports granular Permission.audio
      if (await Permission.audio.isGranted ||
          await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }
      if (sdk >= 33) {
        final audioStatus = await Permission.audio.request();
        if (audioStatus.isGranted) return true;
      }
      if (!await Permission.manageExternalStorage.isGranted) {
        final permission = await Permission.manageExternalStorage.request();
        return permission.isGranted;
      }
      return true;
    }
  }
}
