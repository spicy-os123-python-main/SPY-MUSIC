import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/ui/player/player_controller.dart';

void main() {
  group('PlayerController.computeMiniPlayerMinHeight', () {
    test(
        'keeps compact 75dp height without extra bottom inset when bottom nav bar is enabled',
        () {
      expect(
        PlayerController.computeMiniPlayerMinHeight(
          screenWidth: 412,
          isBottomNavBarEnabled: true,
          bottomPadding: 48,
        ),
        75.0,
      );
      expect(
        PlayerController.computeMiniPlayerMinHeight(
          screenWidth: 900,
          isBottomNavBarEnabled: true,
          bottomPadding: 48,
        ),
        75.0,
      );
    });

    test(
        'includes bottom inset when bottom nav bar is disabled and panel touches screen edge',
        () {
      expect(
        PlayerController.computeMiniPlayerMinHeight(
          screenWidth: 412,
          isBottomNavBarEnabled: false,
          bottomPadding: 48,
        ),
        123.0,
      );
      expect(
        PlayerController.computeMiniPlayerMinHeight(
          screenWidth: 900,
          isBottomNavBarEnabled: false,
          bottomPadding: 24,
        ),
        129.0,
      );
    });

    test('clamps negative bottom padding to zero', () {
      expect(
        PlayerController.computeMiniPlayerMinHeight(
          screenWidth: 412,
          isBottomNavBarEnabled: false,
          bottomPadding: -12,
        ),
        75.0,
      );
    });
  });
}

