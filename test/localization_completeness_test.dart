import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/utils/get_localization.dart';
import 'package:spymusic/utils/lang_mapping.dart';

void main() {
  const expectedLangs = {'en', 'de', 'it', 'es', 'fr', 'nl'};

  group('Localization completeness', () {
    test('langMap and Languages expose strictly the 6 supported languages', () {
      expect(langMap.keys.toSet(), expectedLangs);
      expect(Languages().keys.keys.toSet(), expectedLangs);
    });

    test('all 6 languages have identical non-empty keys and matching placeholders', () {
      final translations = Languages().keys;
      final enMap = translations['en']!;
      final enKeys = enMap.keys.toSet();
      final placeholderRegex = RegExp(r'\{[a-zA-Z0-9_]+\}|%s');

      for (final lang in expectedLangs) {
        final langMapEntry = translations[lang]!;
        expect(
          langMapEntry.keys.toSet(),
          enKeys,
          reason: 'Key mismatch in language $lang',
        );

        for (final key in enKeys) {
          final value = langMapEntry[key] ?? '';
          expect(
            value.trim().isNotEmpty,
            isTrue,
            reason: 'Empty translation for $lang.$key',
          );

          final enPlaceholders = placeholderRegex
              .allMatches(enMap[key]!)
              .map((m) => m.group(0)!)
              .toList()
            ..sort();
          final langPlaceholders = placeholderRegex
              .allMatches(value)
              .map((m) => m.group(0)!)
              .toList()
            ..sort();
          expect(
            langPlaceholders,
            enPlaceholders,
            reason: 'Placeholder mismatch for $lang.$key',
          );
        }
      }
    });

    test('every static .tr key used in lib/ exists in all 6 languages', () {
      final translations = Languages().keys;
      final keyRegex = RegExp(r'''(["'])([A-Za-z0-9_]+)\1\s*\.tr''');
      final usedKeys = <String>{'supportViaPaypal', 'joinDiscord'};

      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('get_localization.dart')) continue;
        final content = entity.readAsStringSync();
        for (final match in keyRegex.allMatches(content)) {
          usedKeys.add(match.group(2)!);
        }
      }

      for (final lang in expectedLangs) {
        final map = translations[lang]!;
        final missing = usedKeys.where((k) => !map.containsKey(k)).toList();
        expect(
          missing,
          isEmpty,
          reason: 'Missing .tr keys in $lang: $missing',
        );
      }
    });

    test('normalizeSupportedLanguageCode maps unsupported codes safely to en', () {
      for (final lang in expectedLangs) {
        expect(normalizeSupportedLanguageCode(lang), lang);
      }
      expect(normalizeSupportedLanguageCode(null), 'en');
      expect(normalizeSupportedLanguageCode(''), 'en');
      expect(normalizeSupportedLanguageCode('ar'), 'en');
      expect(normalizeSupportedLanguageCode('ru'), 'en');
      expect(normalizeSupportedLanguageCode('ja'), 'en');
    });
  });
}

