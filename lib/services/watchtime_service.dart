import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';
import '../utils/helper.dart';

class ArtistStat {
  final String name;
  final int playtimeSec;
  final int playCount;

  ArtistStat({
    required this.name,
    required this.playtimeSec,
    required this.playCount,
  });
}

class SongStat {
  final String id;
  final String title;
  final String artist;
  final int playtimeSec;
  final int playCount;
  final String platform;

  SongStat({
    required this.id,
    required this.title,
    required this.artist,
    required this.playtimeSec,
    required this.playCount,
    required this.platform,
  });
}

class WatchtimeService {
  static const String boxName = "WatchtimeStats";

  /// Ticks whenever playtime is recorded so UI widgets can update in real-time
  static final ValueNotifier<int> watchtimeNotifier = ValueNotifier<int>(0);

  static Box _getBox() {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError("WatchtimeStats box is not open");
    }
    return Hive.box(boxName);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  static String _monthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  static String _yearKey() {
    final now = DateTime.now();
    return "${now.year}";
  }

  static String _detectPlatform(MediaItem song) {
    final id = song.id;
    if (id.startsWith('sc_') || song.extras?['isSoundCloud'] == true) {
      return 'SoundCloud';
    } else if (id.startsWith('sp_') || song.extras?['isSpotify'] == true) {
      return 'Spotify';
    } else if (id.startsWith('az_') || song.extras?['isAmazon'] == true) {
      return 'Amazon Music';
    } else {
      return 'YouTube';
    }
  }

  /// Records active playback duration for the currently playing song
  static void recordPlaytime(MediaItem song, {int seconds = 5}) {
    try {
      final box = _getBox();
      final today = _todayKey();
      final month = _monthKey();
      final year = _yearKey();
      final platform = _detectPlatform(song);
      final rawArtist = (song.artist ?? 'unknownArtist'.tr).trim();
      final artist = rawArtist.isEmpty ? 'unknownArtist'.tr : rawArtist;

      // 1. Daily, Monthly, Yearly Playtime
      final dayKey = 'daily_$today';
      final curDay = (box.get(dayKey, defaultValue: 0) as num).toInt();
      box.put(dayKey, curDay + seconds);

      final monthDataKey = 'monthly_$month';
      final curMonth = (box.get(monthDataKey, defaultValue: 0) as num).toInt();
      box.put(monthDataKey, curMonth + seconds);

      final yearDataKey = 'yearly_$year';
      final curYear = (box.get(yearDataKey, defaultValue: 0) as num).toInt();
      box.put(yearDataKey, curYear + seconds);

      // Track all recorded dates for weekly/custom calculations
      final dates = List<String>.from(box.get('recorded_dates', defaultValue: <String>[]) as List);
      if (!dates.contains(today)) {
        dates.add(today);
        box.put('recorded_dates', dates);
      }

      // 2. Platform Playtime
      final platKey = 'plat_$platform';
      final curPlat = (box.get(platKey, defaultValue: 0) as num).toInt();
      box.put(platKey, curPlat + seconds);

      // 3. Artist Playtime
      final artistTimeKey = 'artist_time_$artist';
      final curArtistTime = (box.get(artistTimeKey, defaultValue: 0) as num).toInt();
      box.put(artistTimeKey, curArtistTime + seconds);

      final artists = List<String>.from(box.get('all_artists', defaultValue: <String>[]) as List);
      if (!artists.contains(artist)) {
        artists.add(artist);
        box.put('all_artists', artists);
      }

      // 4. Song Playtime & Meta
      final songKey = 'song_time_${song.id}';
      final curSongTime = (box.get(songKey, defaultValue: 0) as num).toInt();
      box.put(songKey, curSongTime + seconds);

      final songMetaKey = 'song_meta_${song.id}';
      if (!box.containsKey(songMetaKey)) {
        box.put(songMetaKey, {
          'id': song.id,
          'title': song.title,
          'artist': artist,
          'platform': platform,
        });
      }

      final songList = List<String>.from(box.get('all_songs', defaultValue: <String>[]) as List);
      if (!songList.contains(song.id)) {
        songList.add(song.id);
        box.put('all_songs', songList);
      }

      // Notify UI
      watchtimeNotifier.value = watchtimeNotifier.value + seconds;
    } catch (e) {
      printERROR("WatchtimeService.recordPlaytime error: $e");
    }
  }

  /// Record song start for play count tracking
  static void recordSongStart(MediaItem song) {
    try {
      final box = _getBox();
      final rawArtist = (song.artist ?? 'unknownArtist'.tr).trim();
      final artist = rawArtist.isEmpty ? 'unknownArtist'.tr : rawArtist;

      // Artist play count
      final aCountKey = 'artist_count_$artist';
      final curACount = (box.get(aCountKey, defaultValue: 0) as num).toInt();
      box.put(aCountKey, curACount + 1);

      // Song play count
      final sCountKey = 'song_count_${song.id}';
      final curSCount = (box.get(sCountKey, defaultValue: 0) as num).toInt();
      box.put(sCountKey, curSCount + 1);
    } catch (_) {}
  }

