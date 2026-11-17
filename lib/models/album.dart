import 'package:audio_service/audio_service.dart' show MediaItem;

import '../models/thumbnail.dart';

class AlbumContent {
  AlbumContent({required this.title, required this.albumList});
  final String title;
  final List<Album> albumList;

  factory AlbumContent.fromJson(Map<dynamic, dynamic> json) => AlbumContent(
      title: json['title'],
      albumList:
          (json['albumlist'] as List).map((e) => Album.fromJson(e)).toList());
  Map<String, dynamic> toJson() => {
        "type": "Album Content",
        "title": title,
        'albumlist': albumList.map((e) => e.toJson()).toList()
      };
}

class Album {
  Album(
      {required this.title,
      required this.browseId,
      required this.artists,
      this.year,
      this.description,
      this.audioPlaylistId,
      required this.thumbnailUrl});
  final String browseId;
  final String? audioPlaylistId;
  final String title;
  final String? description;
  final List<Map<dynamic, dynamic>>? artists;
  final String? year;
  final String thumbnailUrl;

  factory Album.fromJson(Map<dynamic, dynamic> json) {
    String thumb = "";
    if (json["thumbnails"] is List && (json["thumbnails"] as List).isNotEmpty) {
      final firstThumb = json["thumbnails"][0];
      if (firstThumb is Map && firstThumb["url"] != null) {
        thumb = Thumbnail(firstThumb["url"].toString()).medium;
      }
    }
    return Album(
        title: json["title"]?.toString() ?? "",
        browseId: json["browseId"]?.toString() ?? "",
        artists: json["artists"] != null && json["artists"] is List
            ? List<Map<dynamic, dynamic>>.from(json["artists"])
            : [
                {'name': ''}
              ],
        year: json['year']?.toString(),
        audioPlaylistId: json['audioPlaylistId']?.toString(),
        description: json['description']?.toString() ?? json["type"]?.toString() ?? "Album",
        thumbnailUrl: thumb);
  }

  Map<String, dynamic> toJson() => {
        "title": title,
        "browseId": browseId,
        'artists': artists,
        'year': year,
        'audioPlaylistId': audioPlaylistId,
        'description': description,
        'thumbnails': [
          {'url': thumbnailUrl}
        ]
      };

  // Converts this object to a MediaItem object.
  // This is used to display the playlist in Android auto.
  MediaItem toMediaItem() {
    return MediaItem(
        id: browseId,
        title: title,
        artUri: Uri.parse(thumbnailUrl),
        playable: false);
  }
}
