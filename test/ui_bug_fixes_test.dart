import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:spymusic/ui/themes/app_themes.dart';
import 'package:spymusic/ui/widgets/cust_switch.dart';
import 'package:spymusic/ui/widgets/import_playlist_dialog.dart';
import 'package:spymusic/ui/widgets/snackbar.dart';
import 'package:spymusic/utils/get_localization.dart';

void main() {
  setUp(() {
    Get.addTranslations(Languages().keys);
    Get.locale = const Locale('de');
  });

  tearDown(Get.reset);

  group('UI contrast and layout regression checks', () {
    testWidgets(
        'CustSwitch adapts activeColor in light and Liquid Glass themes while preserving dark mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: CustSwitch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      final lightSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(lightSwitch.activeColor, isNot(Colors.white));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.liquidGlass.createThemeData(),
          home: Scaffold(
            body: CustSwitch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final glassSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(glassSwitch.activeColor, AppThemes.liquidGlass.accent);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: CustSwitch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final darkSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(darkSwitch.activeColor, Colors.white);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'snackbar clamps margins on narrow 260dp screen and preserves contrast on bright accents',
        (tester) async {
      tester.view.physicalSize = const Size(260, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late SnackBar builtBar;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.signal.createThemeData(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                builtBar =
                    snackbar(context, 'Test message', size: SanckBarSize.BIG);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final margin = builtBar.margin! as EdgeInsets;
      expect(margin.left, greaterThanOrEqualTo(16.0));
      expect(margin.right, greaterThanOrEqualTo(16.0));

      final centerWidget = builtBar.content as Center;
      final textWidget = centerWidget.child! as Text;
      // Signal accent (#B8FF3C) is bright, so text must be dark.
      expect(textWidget.style?.color, Colors.black87);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ImportPlaylistDialog renders in German on compact 300x360 viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(300, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          translations: Languages(),
          locale: const Locale('de'),
          home: const Scaffold(
            body: ImportPlaylistDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlist importieren'), findsOneWidget);
    });
  });
}

