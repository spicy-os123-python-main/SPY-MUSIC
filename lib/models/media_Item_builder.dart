// ignore_for_file: file_names

import 'package:audio_service/audio_service.dart';
import '../models/thumbnail.dart';

class MediaItemBuilder {
  static MediaItem fromJson(dynamic json, {String? url}) {
    String? artistName;
    if (json['artists'] != null) {
      artistName =
          json['artists']?.map((e) => e['name']).toList().join(', ').toString();
    }

    Map? album;
    if (json['album'] != null) {
      if (json['album']['id'] != null) {
        album = json['album'];
      }
    }

    return MediaItem(
        id: json["videoId"],
        title: json["title"],
        duration: json['duration'] != null
            ? Duration(seconds: json['duration'])
            : toDuration(json['length']),
        album: album != null ? album['name'] : null,
        artist: artistName,
        artUri: Uri.parse(Thumbnail(json["thumbnails"][0]['url']).high),
        extras: {
          'url': json['url'] ?? url,
          'length': json['length'],
          'album': album,
          'artists': json['artists'],
          'date': json['date'],
          'trackDetails': json['trackDetails'],
          'year': json['year']
        });
  }

  static Duration? toDuration(String? time) {
    if (time == null || time.isEmpty) {
      return null;
    }

    try {
      int sec = 0;
      final splitted = time.split(":");
      if (splitted.length == 3) {
        sec += (int.tryParse(splitted[0]) ?? 0) * 3600 +
            (int.tryParse(splitted[1]) ?? 0) * 60 +
            (int.tryParse(splitted[2]) ?? 0);
      } else if (splitted.length == 2) {
        sec += (int.tryParse(splitted[0]) ?? 0) * 60 +
            (int.tryParse(splitted[1]) ?? 0);
      } else if (splitted.length == 1) {
        sec += int.tryParse(splitted[0]) ?? 0;
      }
      return sec > 0 ? Duration(seconds: sec) : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> toJson(MediaItem mediaItem) => {
        "videoId": mediaItem.id,
        "title": mediaItem.title,
        'album': mediaItem.extras?['album'],
        'artists': mediaItem.extras?['artists'],
        'length': mediaItem.extras?['length'] ??
            (mediaItem.duration != null && mediaItem.duration!.inSeconds > 0
                ? "${mediaItem.duration!.inMinutes}:${(mediaItem.duration!.inSeconds % 60).toString().padLeft(2, '0')}"
                : null),
        'duration': mediaItem.duration?.inSeconds,
        'date': mediaItem.extras?['date'],
        'thumbnails': [
          {'url': mediaItem.artUri?.toString() ?? ''}
        ],
        'url': mediaItem.extras?['url'],
        'trackDetails': mediaItem.extras?['trackDetails'],
        'year': mediaItem.extras?['year']
      };
}
