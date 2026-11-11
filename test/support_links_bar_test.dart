import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:spymusic/ui/screens/Settings/components/support_links_bar.dart';
import 'package:spymusic/ui/themes/app_themes.dart';

void main() {
  group('SupportLinksBar', () {
    testWidgets('renders Support me label and separate PayPal & Discord buttons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.warp.createThemeData(),
          home: Scaffold(
            body: Center(
              child: SupportLinksBar(
                overrideConfig: AppThemes.warp,
                onLaunchUri: (_) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Support me'), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      expect(find.text('Discord'), findsOneWidget);
      expect(find.byIcon(Ionicons.logo_paypal), findsOneWidget);
      expect(find.byIcon(Ionicons.logo_discord), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('support_paypal_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support_discord_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens distinct PayPal and Discord URLs when tapped',
        (tester) async {
      final launched = <Uri>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.warp.createThemeData(),
          home: Scaffold(
            body: Center(
              child: SupportLinksBar(
                overrideConfig: AppThemes.warp,
                onLaunchUri: (uri) async => launched.add(uri),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('support_paypal_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('support_discord_button')),
      );
      await tester.pumpAndSettle();

      expect(launched, [
        Uri.parse('https://www.paypal.me/NuayaYauan'),
        Uri.parse('https://discord.gg/3XczVdSHdG'),
      ]);
    });

    testWidgets('adapts styling cleanly across custom and standard themes',
        (tester) async {
      for (final config in <SpyThemeConfig?>[
        AppThemes.warp,
        AppThemes.inferno,
        AppThemes.liquidGlass,
        AppThemes.signal,
        null,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: config?.createThemeData() ?? ThemeData.dark(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 20, right: 15, top: 66),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Einstellungen',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SupportLinksBar(
                      overrideConfig: config,
                      onLaunchUri: (_) async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final iconWidget = tester.widget<Icon>(
          find.byIcon(Ionicons.logo_paypal),
        );
        if (config != null) {
          expect(iconWidget.color, config.accent);
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('does not overflow on narrow 320dp viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.warp.createThemeData(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 20, right: 15, top: 66),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Einstellungen',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SupportLinksBar(
                    overrideConfig: AppThemes.warp,
                    onLaunchUri: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

