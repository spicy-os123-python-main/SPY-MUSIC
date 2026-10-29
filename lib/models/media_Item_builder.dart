// ignore_for_file: file_names

import 'package:audio_service/audio_service.dart';
import '../models/thumbnail.dart';

class MediaItemBuilder {
  static bool _isValidString(dynamic val) {
    if (val == null) return false;
    final s = val.toString().trim();
    final lower = s.toLowerCase();
    return s.isNotEmpty &&
        lower != 'null' &&
        lower != 'na' &&
        lower != 'n/a' &&
        lower != 'undefined';
  }

  static MediaItem fromJson(dynamic json, {String? url}) {
    if (json == null) {
      return const MediaItem(id: '', title: '');
    }

    String? artistName;
    if (json['artists'] != null) {
      if (json['artists'] is List) {
        final list = (json['artists'] as List)
            .map((e) => e is Map ? (e['name'] ?? e.toString()) : e.toString())
            .where((s) => _isValidString(s))
            .map((s) => s.toString().trim())
            .toList();
        if (list.isNotEmpty) {
          artistName = list.join(', ');
        }
      } else if (_isValidString(json['artists'])) {
        artistName = json['artists'].toString().trim();
      }
    }

    if (!_isValidString(artistName)) {
      final a = json['artist']?.toString();
      if (_isValidString(a)) {
        artistName = a!.trim();
      }
    }

    if (!_isValidString(artistName)) {
      final a = json['extras']?['artist']?.toString();
      if (_isValidString(a)) {
        artistName = a!.trim();
      }
    }

    // Auto-recovery for previously saved tracks that had searchQuery: "$title $artist"
    if (!_isValidString(artistName)) {
      final sq = (json['extras']?['searchQuery'] ?? json['searchQuery'])?.toString();
      final title = json['title']?.toString() ?? '';
      if (_isValidString(sq) && title.isNotEmpty && sq!.toLowerCase().startsWith(title.toLowerCase())) {
        final rem = sq.substring(title.length).trim();
        if (_isValidString(rem)) artistName = rem;
      }
    }

    Map? album;
    if (json['album'] != null) {
      if (json['album'] is Map) {
        album = json['album'];
      } else if (json['album'] is String) {
        album = {'name': json['album']};
      }
    }

    String? thumbUrl;
    if (json['thumbnails'] != null &&
        json['thumbnails'] is List &&
        (json['thumbnails'] as List).isNotEmpty) {
      final t = (json['thumbnails'] as List)[0];
      if (t is Map) {
        thumbUrl = t['url']?.toString();
      } else if (t is String) {
        thumbUrl = t;
      }
    }
    if (thumbUrl == null || thumbUrl.isEmpty || thumbUrl == "null") {
      thumbUrl = json['artworkUrl']?.toString() ??
          json['coverArt']?.toString() ??
          json['thumbnailUrl']?.toString();
    }

    Uri? parsedArtUri;
    if (thumbUrl != null && thumbUrl.isNotEmpty && thumbUrl != "null") {
      try {
        if (thumbUrl.contains("googleusercontent.com") ||
            thumbUrl.contains("ggpht.com") ||
            thumbUrl.contains("i.ytimg.com")) {
          parsedArtUri = Uri.tryParse(Thumbnail(thumbUrl).high);
        } else {
          parsedArtUri = Uri.tryParse(thumbUrl);
        }
      } catch (_) {
        parsedArtUri = Uri.tryParse(thumbUrl);
      }
    }

    final extrasMap = json['extras'] is Map
        ? Map<String, dynamic>.from(json['extras'])
        : <String, dynamic>{};
    extrasMap['url'] = json['url'] ?? url ?? extrasMap['url'];
    extrasMap['length'] = json['length'] ?? extrasMap['length'];
    extrasMap['album'] = album ?? extrasMap['album'];
    extrasMap['artists'] = json['artists'] ?? extrasMap['artists'];
    extrasMap['date'] = json['date'] ?? extrasMap['date'];
    extrasMap['trackDetails'] = json['trackDetails'] ?? extrasMap['trackDetails'];
    extrasMap['year'] = json['year'] ?? extrasMap['year'];
    if (_isValidString(artistName)) {
      extrasMap['artist'] = artistName;
    }

    final trackId = (json["videoId"] ?? json["id"] ?? "").toString();
    String? platform = json['platform']?.toString() ?? extrasMap['platform']?.toString();
    if (platform == null || platform.isEmpty || platform == 'null') {
      if (trackId.startsWith('sp_') || extrasMap['isSpotify'] == true) {
        platform = 'Spotify';
      } else if (trackId.startsWith('sc_') || extrasMap['isSoundCloud'] == true) {
        platform = 'SoundCloud';
      } else if (trackId.startsWith('az_') || extrasMap['isAmazon'] == true) {
        platform = 'Amazon Music';
      } else {
        platform = 'YouTube';
      }
    }
    extrasMap['platform'] = platform;

    final albumName = album != null
        ? (album['name']?.toString())
        : (json['albumName']?.toString() ?? json['album']?.toString());

    return MediaItem(
      id: trackId,
      title: (json["title"] ?? "Unbekannt").toString(),
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'])
          : toDuration(json['length'] ?? extrasMap['length']),
      album: albumName,
      artist: _isValidString(artistName) ? artistName : null,
      artUri: parsedArtUri,
      extras: extrasMap,
    );
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

  static Map<String, dynamic> toJson(MediaItem mediaItem) {
    List<dynamic> artists = [];
    if (mediaItem.extras?['artists'] != null) {
      artists = mediaItem.extras?['artists'];
    } else if (mediaItem.artist != null &&
        mediaItem.artist!.isNotEmpty &&
        mediaItem.artist != 'null' &&
        mediaItem.artist != 'NA') {
      artists = [
        {'name': mediaItem.artist!, 'id': ''}
      ];
    }

    final thumbUrl = mediaItem.artUri?.toString() ?? '';

    final extrasMap = mediaItem.extras != null
        ? Map<String, dynamic>.from(mediaItem.extras!)
        : <String, dynamic>{};
    if (mediaItem.artist != null &&
        mediaItem.artist!.isNotEmpty &&
        mediaItem.artist != 'null' &&
        mediaItem.artist != 'NA') {
      extrasMap['artist'] = mediaItem.artist;
    }

    final platform = mediaItem.extras?['platform'] ??
        (mediaItem.id.startsWith('sp_')
            ? 'Spotify'
            : mediaItem.id.startsWith('sc_')
                ? 'SoundCloud'
                : mediaItem.id.startsWith('az_')
                    ? 'Amazon Music'
                    : 'YouTube');
    extrasMap['platform'] = platform;

    return {
      "videoId": mediaItem.id,
      "id": mediaItem.id,
      "title": mediaItem.title,
      "artist": mediaItem.artist,
      "platform": platform,
      'album': mediaItem.extras?['album'] ??
          (mediaItem.album != null ? {'name': mediaItem.album} : null),
      'albumName': mediaItem.album,
      'artists': artists,
      'length': mediaItem.extras?['length'] ??
          (mediaItem.duration != null && mediaItem.duration!.inSeconds > 0
              ? "${mediaItem.duration!.inMinutes}:${(mediaItem.duration!.inSeconds % 60).toString().padLeft(2, '0')}"
              : null),
      'duration': mediaItem.duration?.inSeconds,
      'date': mediaItem.extras?['date'],
      'thumbnails': [
        {'url': thumbUrl}
      ],
      'artworkUrl': thumbUrl,
      'url': mediaItem.extras?['url'],
      'trackDetails': mediaItem.extras?['trackDetails'],
      'year': mediaItem.extras?['year'],
      'extras': extrasMap,
    };
  }
}
