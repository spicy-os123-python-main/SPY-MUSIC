import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/watchtime_service.dart';
import '../screens/Watchtime/watchtime_screen.dart';

class WatchtimeHomeWidget extends StatelessWidget {
  const WatchtimeHomeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WatchtimeService.watchtimeNotifier,
      builder: (context, _, __) {
        final todaySec = WatchtimeService.getDailyPlaytimeSec();
        final weeklySec = WatchtimeService.getWeeklyPlaytimeSec();

        return Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, top: 2, bottom: 8),
          child: GestureDetector(
            onTap: () => Get.to(() => const WatchtimeScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F1524), Color(0xFF161C2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00D2FF).withOpacity(0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2FF), Color(0xFFFF0055)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.timer_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Watchtime",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D2FF).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Heute: ${WatchtimeService.formatDuration(todaySec)}",
                                style: const TextStyle(
                                  color: Color(0xFF00D2FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Diese Woche: ${WatchtimeService.formatDuration(weeklySec)} • Alle Statistiken & Top-Künstler ansehen",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

