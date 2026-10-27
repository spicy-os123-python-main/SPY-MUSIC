import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/create_playlist_dialog.dart';
import '../../widgets/import_playlist_dialog.dart';
import '../Watchtime/watchtime_screen.dart';
import 'library.dart';

class CombinedLibrary extends StatelessWidget {
  const CombinedLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final tabCon = Get.put(CombinedLibraryController());

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 85,
        backgroundColor: Theme.of(context).canvasColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 50.0, right: 10),
            child: SizedBox(
              height: 40,
              width: 50,
              child: FittedBox(
                child: FloatingActionButton(
                    heroTag: 'watchtimeStatsBtn',
                    elevation: 0,
                    tooltip: 'Watchtime Tracking',
                    backgroundColor: const Color(0xFF1B2338),
                    onPressed: () {
                      tabCon.tabController.animateTo(4);
                    },
                    child: const Icon(Icons.timer_rounded, color: Color(0xFF00D2FF))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50.0, right: 10),
            child: SizedBox(
              height: 40,
              width: 50,
              child: FittedBox(
                child: FloatingActionButton(
                    heroTag: 'importPlaylistBtn',
                    elevation: 0,
                    tooltip: 'Playlist importieren',
                    backgroundColor: const Color(0xFF00D2FF),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              const ImportPlaylistDialog());
                    },
                    child: const Icon(Icons.cloud_download_rounded, color: Colors.black)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50.0, right: 25),
            child: SizedBox(
              height: 40,
              width: 50,
              child: FittedBox(
                child: FloatingActionButton.extended(
                    heroTag: 'createPlaylistBtn',
                    elevation: 0,
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              const CreateNRenamePlaylistPopup());
                    },
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.add,
                        ),
                      ],
                    )),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          splashFactory: NoSplash.splashFactory,
          controller: tabCon.tabController,
          tabs: [
            Tab(text: "songs".tr),
            Tab(text: "playlists".tr),
            Tab(text: "albums".tr),
            Tab(text: "artists".tr),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded, size: 16, color: Color(0xFF00D2FF)),
                  SizedBox(width: 6),
                  Text("Watchtime"),
                ],
              ),
            ),
          ],
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 60.0, left: 5),
          child:
              Text('library'.tr, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      body: TabBarView(
        controller: tabCon.tabController,
        children: const [
          SongsLibraryWidget(
            isBottomNavActive: true,
          ),
          PlaylistNAlbumLibraryWidget(
              isAlbumContent: false, isBottomNavActive: true),
          PlaylistNAlbumLibraryWidget(isBottomNavActive: true),
          LibraryArtistWidget(isBottomNavActive: true),
          WatchtimeScreen(isEmbedded: true),
        ],
      ),
    );
  }
}

class CombinedLibraryController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(vsync: this, length: 5);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
