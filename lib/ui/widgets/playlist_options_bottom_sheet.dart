import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/media_Item_builder.dart';
import '../../models/playling_from.dart';
import '../../models/playlist.dart';
import '../../services/piped_service.dart';
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
                  const Expanded(
                    child: Text(
                      "Playlist löschen?",
                      style: TextStyle(
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
                'Möchtest du die Playlist "${playlist.title}" wirklich dauerhaft entfernen? Die Songs in der Playlist werden gelöscht.',
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
                                'Playlist "${playlist.title}" gelöscht',
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
                      child: const Text(
                        "Löschen",
                        style: TextStyle(
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C101D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFF00D2FF).withOpacity(0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Playlist Thumbnail + Title + Info
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ImageWidget(
                        size: 54,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FutureBuilder<List<MediaItem>>(
                          future: loadPlaylistSongs(playlist),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length;
                            final subtitle = count != null
                                ? "$count Songs • ${isSystem ? 'System-Playlist' : 'Eigene Playlist'}"
                                : (playlist.description ?? "SPY MUSIC");
                            return Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 10),

              // 1. Play Playlist
              _buildOptionTile(
                icon: Icons.play_arrow_rounded,
                iconColor: const Color(0xFF00D2FF),
                iconBg: const Color(0xFF00D2FF).withOpacity(0.15),
                title: "play".tr,
                subtitle: "Playlist von Beginn an abspielen",
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
                subtitle: "Titel an das Ende der Warteschlange anfügen",
                onTap: () async {
                  Navigator.of(context).pop();
                  final songs = await loadPlaylistSongs(playlist);
                  if (songs.isNotEmpty) {
                    await playerController.enqueueSongList(songs);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        snackbar(
                          context,
                          "${songs.length} Songs zur Warteschlange hinzugefügt",
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
                  subtitle: "Neuen Namen für diese Playlist vergeben",
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
                subtitle: "Trackliste als Text oder Link teilen",
                onTap: () async {
                  Navigator.of(context).pop();
                  final songs = await loadPlaylistSongs(playlist);
                  final buffer = StringBuffer();
                  buffer.writeln('🎵 SPY MUSIC Playlist: "${playlist.title}"');
                  if (songs.isNotEmpty) {
                    buffer.writeln('${songs.length} Songs:\n');
                    for (int i = 0; i < min(30, songs.length); i++) {
                      final s = songs[i];
                      buffer.writeln(
                          '${i + 1}. ${s.title} - ${s.artist ?? "Unbekannt"}');
                    }
                    if (songs.length > 30) {
                      buffer.writeln('... und ${songs.length - 30} weitere');
                    }
                  }
                  await Share.share(buffer.toString());
                },
              ),

              // 5. Delete (Custom / Imported only)
              if (!isSystem)
                _buildOptionTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFFF0055),
                  iconBg: const Color(0xFFFF0055).withOpacity(0.15),
                  title: "removePlaylist".tr,
                  subtitle: "Playlist dauerhaft aus der Bibliothek entfernen",
                  isDanger: true,
                  onTap: () => _showDeleteConfirmation(context),
                ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDanger ? const Color(0xFFFF3366) : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.3),
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
