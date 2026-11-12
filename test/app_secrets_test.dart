import 'package:flutter_test/flutter_test.dart';
import 'package:spymusic/services/app_secrets.dart';
import 'package:spymusic/services/constant.dart';
import 'package:spymusic/services/love_mode_service.dart';

void main() {
  group('AppSecrets vault decryption', () {
    test('unseals Discord, webhook, YouTube, SoundCloud, and support entries cleanly',
        () {
      expect(
        AppSecrets.discordWebhookUrl,
        startsWith(AppSecrets.discordWebhookPrefix),
      );
      expect(AppSecrets.discordWebhookAvatarUrl, startsWith('https://'));
      expect(AppSecrets.discordApplicationId, matches(RegExp(r'^\d{17,20}$')));
      expect(AppSecrets.discordApiBaseUrl, startsWith('https://'));
      expect(AppSecrets.discordGatewayUrl, startsWith('wss://'));
      expect(AppSecrets.discordLogoUrl, startsWith('https://'));
      expect(AppSecrets.soundCloudDefaultClientId.length, greaterThanOrEqualTo(24));
      expect(AppSecrets.ytPublicKey, startsWith('AIza'));
      expect(AppSecrets.ytMusicDomain, startsWith('https://'));
      expect(baseUrl, contains(AppSecrets.ytMusicDomain));
      expect(fixedParms, contains(AppSecrets.ytPublicKey));
      expect(AppSecrets.liveConfigUrl, startsWith('https://'));
      expect(AppSecrets.supportPaypalUrl, startsWith('https://www.paypal.me/'));
      expect(AppSecrets.supportDiscordUrl, startsWith('https://discord.gg/'));
    });

    test('unseals Easter egg keywords and copy without plaintext fallbacks', () {
      expect(AppSecrets.loveSecretKeywords, isNotEmpty);
      expect(LoveModeService.isLoveCode('schatz'), isTrue);
      expect(LoveModeService.isLoveCode('love'), isTrue);
      expect(LoveModeService.isLoveCode('random song query'), isFalse);

      final copy = AppSecrets.loveCopy;
      expect(copy['bannerPrimary'], isNotEmpty);
      expect(copy['bannerSecondary'], isNotEmpty);
      expect(copy['titleOn'], isNotEmpty);
      expect(copy['titleOff'], isNotEmpty);
      expect(copy['bodyOn'], isNotEmpty);
      expect(copy['bodyOff'], isNotEmpty);
      expect(copy['btnOn'], isNotEmpty);
      expect(copy['sheetTitle'], isNotEmpty);
      expect(copy['sheetHintOn'], isNotEmpty);
      expect(copy['sheetHintOff'], isNotEmpty);
    });
  });
}
