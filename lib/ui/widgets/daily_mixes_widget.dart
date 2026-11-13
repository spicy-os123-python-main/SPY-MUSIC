import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../player/player_controller.dart';
import '../../services/music_service.dart';
import '../../utils/helper.dart';

class DailyMixInfo {
  final String id;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final IconData icon;
  final List<String> seedQueries;

  const DailyMixInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.icon,
    required this.seedQueries,
  });
}

/// Dynamic Daily Mixes section placed right near the top of the Home Screen.
class DailyMixesWidget extends StatefulWidget {
  const DailyMixesWidget({super.key});

  static const List<DailyMixInfo> mixTemplates = [
    DailyMixInfo(
      id: "spy_daily_mix_1",
      title: "Daily Mix 1",
      subtitle: "Deutschrap & Urban Hits",
      gradientColors: [Color(0xFFDC2626), Color(0xFF7F1D1D), Color(0xFF1E1B4B)],
      icon: Icons.local_fire_department_rounded,
      seedQueries: ["Deutschrap 2026", "2LADE", "Apache 207", "Luciano"],
    ),
    DailyMixInfo(
      id: "spy_daily_mix_2",
      title: "Daily Mix 2",
      subtitle: "Global Top Hits & Pop",
      gradientColors: [Color(0xFF00D2FF), Color(0xFF0051FF), Color(0xFF0F172A)],
      icon: Icons.trending_up_rounded,
      seedQueries: ["Top Hits 2026", "The Weeknd", "Dua Lipa", "Billie Eilish"],
    ),
    DailyMixInfo(
      id: "spy_daily_mix_3",
      title: "Daily Mix 3",
      subtitle: "Chill, Lofi & Ambient",
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF4C1D95), Color(0xFF0F172A)],
      icon: Icons.nightlight_round,
      seedQueries: ["Lofi Hip Hop Beats", "Chillhop", "Late Night Vibes"],
    ),
    DailyMixInfo(
      id: "spy_daily_mix_4",
      title: "Daily Mix 4",
      subtitle: "Club, EDM & Viral Remixes",
      gradientColors: [Color(0xFF10B981), Color(0xFF064E3B), Color(0xFF022C22)],
      icon: Icons.flash_on_rounded,
      seedQueries: ["Viral Remixes", "SoundCloud EDM", "Bass Boosted Trap"],
    ),
  ];

  @override
  State<DailyMixesWidget> createState() => _DailyMixesWidgetState();
}

class _DailyMixesWidgetState extends State<DailyMixesWidget> {
  static const List<DailyMixInfo> _mixTemplates = DailyMixesWidget.mixTemplates;

  Future<void> _playOrOpenMix(DailyMixInfo mix) async {
    final playerController = Get.find<PlayerController>();
    final musicServices = Get.find<MusicServices>();

    // Try to load cached or live songs for this mix
    try {
      final query = mix.seedQueries.first;
      final searchResult = await musicServices.search(query, filter: "songs", limit: 20);
      final rawSongs = (searchResult["Songs"] as List?) ?? (searchResult["mixed"] as List?) ?? [];
      final songs = List<MediaItem>.from(rawSongs.whereType<MediaItem>());

      if (songs.isNotEmpty) {
        await playerController.playPlayListSong(songs, 0);
        if (playerController.playerPanelController.isAttached) {
          playerController.playerPanelController.open();
        }
        return;
      }
    } catch (e) {
      printERROR("Error loading daily mix: $e");
    }

    // Fallback: If network search fails, try favorite songs
    try {
      final favBox = Hive.box("LIBFAV");
      if (favBox.isNotEmpty) {
        final favSongs = favBox.values.map((e) => MediaItem(
          id: e['id'] ?? '',
          title: e['title'] ?? 'Song',
          artist: e['artist'] ?? '',
          artUri: Uri.tryParse(e['artUri'] ?? ''),
        )).toList();
        if (favSongs.isNotEmpty) {
          playerController.playPlayListSong(favSongs, 0);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFFF5722), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "dailyMixesTitle".tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                "dailyFresh".tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _mixTemplates.length,
            itemBuilder: (context, index) {
              final mix = _mixTemplates[index];
              return Container(
                width: 145,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _playOrOpenMix(mix),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: mix.gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mix.gradientColors.first.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Icon(mix.icon, size: 16, color: Colors.white),
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.white12,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mix.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mix.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
