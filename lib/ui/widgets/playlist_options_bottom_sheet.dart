import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../models/media_Item_builder.dart';
import '../../models/playling_from.dart';
import '../../models/playlist.dart';
import '../../services/piped_service.dart';
import '../../services/playlist_share_service.dart';
import '../../utils/helper.dart';
import '../player/player_controller.dart';
import '../screens/Library/library_controller.dart';
import 'common_dialog_widget.dart';
import 'create_playlist_dialog.dart';
import 'image_widget.dart';
import 'snackbar.dart';

class PlaylistOptionsBottomSheet extends StatelessWidget {
  const PlaylistOptionsBottomSheet({
    super.key,
    required this.playlist,
    this.onDeleted,
  });

  final Playlist playlist;
  final VoidCallback? onDeleted;

  static Future<T?> show<T>({
    required BuildContext context,
    required Playlist playlist,
    VoidCallback? onDeleted,
  }) {
    final rootContext = (Get.isRegistered<PlayerController>() &&
            Get.find<PlayerController>().homeScaffoldkey.currentContext != null)
        ? Get.find<PlayerController>().homeScaffoldkey.currentContext!
        : context;

    return showModalBottomSheet<T>(
      context: rootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (ctx) => PlaylistOptionsBottomSheet(
        playlist: playlist,
        onDeleted: onDeleted,
      ),
    );
  }

  static bool isSystemPlaylist(Playlist playlist) {
    final id = playlist.playlistId;
    return id == "SongDownloads" ||
        id == "SongsCache" ||
        id == "LIBRP" ||
        id == "LIBFAV";
  }

  static Future<List<MediaItem>> loadPlaylistSongs(Playlist playlist) async {
    try {
      if (playlist.isPipedPlaylist) {
        return await Get.find<PipedServices>()
            .getPlaylistSongs(playlist.playlistId);
      }
      final box = await Hive.openBox(playlist.playlistId);
      final songs = box.values
          .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
          .whereType<MediaItem>()
          .toList();
      if (playlist.playlistId != 'SongDownloads') {
        await box.close();
      }
      return playlist.playlistId == 'LIBRP' ? songs.reversed.toList() : songs;
    } catch (e) {
      printERROR("loadPlaylistSongs error: $e");
      return [];
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CommonDialog(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1322),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF0055).withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0055).withOpacity(0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0055).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFFF0055),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "deletePlaylistConfirmTitle".tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "deletePlaylistConfirmMsg"
                    .tr
                    .replaceAll("{title}", playlist.title),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      "cancel".tr,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(dialogCtx).pop(); // Close confirm dialog
                      Navigator.of(context).pop(); // Close bottom sheet

                      if (Get.isRegistered<LibraryPlaylistsController>()) {
                        final success = await Get.find<LibraryPlaylistsController>()
                            .deletePlaylist(playlist);
                        if (success) {
                          onDeleted?.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              snackbar(
                                context,
                                '${"playlist".tr} "${playlist.title}" ${"playlistDeletedSnackbar".tr}',
                                size: SanckBarSize.BIG,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF0055), Color(0xFFFF5500)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF0055).withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        "delete".tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSystem = isSystemPlaylist(playlist);
    final playerController = Get.find<PlayerController>();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.padding.bottom;

    // Make the menu taller ("mach die einfach höher dieses menü"): ~68-72% of screen height
    final double sheetHeight = min(screenHeight * 0.72, 600.0);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF0C101D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFF00D2FF).withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Top drag pill
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Playlist Thumbnail + Title + Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageWidget(
                        size: 58,
                        playlist: playlist,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<List<MediaItem>>(
                          future: loadPlaylistSongs(playlist),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length;
                            final subtitle = count != null
                                ? "$count ${'songs'.tr} • ${isSystem ? 'systemPlaylist'.tr : 'customPlaylist'.tr}"
                                : (playlist.description ?? "SPY MUSIC");
                            return Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
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
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),

            // Scrollable Options List
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    // 1. Play Playlist
                    _buildOptionTile(
                      icon: Icons.play_arrow_rounded,
                      iconColor: const Color(0xFF00D2FF),
                      iconBg: const Color(0xFF00D2FF).withOpacity(0.15),
                      title: "play".tr,
                      subtitle: "playPlaylistSub".tr,
                      onTap: () async {
                        Navigator.of(context).pop();
                        final songs = await loadPlaylistSongs(playlist);
                        if (songs.isNotEmpty) {
                          playerController.playPlayListSong(
                            songs,
                            0,
                            playfrom: PlaylingFrom(
                              name: playlist.title,
                              type: PlaylingFromType.PLAYLIST,
                            ),
                          );
                        }
                      },
                    ),

                    // 2. Enqueue
                    _buildOptionTile(
                      icon: Icons.queue_music_rounded,
                      iconColor: const Color(0xFF38EF7D),
                      iconBg: const Color(0xFF38EF7D).withOpacity(0.15),
                      title: "enqueueSongs".tr,
                      subtitle: "enqueuePlaylistSub".tr,
                      onTap: () async {
                        Navigator.of(context).pop();
                        final songs = await loadPlaylistSongs(playlist);
                        if (songs.isNotEmpty) {
                          await playerController.enqueueSongList(songs);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              snackbar(
                                context,
                                "${songs.length} ${'songsEnqueuedSnackbar'.tr}",
                                size: SanckBarSize.MEDIUM,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    // 3. Rename (Custom / Imported only)
                    if (!isSystem)
                      _buildOptionTile(
                        icon: Icons.drive_file_rename_outline_rounded,
                        iconColor: const Color(0xFFFFB800),
                        iconBg: const Color(0xFFFFB800).withOpacity(0.15),
                        title: "renamePlaylist".tr,
                        subtitle: "renamePlaylistSub".tr,
                        onTap: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => CreateNRenamePlaylistPopup(
                              renamePlaylist: true,
                              playlist: playlist,
                            ),
                          );
                        },
                      ),

                    // 4. Share / Export
                    _buildOptionTile(
                      icon: Icons.share_rounded,
                      iconColor: const Color(0xFFB537F2),
                      iconBg: const Color(0xFFB537F2).withOpacity(0.15),
                      title: "share".tr,
                      subtitle: "sharePlaylistSub".tr,
                      onTap: () async {
                        Navigator.of(context).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            snackbar(
                              context,
                              "generatingShareLink".tr,
                              size: SanckBarSize.MEDIUM,
                            ),
                          );
                        }
                        final songs = await loadPlaylistSongs(playlist);
                        await PlaylistShareService.instance
                            .sharePlaylist(playlist, songs);
                      },
                    ),

                    // 5. Delete (Custom / Imported only)
                    if (!isSystem)
                      _buildOptionTile(
                        icon: Icons.delete_forever_rounded,
                        iconColor: const Color(0xFFFF0055),
                        iconBg: const Color(0xFFFF0055).withOpacity(0.15),
                        title: "removePlaylist".tr,
                        subtitle: "removePlaylistSub".tr,
                        isDanger: true,
                        onTap: () => _showDeleteConfirmation(context),
                      ),

                    const SizedBox(height: 16),

                    // Close Button
                    Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded,
                                  size: 18, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text(
                                "close".tr,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24 + bottomInset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDanger
                  ? const Color(0xFFFF0055).withOpacity(0.07)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDanger
                    ? const Color(0xFFFF0055).withOpacity(0.25)
                    : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              isDanger ? const Color(0xFFFF3366) : Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2.5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
