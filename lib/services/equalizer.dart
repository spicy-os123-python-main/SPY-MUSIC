import 'package:get/get.dart';
import 'package:spymusic/native_bindings/andrid_utils.dart';
import 'package:jni/jni.dart';
import '../utils/helper.dart';

class EqualizerService {
  static bool openEqualizer(int sessionId) {
    if (!GetPlatform.isAndroid) return false;
    try {
      JObject activity = JObject.fromReference(Jni.getCurrentActivity());
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      final success = Equalizer().openEqualizer(sessionId, context, activity);
      activity.release();
      context.release();
      return success;
    } catch (e) {
      printERROR("openEqualizer error: $e");
      return false;
    }
  }

  static void initAudioEffect(int sessionId) {
    if (!GetPlatform.isAndroid) return;
    try {
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().initAudioEffect(sessionId, context);
      context.release();
    } catch (e) {
      printERROR("initAudioEffect error: $e");
    }
  }

  static void endAudioEffect(int sessionId) {
    if (!GetPlatform.isAndroid) return;
    try {
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().endAudioEffect(sessionId, context);
      context.release();
    } catch (e) {
      printERROR("endAudioEffect error: $e");
    }
  }
}
