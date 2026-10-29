import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../utils/helper.dart';

class PlaylistShareService {
  static final PlaylistShareService _instance =
      PlaylistShareService._internal();
  static PlaylistShareService get instance => _instance;
  factory PlaylistShareService() => _instance;
  PlaylistShareService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// Generates a short, shareable cloud link or falls back to a file.
  /// Works smoothly even for 700+ songs.
  Future<void> sharePlaylist(Playlist playlist, List<MediaItem> songs) async {
    if (songs.isEmpty) {
      final msg = 'emptyPlaylist'.tr;
      await Share.share(
          '🎵 SPY MUSIC ${"playlist".tr}: "${playlist.title}" ($msg)');
      return;
    }

    // 1. If playlist is a native YouTube playlist, share direct link
    if (playlist.isCloudPlaylist &&
        (playlist.playlistId.startsWith('PL') ||
            playlist.playlistId.startsWith('RD') ||
            playlist.playlistId.startsWith('UU'))) {
      final ytLink = 'https://youtube.com/playlist?list=${playlist.playlistId}';
      final shareText =
          '''🎵 SPY MUSIC ${"playlist".tr}: "${playlist.title}" (${songs.length} ${"songs".tr})
$ytLink

💡 ${"importShareHint".tr}''';
      await Share.share(shareText);
      return;
    }

    // 2. Build full SPY MUSIC playlist JSON payload
    final playlistData = {
      'type': 'spymusic_playlist',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'playlistInfo': {
        'title': playlist.title,
        'description': playlist.description ?? 'SPY MUSIC Playlist',
        'thumbnailUrl': playlist.thumbnailUrl,
        'songCount': songs.length,
        'sourceId': playlist.playlistId,
      },
      'songs': songs.map((s) => MediaItemBuilder.toJson(s)).toList(),
    };

    final jsonContent = jsonEncode(playlistData);

    // 3. Upload to dpaste.org to get a super short link (e.g. https://dpaste.org/xyz12)
    String? shortUrl;
    try {
      final formData = FormData.fromMap({
        'content': jsonContent,
        'format': 'url',
        'expiry_days': 365,
        'title': 'SPY MUSIC - ${playlist.title}',
      });

      final response = await _dio.post(
        'https://dpaste.org/api/',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final urlStr = response.data.toString().trim();
        if (urlStr.startsWith('http')) {
          shortUrl = urlStr;
        }
      }
    } catch (e) {
      printERROR("PlaylistShareService dpaste upload error: $e");
    }

    // 4. If short cloud link was generated successfully
    if (shortUrl != null && shortUrl.isNotEmpty) {
      final shareText =
          '''🎵 SPY MUSIC ${"playlist".tr}: "${playlist.title}" (${songs.length} ${"songs".tr})
$shortUrl

💡 ${"importShareHint".tr}''';
      await Share.share(shareText);
      return;
    }

    // 5. Fallback if offline or upload service failed: share as a compact file
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName =
          playlist.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/$sanitizedName.spymusic');
      await file.writeAsString(jsonContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '🎵 SPY MUSIC ${"playlist".tr}: "${playlist.title}" (${songs.length} ${"songs".tr})',
      );
    } catch (e) {
      printERROR("PlaylistShareService file fallback error: $e");
      // Ultimate fallback: text summary
      final fallbackText =
          '🎵 SPY MUSIC ${"playlist".tr}: "${playlist.title}" (${songs.length} ${"songs".tr})';
      await Share.share(fallbackText);
    }
  }
}
