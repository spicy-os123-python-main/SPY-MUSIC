import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _SongRecognizerDialogState extends State<SongRecognizerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _queryController = TextEditingController();
  final SongRecognizerService _recognizer = SongRecognizerService();

  bool _isListening = false;
  bool _isSearching = false;
  bool _permissionDenied = false;
  String _statusText = "";
  RecognizedSong? _result;
  List<RecognizedSong> _candidates = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Start real acoustic recognition via microphone on open
    _startAcousticListening();
  }

  @override
  void dispose() {
    _recognizer.cancelRecording();
    _animController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  /// Real microphone acoustic recognition
  Future<void> _startAcousticListening() async {
    if (!mounted) return;

    setState(() {
      _isListening = true;
      _isSearching = false;
      _permissionDenied = false;
      _result = null;
      _candidates = [];
      _statusText = "recognizerListening".tr;
    });

    try {
      final match = await _recognizer.listenAndRecognize(
        listenDuration: const Duration(seconds: 6),
        onProgress: (stage) {
          if (!mounted) return;
          setState(() {
            if (stage == "listening") {
              _statusText = "recognizerListening".tr;
            } else if (stage == "analyzing") {
              _statusText = "recognizerAnalyzing".tr;
            } else if (stage == "resolving") {
              _statusText = "recognizerResolving".tr;
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _isListening = false;
        _result = match;
        _statusText =
            match != null ? "recognizerFound".tr : "recognizerNotFound".tr;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final isPerm = msg.contains("permission") || msg.contains("berechtigung");

      setState(() {
        _isListening = false;
        _permissionDenied = isPerm;
        _statusText = isPerm
            ? "recognizerMicPermissionNeeded".tr
            : "recognizerNotFound".tr;
      });
    }
  }

  /// Multi-source text / lyrics / humming search
  Future<void> _recognizeManualQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    // Cancel acoustic recording if user switches to typing
    _recognizer.cancelRecording();

    setState(() {
      _isListening = false;
      _isSearching = true;
      _statusText = "recognizerAnalyzing".tr;
      _result = null;
      _candidates = [];
    });

    try {
      final candidates = await _recognizer.searchCandidates(query);

      if (!mounted) return;

      RecognizedSong? top;
      if (candidates.isNotEmpty) {
        // Resolve top candidate so Play Now works seamlessly
        top = await _recognizer.identifyByQuery(query);
      }

      setState(() {
        _isSearching = false;
        _result = top;
        _candidates = candidates.length > 1 ? candidates.sublist(1) : [];
        _statusText =
            top != null ? "recognizerFound".tr : "recognizerNotFound".tr;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _statusText = "recognizerNotFound".tr;
      });
    }
  }

  void _playSong(RecognizedSong song) {
    Navigator.of(context).pop();
    final playerController = Get.find<PlayerController>();
    playerController.pushSongToQueue(song.toMediaItem());
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _isListening || _isSearching;

    return Dialog(
      backgroundColor: const Color(0xFF0D1220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: const Color(0xFF00D2FF).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
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
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF00D2FF),
                          size: 18,
                        ),
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
                    onPressed: () {
                      _recognizer.cancelRecording();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main Result Card
              if (_result != null) ...[
                _buildRecognizedCard(_result!),
                const SizedBox(height: 12),

                // Button: Listen Again
                TextButton.icon(
                  onPressed: _startAcousticListening,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF00D2FF), size: 18),
                  label: Text(
                    "recognizerListenAgain".tr,
                    style: const TextStyle(
                      color: Color(0xFF00D2FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Alternative candidates if user searched by lyrics / text
                if (_candidates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "recognizerAlternatives".tr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildCandidatesList(),
                ],
              ] else if (_permissionDenied) ...[
                // Microphone Permission Denied view
                _buildPermissionDeniedView(),
              ] else ...[
                // Radar / Listening animation or Not Found view
                _buildListeningOrNotFoundView(busy),
              ],

              const SizedBox(height: 16),

              // Manual Song / Lyric Search Input
              TextField(
                controller: _queryController,
                onSubmitted: (_) => _recognizeManualQuery(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "recognizerInputHint".tr,
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Colors.black38,
                  suffixIcon: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00D2FF),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF00D2FF),
                            size: 20,
                          ),
                          onPressed: _recognizeManualQuery,
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecognizedCard(RecognizedSong song) {
    return Container(
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
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.5),
          width: 1.5,
        ),
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
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: song.artworkUrl != null && song.artworkUrl!.isNotEmpty
                  ? Image.network(
                      song.artworkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ImageWidget(
                        song: song.toMediaItem(),
                        size: 104,
                      ),
                    )
                  : ImageWidget(
                      song: song.toMediaItem(),
                      size: 104,
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
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  "${(song.confidence * 100).toInt()}% Match • ${song.source ?? 'Acoustic Radar'}",
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
            song.title,
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
            song.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          if (song.album != null && song.album!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              song.album!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Play Now Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _playSong(song),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text("playNowBtn".tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _candidates.length.clamp(0, 3),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final c = _candidates[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: c.artworkUrl != null
                      ? Image.network(
                          c.artworkUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.music_note_rounded,
                          color: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      c.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Color(0xFF00D2FF), size: 28),
                onPressed: () => _playSong(c),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mic_off_rounded, color: Colors.amber, size: 38),
          const SizedBox(height: 8),
          Text(
            "recognizerMicPermissionNeeded".tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "recognizerMicPermissionHint".tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => openAppSettings(),
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: const Text("Open Settings"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningOrNotFoundView(bool busy) {
    return Column(
      children: [
        // Pulsing Listening Wave Animation
        Center(
          child: GestureDetector(
            onTap: busy ? null : _startAcousticListening,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening)
                      for (int i = 0; i < 3; i++)
                        Container(
                          width: 80.0 + (i * 28.0) * _animController.value,
                          height: 80.0 + (i * 28.0) * _animController.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00D2FF).withOpacity(
                                (1.0 - _animController.value).clamp(0.0, 1.0) *
                                    (0.35 - i * 0.1),
                              ),
                              width: 2.0,
                            ),
                          ),
                        ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: busy
                              ? const [
                                  Color(0xFF00D2FF),
                                  Color(0xFF0051FF),
                                ]
                              : const [
                                  Color(0xFF334155),
                                  Color(0xFF1E293B),
                                ],
                        ),
                        boxShadow: [
                          if (busy)
                            BoxShadow(
                              color: const Color(0xFF00D2FF).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: Icon(
                        busy ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
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
        if (!_isListening && !_isSearching) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _startAcousticListening,
            icon: const Icon(Icons.mic_rounded, size: 16),
            label: Text("recognizerListenAgain".tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
