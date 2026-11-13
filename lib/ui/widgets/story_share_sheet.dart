import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'image_widget.dart';
import 'snackbar.dart';

/// Modal sheet that renders an Instagram / WhatsApp Story-style share card
/// with high-resolution artwork, ambient glow, cyber soundwaves, and 1-tap share actions.
class StoryShareSheet extends StatelessWidget {
  final MediaItem song;

  const StoryShareSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, MediaItem song) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoryShareSheet(song: song),
    );
  }

  String get _shareUrl {
    final origUrl = song.extras?['url']?.toString();
    if (origUrl != null && origUrl.startsWith('http') && !origUrl.contains('googlevideo.com')) {
      return origUrl;
    }
    final cleanId = song.id.replaceAll('MPED', '').replaceAll('sp_', '').replaceAll('az_', '').replaceAll('sc_', '');
    return "https://youtube.com/watch?v=$cleanId";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = (size.width * 0.82).clamp(280.0, 360.0);
    final cardHeight = cardWidth * 1.52; // ~9:15 ratio for stories

    final title = song.title;
    final artist = song.artist ?? 'SPY MUSIC Artist';
    final album = song.album ?? 'SPY Track';

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.94),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFFF5722), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "storyCardTitle".tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // The Visual Story Card (9:16 Aspect Ratio)
              Container(
                width: cardWidth,
                height: cardHeight,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(-0.2, -0.4),
                    radius: 1.25,
                    colors: [
                      Color(0xFF201335),
                      Color(0xFF111425),
                      Color(0xFF070913),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFF5722).withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.25),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Badge at top
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF5722).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 14),
                              SizedBox(width: 4),
                              Text(
                                "SPY MUSIC",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: Color(0xFF00D2FF),
                            size: 16,
                          ),
                        ),
                      ],
                    ),

                    // Center: High-Res Glowing Album Artwork
                    Container(
                      width: cardWidth * 0.68,
                      height: cardWidth * 0.68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withOpacity(0.3),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                          const BoxShadow(
                            color: Colors.black87,
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ImageWidget(
                          song: song,
                          size: cardWidth * 0.68,
                        ),
                      ),
                    ),

                    // Song Title, Artist & Album
                    Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (album.isNotEmpty && album != title) ...[
                          const SizedBox(height: 3),
                          Text(
                            album,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Stylized Waveform Soundwaves
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(24, (i) {
                        final heights = [
                          8.0, 14.0, 22.0, 18.0, 28.0, 36.0, 24.0, 16.0,
                          32.0, 42.0, 26.0, 14.0, 20.0, 38.0, 44.0, 28.0,
                          18.0, 30.0, 22.0, 12.0, 24.0, 16.0, 10.0, 6.0,
                        ];
                        final h = heights[i % heights.length];
                        return Container(
                          width: 3.2,
                          height: h * 0.65,
                          margin: const EdgeInsets.symmetric(horizontal: 1.8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xFFFF5722),
                                Color(0xFF00D2FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),

                    // Bottom Tagline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note_rounded, size: 13, color: Color(0xFF00D2FF)),
                        const SizedBox(width: 5),
                        Text(
                          "storyCardNowPlaying".tr,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        final msg = "🎧 '${song.title}' von ${song.artist ?? ''} auf SPY MUSIC hören:\n$_shareUrl";
                        Share.share(msg, subject: "${song.title} - SPY MUSIC");
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text("storyShareBtn".tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        snackbar(context, "linkCopiedMsg".tr, size: SanckBarSize.SMALL),
                      );
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text("copyLinkBtn".tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
