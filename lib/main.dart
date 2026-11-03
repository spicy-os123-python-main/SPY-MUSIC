import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terminate_restart/terminate_restart.dart';

import '/ui/screens/Search/search_screen_controller.dart';
import '/utils/get_localization.dart';
import '/services/downloader.dart';
import '/services/piped_service.dart';
import '/services/discord_service.dart';
import 'utils/app_link_controller.dart';
import '/services/audio_handler.dart';
import '/services/music_service.dart';
import '/ui/home.dart';
import '/ui/player/player_controller.dart';
import 'ui/screens/Settings/settings_screen_controller.dart';
import 'package:media_kit/media_kit.dart';
import '/ui/utils/theme_controller.dart';
import 'ui/screens/Home/home_screen_controller.dart';
import 'ui/screens/Library/library_controller.dart';
import 'utils/system_tray.dart';
import 'utils/update_check_flag_file.dart';
import 'services/playlist_repair_service.dart';
import 'utils/helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    printERROR('${details.exceptionAsString()}\n${details.stack}', tag: 'FlutterError');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    printERROR('$error\n$stack', tag: 'PlatformError');
    return true;
  };
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('MediaKit init: $e');
  }
  try {
    await initHive();
    _setAppInitPrefs();
  } catch (e) {
    debugPrint('Hive init: $e');
  }
  try {
    startApplicationServices();
  } catch (e) {
    debugPrint('Services init: $e');
  }
  try {
    final audioHandler = await initAudioService();
    Get.put<AudioHandler>(audioHandler, permanent: true);
  } catch (e) {
    debugPrint('AudioService init: $e');
    try {
      Get.put<AudioHandler>(MyAudioHandler(), permanent: true);
    } catch (_) {}
  }
  try {
    WidgetsBinding.instance.addObserver(LifecycleHandler());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    TerminateRestart.instance.initialize();
  } catch (e) {
    debugPrint('System UI init: $e');
  }
  runApp(const MyApp());
  Future.microtask(() async {
    try {
      DiscordService().init();
    } catch (_) {}
    try {
      await PlaylistRepairService().autoRepairOnLaunch();
    } catch (e) {
      debugPrint('Auto repair: $e');
    }
  });
}

class SpyScrollBehavior extends MaterialScrollBehavior {
  const SpyScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (!GetPlatform.isDesktop) Get.put(AppLinksController());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return GetMaterialApp(
        title: 'SPY MUSIC',
        scrollBehavior: const SpyScrollBehavior(),
        home: const Home(),
        debugShowCheckedModeBanner: false,
        defaultTransition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 260),
        translations: Languages(),
        locale: Locale(
          Hive.isBoxOpen("AppPrefs")
              ? (Hive.box("AppPrefs").get('currentAppLanguageCode') ?? "en")
              : "en",
        ),
        fallbackLocale: const Locale("en"),
        builder: (context, child) {
          final mQuery = MediaQuery.of(context);
          final scale =
              mQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.1);
          return Stack(
            children: [
              GetX<ThemeController>(
                builder: (controller) => MediaQuery(
                  data: mQuery.copyWith(textScaler: scale),
                  child: AnimatedTheme(
                      duration: const Duration(milliseconds: 700),
                      data: controller.themedata.value!,
                      child: child!),
                ),
              ),
              GestureDetector(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.transparent,
                    height: mQuery.padding.bottom,
                    width: mQuery.size.width,
                  ),
                ),
              )
            ],
          );
        });
  }
}

Future<void> startApplicationServices() async {
  Get.lazyPut(() => PipedServices(), fenix: true);
  Get.lazyPut(() => MusicServices(), fenix: true);
  Get.lazyPut(() => ThemeController(), fenix: true);
  Get.lazyPut(() => PlayerController(), fenix: true);
  Get.lazyPut(() => HomeScreenController(), fenix: true);
  Get.lazyPut(() => LibrarySongsController(), fenix: true);
  Get.lazyPut(() => LibraryPlaylistsController(), fenix: true);
  Get.lazyPut(() => LibraryAlbumsController(), fenix: true);
  Get.lazyPut(() => LibraryArtistsController(), fenix: true);
  Get.lazyPut(() => SettingsScreenController(), fenix: true);
  Get.lazyPut(() => Downloader(), fenix: true);
  Get.lazyPut(() => DiscordService(), fenix: true);
  if (GetPlatform.isDesktop) {
    Get.lazyPut(() => SearchScreenController(), fenix: true);
    Get.put(DesktopSystemTray());
  }
}

Future<void> _safeOpenBox(String name) async {
  try {
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox(name).timeout(const Duration(seconds: 3));
    }
  } catch (e) {
    printERROR("Failed to open Hive box '$name': $e. Repairing...");
    try {
      await Hive.deleteBoxFromDisk(name);
      await Hive.openBox(name).timeout(const Duration(seconds: 2));
    } catch (err) {
      printERROR("Fatal error opening box '$name': $err");
    }
  }
}

Future<void> initHive() async {
  try {
    String applicationDataDirectoryPath;
    if (GetPlatform.isDesktop) {
      applicationDataDirectoryPath =
          "${(await getApplicationSupportDirectory().timeout(const Duration(seconds: 2))).path}/db";
    } else {
      applicationDataDirectoryPath =
          (await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 2))).path;
    }
    await Hive.initFlutter(applicationDataDirectoryPath);
  } catch (e) {
    printERROR("Hive.initFlutter error: $e");
  }

  await Future.wait([
    _safeOpenBox("SongsCache"),
    _safeOpenBox("SongDownloads"),
    _safeOpenBox('SongsUrlCache'),
    _safeOpenBox("AppPrefs"),
    _safeOpenBox("appPrefs"),
    _safeOpenBox("WatchtimeStats"),
  ]);
}

void _setAppInitPrefs() {
  try {
    if (!Hive.isBoxOpen("AppPrefs")) return;
    final appPrefs = Hive.box("AppPrefs");
    if (appPrefs.isEmpty) {
      appPrefs.putAll({
        'themeModeType': 0,
        "cacheSongs": false,
        "skipSilenceEnabled": false,
        'streamingQuality': 0,
        'dataSaverMode': 0,
        'themePrimaryColor': 4278199603,
        'discoverContentType': "QP",
        'newVersionVisibility': updateCheckFlag,
        "cacheHomeScreenData": true
      });
    }
  } catch (e) {
    printERROR("Error setting initial app prefs: $e");
  }
}

class LifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    try {
      if (state == AppLifecycleState.resumed) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else if (state == AppLifecycleState.detached) {
        if (Get.isRegistered<AudioHandler>()) {
          await Get.find<AudioHandler>().customAction("saveSession");
        }
      }
    } catch (_) {}
  }
}
