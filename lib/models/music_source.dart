import 'package:flutter/material.dart';

enum MusicSource {
  all,
  youtube,
  spotify,
  soundcloud,
  amazon,
}

extension MusicSourceExt on MusicSource {
  String get displayName {
    switch (this) {
      case MusicSource.all:
        return '🔥 All-In-One';
      case MusicSource.youtube:
        return 'YouTube';
      case MusicSource.spotify:
        return 'Spotify';
      case MusicSource.soundcloud:
        return 'SoundCloud';
      case MusicSource.amazon:
        return 'Amazon Music';
    }
  }

  Color get brandColor {
    switch (this) {
      case MusicSource.all:
        return const Color(0xFFFF0055); // Crimson Fire
      case MusicSource.youtube:
        return const Color(0xFFFF0000); // YouTube Red
      case MusicSource.spotify:
        return const Color(0xFF1DB954); // Spotify Green
      case MusicSource.soundcloud:
        return const Color(0xFFFF5500); // SoundCloud Orange
      case MusicSource.amazon:
        return const Color(0xFF00A8E1); // Amazon Cyan
    }
  }

  IconData get icon {
    switch (this) {
      case MusicSource.all:
        return Icons.local_fire_department_rounded;
      case MusicSource.youtube:
        return Icons.play_circle_filled_rounded;
      case MusicSource.spotify:
        return Icons.graphic_eq_rounded;
      case MusicSource.soundcloud:
        return Icons.cloud_queue_rounded;
      case MusicSource.amazon:
        return Icons.music_note_rounded;
    }
  }
}

