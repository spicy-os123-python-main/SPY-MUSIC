import '../models/thumbnail.dart';

class Artist {
  Artist({
    required this.name,
    required this.browseId,
    this.radioId,
    required this.thumbnailUrl,
    this.subscribers,
  });
  final String name;
  final String browseId;
  final String? radioId;
  final String? subscribers;
  final String thumbnailUrl;
  factory Artist.fromJson(dynamic json) {
    if (json is! Map) {
      return Artist(
        name: "",
        browseId: "",
        thumbnailUrl: "",
      );
    }
    String thumb = "";
    if (json["thumbnails"] is List && (json["thumbnails"] as List).isNotEmpty) {
      final firstThumb = json["thumbnails"][0];
      if (firstThumb is Map && firstThumb["url"] != null) {
        thumb = Thumbnail(firstThumb["url"].toString()).high;
      }
    }
    return Artist(
        name: json['artist']?.toString() ?? json['name']?.toString() ?? "",
        browseId: json['browseId']?.toString() ?? "",
        radioId: json['radioId']?.toString(),
        subscribers: (json['subscribers']) == null
            ? ""
            : json['subscribers'] is String
                ? json['subscribers']
                : (json['subscribers'] is Map
                    ? (json['subscribers']['text']?.toString() ?? "")
                    : json['subscribers'].toString()),
        thumbnailUrl: thumb);
  }

  Map<String, dynamic> toJson() => {
        'artist': name,
        'browseId': browseId,
        'radioId': radioId,
        'subscribers': subscribers,
        'thumbnails': [
          {'url': thumbnailUrl}
        ]
      };
}

class ArtistContent {
  ArtistContent(this.content, {this.title = "Artists"});
  final List<Artist> content;
  final String title;
}