  /// Get daily playtime in seconds
  static int getDailyPlaytimeSec() {
    try {
      final box = _getBox();
      return (box.get('daily_${_todayKey()}', defaultValue: 0) as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  /// Get weekly playtime (last 7 days combined) in seconds
  static int getWeeklyPlaytimeSec() {
    try {
      final box = _getBox();
      int total = 0;
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final key = 'daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        total += (box.get(key, defaultValue: 0) as num).toInt();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Get monthly playtime in seconds
  static int getMonthlyPlaytimeSec() {
    try {
      final box = _getBox();
      return (box.get('monthly_${_monthKey()}', defaultValue: 0) as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  /// Get yearly playtime in seconds
  static int getYearlyPlaytimeSec() {
    try {
      final box = _getBox();
      return (box.get('yearly_${_yearKey()}', defaultValue: 0) as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  /// Get top artists sorted by listened playtime
  static List<ArtistStat> getTopArtists({int limit = 10}) {
    try {
      final box = _getBox();
      final artists = List<String>.from(box.get('all_artists', defaultValue: <String>[]) as List);
      final List<ArtistStat> list = [];

      for (var a in artists) {
        final time = (box.get('artist_time_$a', defaultValue: 0) as num).toInt();
        final count = (box.get('artist_count_$a', defaultValue: 0) as num).toInt();
        if (time > 0 || count > 0) {
          list.add(ArtistStat(name: a, playtimeSec: time, playCount: count));
        }
      }

      list.sort((a, b) => b.playtimeSec.compareTo(a.playtimeSec));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static bool get _isEnglish {
    try {
      final code = Hive.box("AppPrefs").get('currentAppLanguageCode') ?? Get.locale?.languageCode ?? 'en';
      return code.toString().toLowerCase().startsWith('en');
    } catch (_) {
      return (Get.locale?.languageCode ?? 'en').toLowerCase().startsWith('en');
    }
  }

  /// Get top songs sorted by play count (or playtime as tiebreaker)
  static List<SongStat> getTopSongs({int limit = 10}) {
    try {
      final box = _getBox();
      final songIds = List<String>.from(box.get('all_songs', defaultValue: <String>[]) as List);
      final List<SongStat> list = [];

      for (var id in songIds) {
        final time = (box.get('song_time_$id', defaultValue: 0) as num).toInt();
        final count = (box.get('song_count_$id', defaultValue: 0) as num).toInt();
        final meta = box.get('song_meta_$id') as Map?;
        final title = meta?['title']?.toString() ?? 'Track';
        final rawArtist = meta?['artist']?.toString();
        final artist = (rawArtist == null || rawArtist.isEmpty || rawArtist == 'Unbekannt')
            ? 'unknownArtist'.tr
            : rawArtist;
        final platform = meta?['platform']?.toString() ?? 'All';

        if (time > 0 || count > 0) {
          list.add(SongStat(
            id: id,
            title: title,
            artist: artist,
            playtimeSec: time,
            playCount: count > 0 ? count : (time > 60 ? (time ~/ 180) + 1 : 1),
            platform: platform,
          ));
        }
      }

      list.sort((a, b) {
        final countCmp = b.playCount.compareTo(a.playCount);
        if (countCmp != 0) return countCmp;
        return b.playtimeSec.compareTo(a.playtimeSec);
      });
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Platform playtime breakdown
  static Map<String, int> getPlatformBreakdown() {
    try {
      final box = _getBox();
      final platforms = ['YouTube', 'SoundCloud', 'Spotify', 'Amazon Music'];
      final Map<String, int> map = {};
      for (var p in platforms) {
        map[p] = (box.get('plat_$p', defaultValue: 0) as num).toInt();
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Format seconds into readable human format: e.g. "2h 45m" or "45m" or "32s"
  static String formatDuration(int totalSeconds) {
    final isEn = _isEnglish;
    if (totalSeconds <= 0) return isEn ? "0 min" : "0 Min.";
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      final hUnit = isEn ? "h" : "Std.";
      final mUnit = isEn ? "min" : "Min.";
      return "$hours $hUnit ${minutes > 0 ? '$minutes $mUnit' : ''}".trim();
    } else if (minutes > 0) {
      final mUnit = isEn ? "min" : "Min.";
      return "$minutes $mUnit";
    } else {
      final sUnit = isEn ? "sec" : "Sek.";
      return "$seconds $sUnit";
    }
  }

  /// Reset all watchtime statistics
  static Future<void> resetAllStats() async {
    try {
      final box = _getBox();
      await box.clear();
      watchtimeNotifier.value = 0;
    } catch (e) {
      printERROR("resetAllStats error: $e");
    }
  }
}
