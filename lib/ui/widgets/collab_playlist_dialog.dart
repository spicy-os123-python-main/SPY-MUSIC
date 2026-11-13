import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/collab_playlist_service.dart';
import '../screens/Library/library_controller.dart';
import 'snackbar.dart';

class CollabPlaylistDialog extends StatefulWidget {
  const CollabPlaylistDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CollabPlaylistDialog(),
    );
  }

  @override
  State<CollabPlaylistDialog> createState() => _CollabPlaylistDialogState();
}

class _CollabPlaylistDialogState extends State<CollabPlaylistDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _createTitleController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createTitleController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final title = _createTitleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);
    final service = CollabPlaylistService();
    final collab = await service.createCollabPlaylist(title);
    setState(() {
      _isLoading = false;
      _generatedCode = collab.code;
    });

    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        Get.find<LibraryPlaylistsController>().refreshLib();
      }
    } catch (_) {}
  }

  Future<void> _handleJoin() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final service = CollabPlaylistService();
    final collab = await service.joinCollabPlaylist(code);
    setState(() => _isLoading = false);

    try {
      if (Get.isRegistered<LibraryPlaylistsController>()) {
        Get.find<LibraryPlaylistsController>().refreshLib();
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(
          context,
          collab != null
              ? "collabJoinedSuccess".tr.replaceAll("{code}", code)
              : "collabNotFound".tr,
          size: SanckBarSize.MEDIUM,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101524),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFF00D2FF).withOpacity(0.3), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2FF).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_rounded, color: Color(0xFF00D2FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "collabDialogTitle".tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "collabDialogSub".tr,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Bar (Create / Join)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF00D2FF).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.5)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  tabs: [
                    Tab(text: "collabTabCreate".tr),
                    Tab(text: "collabTabJoin".tr),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tab Views
              SizedBox(
                height: 190,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Create Collab
                    _generatedCode != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "collabCreatedSuccess".tr,
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00D2FF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _generatedCode!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF00D2FF), size: 18),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _generatedCode!));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          snackbar(context, "codeCopiedMsg".tr, size: SanckBarSize.SMALL),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "collabShareHint".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "collabPlaylistNameLabel".tr,
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _createTitleController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: "z.B. Roadtrip 2026, Gym Hits...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleCreate,
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text("collabCreateBtn".tr),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D2FF),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    // Tab 2: Join Collab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "collabEnterCodeLabel".tr,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _joinCodeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          decoration: InputDecoration(
                            hintText: "SPY-XXXX",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "collabDataSaverNotice".tr,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10.5, height: 1.3),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleJoin,
                            icon: const Icon(Icons.login_rounded),
                            label: Text("collabJoinBtn".tr),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
