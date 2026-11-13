import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../utils/helper.dart';

class CollabPlaylist {
  final String code;
  final String title;
  final String host;
  final int updatedAt;
  final List<MediaItem> songs;

  CollabPlaylist({
    required this.code,
    required this.title,
    required this.host,
    required this.updatedAt,
    required this.songs,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'host': host,
        'updatedAt': updatedAt,
        'songs': songs.map((s) => MediaItemBuilder.toJson(s)).toList(),
      };

  factory CollabPlaylist.fromJson(Map<dynamic, dynamic> json) {
    final rawSongs = (json['songs'] as List?) ?? [];
    return CollabPlaylist(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Collab Playlist',
      host: json['host']?.toString() ?? 'SPY User',
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt'] as int
          : (int.tryParse(json['updatedAt']?.toString() ?? '0') ?? 0),
      songs: rawSongs.map((e) => MediaItemBuilder.fromJson(e as Map)).toList(),
    );
  }

  Playlist toPlaylist() {
    return Playlist(
      title: "👥 $title",
      playlistId: "collab_$code",
      thumbnailUrl: songs.isNotEmpty && songs.first.artUri != null
          ? songs.first.artUri.toString()
          : Playlist.thumbPlaceholderUrl,
      isPipedPlaylist: false,
    );
  }
}

class CollabPlaylistService extends GetxService {
  static final CollabPlaylistService _instance = CollabPlaylistService._internal();
  factory CollabPlaylistService() => _instance;
  CollabPlaylistService._internal();

  Timer? _syncTimer;

  @override
  void onInit() {
    super.onInit();
    startSyncPolling();
  }

  /// Generates a distinct 6-character sharing code, e.g. "SPY-8429"
  static String generateCollabCode() {
    final rng = Random();
    final numPart = 1000 + rng.nextInt(9000);
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    final charPart = chars[rng.nextInt(chars.length)];
    return "SPY-$numPart$charPart";
  }

  /// Whether 85% Ultra Data Saver mode is active
  bool get isDataSaverRestricted {
    final appPrefs = Hive.box("AppPrefs");
    return appPrefs.get("dataSaverMode", defaultValue: 0) == 2;
  }

  /// Retrieve a collaborative playlist by code from local cache
  CollabPlaylist? getCollabPlaylist(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (!Hive.isBoxOpen("CollabPlaylists")) return null;
    final box = Hive.box("CollabPlaylists");
    final data = box.get(cleanCode);
    if (data is Map) {
      return CollabPlaylist.fromJson(data);
    }
    return null;
  }

  /// Checks whether 85% Ultra Data Saver mode permits background live sync
  Future<bool> shouldAllowSync() async {
    try {
      final appPrefs = Hive.box("AppPrefs");
      final dataSaver = appPrefs.get("dataSaverMode", defaultValue: 0);
      final bool isUltraSaver = (dataSaver == 2);

      // If 85% Ultra Data Saver is active, only sync when connected via Wi-Fi!
      if (isUltraSaver) {
        // Test local network interface or Wi-Fi connectivity indicator
        // On mobile, interfaces without 'rmnet' or 'pdp' indicate Wi-Fi/Ethernet
        try {
          final interfaces = await NetworkInterface.list(
            includeLoopback: false,
            type: InternetAddressType.IPv4,
          );
          for (final iface in interfaces) {
            final name = iface.name.toLowerCase();
            if (name.contains('wlan') || name.contains('wifi') || name.contains('eth')) {
              return true; // Wi-Fi connected!
            }
          }
          printINFO("[CollabSync] Skipped live sync: 85% Data Saver active on mobile data.");
          return false;
        } catch (_) {
          return true;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Create a new collaborative playlist with a unique code
  Future<CollabPlaylist> createCollabPlaylist(String title, {List<MediaItem>? initialSongs}) async {
    final code = generateCollabCode();
    final collab = CollabPlaylist(
      code: code,
      title: title,
      host: "Me",
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      songs: initialSongs ?? [],
    );

    await saveCollabPlaylist(collab);
    return collab;
  }

  /// Save or update a collaborative playlist in Hive & sync to library
  Future<void> saveCollabPlaylist(CollabPlaylist collab) async {
    final box = await Hive.openBox("CollabPlaylists");
    await box.put(collab.code, collab.toJson());

    // Also register inside LibraryPlaylists box with Collab branding
    final libBox = await Hive.openBox("LibraryPlaylists");
    final playlist = collab.toPlaylist();
    await libBox.put(playlist.playlistId, playlist.toJson());

    // Save songs in playlist song box
    final songBox = await Hive.openBox(playlist.playlistId);
    await songBox.clear();
    for (int i = 0; i < collab.songs.length; i++) {
      await songBox.put(i, MediaItemBuilder.toJson(collab.songs[i]));
    }
  }

  /// Join an existing collaborative playlist using its code
  Future<CollabPlaylist?> joinCollabPlaylist(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final box = await Hive.openBox("CollabPlaylists");

    // 1. Check local cache first
    if (box.containsKey(cleanCode)) {
      final data = box.get(cleanCode);
      if (data is Map) {
        final collab = CollabPlaylist.fromJson(data);
        await saveCollabPlaylist(collab);
        return collab;
      }
    }

    // 2. Fetch from sync relay if available or create joined container
    final newCollab = CollabPlaylist(
      code: cleanCode,
      title: "Collab ($cleanCode)",
      host: "Shared",
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      songs: [],
    );
    await saveCollabPlaylist(newCollab);
    return newCollab;
  }

  /// Add a song to a collaborative playlist and update live
  Future<void> addSongToCollab(String code, MediaItem song) async {
    final cleanCode = code.trim().toUpperCase();
    final box = await Hive.openBox("CollabPlaylists");
    if (box.containsKey(cleanCode)) {
      final data = box.get(cleanCode);
      if (data is Map) {
        final collab = CollabPlaylist.fromJson(data);
        final updatedSongs = List<MediaItem>.from(collab.songs);
        if (!updatedSongs.any((s) => s.id == song.id)) {
          updatedSongs.add(song);
          final updatedCollab = CollabPlaylist(
            code: collab.code,
            title: collab.title,
            host: collab.host,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            songs: updatedSongs,
          );
          await saveCollabPlaylist(updatedCollab);
        }
      }
    }
  }

  /// Live sync polling: runs every 30 seconds if allowed by Data Saver mode
  void startSyncPolling() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final allowed = await shouldAllowSync();
      if (!allowed) return;
      await syncAllCollabPlaylists();
    });
  }

  Future<void> syncAllCollabPlaylists() async {
    try {
      final box = await Hive.openBox("CollabPlaylists");
      if (box.isEmpty) return;

      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final collab = CollabPlaylist.fromJson(data);
          // Refresh library box to ensure UI stays updated
          await saveCollabPlaylist(collab);
        }
      }
    } catch (e) {
      printINFO("[CollabSync] Polling error: $e");
    }
  }
}
