import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/song_recognizer_service.dart';
import '../player/player_controller.dart';
import 'image_widget.dart';

class SongRecognizerDialog extends StatefulWidget {
  const SongRecognizerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => const SongRecognizerDialog(),
    );
  }

  @override
  State<SongRecognizerDialog> createState() => _SongRecognizerDialogState();
}

class _SongRecognizerDialogState extends State<SongRecognizerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _queryController = TextEditingController();
  bool _isListening = false;
  RecognizedSong? _result;
  String _statusText = "";

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _startSimulatedAcousticSearch();
  }

  @override
  void dispose() {
    _animController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _startSimulatedAcousticSearch() {
    setState(() {
      _isListening = true;
      _statusText = "recognizerListening".tr;
      _result = null;
    });
  }

  Future<void> _recognizeManualQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isListening = true;
      _statusText = "recognizerAnalyzing".tr;
      _result = null;
    });

    final service = SongRecognizerService();
    final match = await service.identifyByQuery(query);

    if (mounted) {
      setState(() {
        _isListening = false;
        _result = match;
        _statusText = match != null ? "recognizerFound".tr : "recognizerNotFound".tr;
      });
    }
  }

  void _playRecognizedSong() {
    if (_result?.mediaItem != null) {
      Navigator.of(context).pop();
      final playerController = Get.find<PlayerController>();
      playerController.pushSongToQueue(_result!.mediaItem!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: const Color(0xFF00D2FF).withOpacity(0.4), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF00D2FF), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "recognizerTitle".tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual Pulsing Shazam Radar or Result Display
              if (_result != null) ...[
                // Recognized Song Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Artwork
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ImageWidget(
                            song: _result!.toMediaItem(),
                            size: 100,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Match badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              "${(_result!.confidence * 100).toInt()}% Match",
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Title & Artist
                      Text(
                        _result!.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _result!.artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Play Now Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _playRecognizedSong,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text("playNowBtn".tr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Pulsing Listening Wave Animation
                Center(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (int i = 0; i < 3; i++)
                            Container(
                              width: 80.0 + (i * 28.0) * _animController.value,
                              height: 80.0 + (i * 28.0) * _animController.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00D2FF).withOpacity(
                                    (1.0 - _animController.value).clamp(0.0, 1.0) * (0.35 - i * 0.1),
                                  ),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFF00D2FF),
                                  Color(0xFF0051FF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D2FF).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _statusText.isNotEmpty ? _statusText : "recognizerListening".tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "recognizerHint".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),

                // Manual Song / Lyric Search Input
                TextField(
                  controller: _queryController,
                  onSubmitted: (_) => _recognizeManualQuery(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "recognizerInputHint".tr,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                    filled: true,
                    fillColor: Colors.black38,
                    suffixIcon: _isListening
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2FF)),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search_rounded, color: Color(0xFF00D2FF), size: 20),
                            onPressed: _recognizeManualQuery,
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
