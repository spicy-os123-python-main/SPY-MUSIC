import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/watchtime_service.dart';

class WatchtimeScreen extends StatelessWidget {
  const WatchtimeScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final bodyContent = ValueListenableBuilder<int>(
      valueListenable: WatchtimeService.watchtimeNotifier,
      builder: (context, _, __) {
        final dailySec = WatchtimeService.getDailyPlaytimeSec();
        final weeklySec = WatchtimeService.getWeeklyPlaytimeSec();
        final monthlySec = WatchtimeService.getMonthlyPlaytimeSec();
        final yearlySec = WatchtimeService.getYearlyPlaytimeSec();
        final topArtists = WatchtimeService.getTopArtists(limit: 10);
        final topSongs = WatchtimeService.getTopSongs(limit: 10);
        final platforms = WatchtimeService.getPlatformBreakdown();

        final int totalPlatformSec = platforms.values.fold(0, (a, b) => a + b);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: isEmbedded ? 12 : 12,
            bottom: isEmbedded ? 120 : 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003859), Color(0xFF0D1B2A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Color(0xFF00D2FF),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Gesamte Spielzeit",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Kombinierte Hörzeit aller Plattformen\n(YouTube • SoundCloud • Spotify • Amazon)",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4 Stat Cards in 2x2 Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "Heute",
                        timeStr: WatchtimeService.formatDuration(dailySec),
                        icon: Icons.today_rounded,
                        accentColor: const Color(0xFF00D2FF),
                        subtitle: "Tägliche Playtime",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: "Woche",
                        timeStr: WatchtimeService.formatDuration(weeklySec),
                        icon: Icons.date_range_rounded,
                        accentColor: const Color(0xFF38EF7D),
                        subtitle: "Letzte 7 Tage",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "Monat",
                        timeStr: WatchtimeService.formatDuration(monthlySec),
                        icon: Icons.calendar_month_rounded,
                        accentColor: const Color(0xFFFF9900),
                        subtitle: "Aktueller Monat",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: "Jahr",
                        timeStr: WatchtimeService.formatDuration(yearlySec),
                        icon: Icons.hourglass_top_rounded,
                        accentColor: const Color(0xFFB537F2),
                        subtitle: "Aktuelles Jahr",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Platform Breakdown Section
                _buildSectionHeader("Plattform-Übersicht", Icons.pie_chart_rounded),
                const SizedBox(height: 10),
                _buildPlatformBar(platforms, totalPlatformSec),

                const SizedBox(height: 28),

                // Top Artists Section
                _buildSectionHeader("Meistgehörte Künstler", Icons.star_rounded),
                const SizedBox(height: 10),
                if (topArtists.isEmpty)
                  _buildEmptyState("Noch keine Künstler-Statistiken vorhanden.")
                else
                  ...topArtists.asMap().entries.map((entry) {
                    final index = entry.key;
                    final artist = entry.value;
                    final maxSec = topArtists.first.playtimeSec > 0
                        ? topArtists.first.playtimeSec
                        : 1;
                    return _buildArtistRow(index, artist, maxSec);
                  }),

                const SizedBox(height: 28),

                // Top Songs Section
                _buildSectionHeader("Meistgehörte Songs", Icons.library_music_rounded),
                const SizedBox(height: 10),
                if (topSongs.isEmpty)
                  _buildEmptyState("Noch keine Song-Statistiken vorhanden.")
                else
                  ...topSongs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final song = entry.value;
                    return _buildSongRow(index, song);
                  }),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      );

    if (isEmbedded) {
      return Container(
        color: const Color(0xFF0F0F14),
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Watchtime Tracking",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            tooltip: "Statistiken zurücksetzen",
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D2FF), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String timeStr,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBar(Map<String, int> platforms, int totalSec) {
    final colors = {
      'YouTube': const Color(0xFFFF0000),
      'SoundCloud': const Color(0xFFFF5500),
      'Spotify': const Color(0xFF1DB954),
      'Amazon Music': const Color(0xFF00A8E1),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: platforms.entries.map((entry) {
                  final sec = entry.value;
                  final pct = totalSec > 0 ? (sec / totalSec) : 0.25;
                  if (pct <= 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: max(1, (pct * 100).toInt()),
                    child: Container(color: colors[entry.key] ?? Colors.grey),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: platforms.entries.map((entry) {
              final color = colors[entry.key] ?? Colors.grey;
              final sec = entry.value;
              final pct = totalSec > 0 ? ((sec / totalSec) * 100).toInt() : 0;
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${entry.key}: $pct%",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistRow(int index, ArtistStat artist, int maxSec) {
    final medal = index == 0
        ? "🥇"
        : index == 1
            ? "🥈"
            : index == 2
                ? "🥉"
                : "#${index + 1}";
    final progress = maxSec > 0 ? (artist.playtimeSec / maxSec).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  medal,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                WatchtimeService.formatDuration(artist.playtimeSec),
                style: const TextStyle(
                  color: Color(0xFF00D2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00D2FF)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongRow(int index, SongStat song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            "#${index + 1}",
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.artist,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                WatchtimeService.formatDuration(song.playtimeSec),
                style: const TextStyle(color: Color(0xFF38EF7D), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (song.playCount > 0)
                Text(
                  "${song.playCount}x gespielt",
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Statistiken zurücksetzen?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Möchtest du wirklich alle aufgezeichneten Spielzeiten und Top-Künstler löschen?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Abbrechen", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await WatchtimeService.resetAllStats();
            },
            child: const Text("Zurücksetzen", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
