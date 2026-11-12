import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/app_secrets.dart';
import '../../../themes/app_themes.dart';
import '../../../themes/components/spy_button_animation.dart';
import '../../../utils/theme_controller.dart';
import '../../../widgets/snackbar.dart';
import '../settings_screen_controller.dart';

class _SupportAction {
  final Key buttonKey;
  final String label;
  final String tooltip;
  final IconData icon;
  final String url;

  const _SupportAction({
    required this.buttonKey,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.url,
  });
}

/// Compact top-right "Support me" pill housing separate PayPal and Discord
/// buttons styled dynamically after the active app theme.
class SupportLinksBar extends StatelessWidget {
  static String get paypalUrl => AppSecrets.supportPaypalUrl;
  static String get discordUrl => AppSecrets.supportDiscordUrl;

  static List<_SupportAction> get _actions => <_SupportAction>[
        _SupportAction(
          buttonKey: const ValueKey<String>('support_paypal_button'),
          label: 'PayPal',
          tooltip: 'supportViaPaypal',
          icon: Ionicons.logo_paypal,
          url: paypalUrl,
        ),
        _SupportAction(
          buttonKey: const ValueKey<String>('support_discord_button'),
          label: 'Discord',
          tooltip: 'joinDiscord',
          icon: Ionicons.logo_discord,
          url: discordUrl,
        ),
      ];

  final Future<void> Function(Uri uri)? onLaunchUri;
  final SpyThemeConfig? overrideConfig;

  const SupportLinksBar({
    super.key,
    this.onLaunchUri,
    this.overrideConfig,
  });

  @override
  Widget build(BuildContext context) {
    if (overrideConfig != null || !Get.isRegistered<ThemeController>()) {
      final reduceEffects = Get.isRegistered<SettingsScreenController>()
          ? Get.find<SettingsScreenController>().reduceEffects.value
          : false;
      return _buildShell(context, overrideConfig, reduceEffects);
    }

    final themeController = Get.find<ThemeController>();
    final settingsController = Get.isRegistered<SettingsScreenController>()
        ? Get.find<SettingsScreenController>()
        : null;

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController?.reduceEffects.value ?? false;
      return _buildShell(context, config, reduceEffects);
    });
  }

  Widget _buildShell(
    BuildContext context,
    SpyThemeConfig? config,
    bool reduceEffects,
  ) {
    final theme = Theme.of(context);
    final isSignal = config?.isSignal ?? false;
    final isGlass = config?.isGlass ?? false;
    final isLight = config?.isLight ?? (theme.brightness == Brightness.light);

    final fgColor = config?.fg ??
        theme.textTheme.titleMedium?.color ??
        theme.colorScheme.onSurface;
    final accentColor = _resolveAccentColor(theme, config, fgColor, isLight);

    final outerFill = _resolveOuterFill(theme, config, isGlass);
    final outerBorder = _resolveOuterBorder(theme, config, isGlass, accentColor);
    final buttonFill =
        accentColor.withOpacity(isLight ? 0.12 : (isGlass ? 0.22 : 0.14));
    final buttonBorder = accentColor.withOpacity(isGlass ? 0.48 : 0.34);
    final labelColor =
        Color.lerp(fgColor, accentColor, 0.25) ?? fgColor.withOpacity(0.88);

    final outerRadius = BorderRadius.circular(isSignal ? 14 : 26);
    final innerRadius = BorderRadius.circular(isSignal ? 10 : 20);

    final List<BoxShadow>? shadow = (config != null && !reduceEffects)
        ? [
            BoxShadow(
              color: isGlass
                  ? (config.glassDropShadow ?? Colors.black26)
                  : accentColor.withOpacity(0.14),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ]
        : null;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Semantics(
        container: true,
        label: 'supportMe'.tr,
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 6),
          decoration: BoxDecoration(
            color: outerFill,
            borderRadius: outerRadius,
            border: Border.all(color: outerBorder, width: 1.0),
            boxShadow: shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'supportMe'.tr,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    _buildActionButton(
                      context: context,
                      action: _actions[i],
                      radius: innerRadius,
                      fillColor: buttonFill,
                      borderColor: buttonBorder,
                      iconColor: accentColor,
                      textColor: fgColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _buildAboutLink(
                context: context,
                config: config,
                accentColor: accentColor,
                isLight: isLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutLink({
    required BuildContext context,
    required SpyThemeConfig? config,
    required Color accentColor,
    required bool isLight,
  }) {
    final linkBlue =
        isLight ? const Color(0xFF0A66C2) : const Color(0xFF58A6FF);

    return Semantics(
      link: true,
      label: 'About',
      child: GestureDetector(
        key: const ValueKey<String>('support_about_link'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showSupportAboutDialog(
          context,
          config: config,
          accentColor: accentColor,
          isLight: isLight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(
            'About',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: linkBlue,
              decoration: TextDecoration.underline,
              decorationColor: linkBlue,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showSupportAboutDialog(
    BuildContext context, {
    required SpyThemeConfig? config,
    required Color accentColor,
    required bool isLight,
  }) {
    final theme = Theme.of(context);
    final baseSurface = isLight ? Colors.white : const Color(0xFF141826);
    final rawCard = config?.cardColor ?? theme.dialogBackgroundColor;
    final dialogBg = Color.alphaBlend(rawCard, config?.bg ?? baseSurface);
    final titleColor = config?.fg ??
        theme.textTheme.titleMedium?.color ??
        (isLight ? Colors.black87 : Colors.white);
    final bodyColor = config?.muted ??
        theme.textTheme.bodyMedium?.color ??
        (isLight ? Colors.black54 : Colors.white70);
    final borderColor = accentColor.withOpacity(0.35);

    Future<void> openTarget(String rawUrl) async {
      final uri = Uri.parse(rawUrl);
      if (onLaunchUri != null) {
        await onLaunchUri!(uri);
        return;
      }
      await _launchExternalUri(context, uri);
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          key: const ValueKey<String>('support_about_dialog'),
          backgroundColor: dialogBg,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: 1.1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'supportAboutTitle'.tr,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: bodyColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SupportInfoCard(
                    icon: Ionicons.logo_paypal,
                    title: 'PayPal',
                    description: 'supportAboutPaypalDesc'.tr,
                    accentColor: accentColor,
                    titleColor: titleColor,
                    bodyColor: bodyColor,
                    isLight: isLight,
                    onTap: () => openTarget(paypalUrl),
                  ),
                  const SizedBox(height: 10),
                  _SupportInfoCard(
                    icon: Ionicons.logo_discord,
                    title: 'Discord',
                    description: 'supportAboutDiscordDesc'.tr,
                    accentColor: accentColor,
                    titleColor: titleColor,
                    bodyColor: bodyColor,
                    isLight: isLight,
                    onTap: () => openTarget(discordUrl),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'close'.tr,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required _SupportAction action,
    required BorderRadius radius,
    required Color fillColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
  }) {
    Future<void> handleTap() async {
      final uri = Uri.parse(action.url);
      if (onLaunchUri != null) {
        await onLaunchUri!(uri);
        return;
      }
      await _launchExternalUri(context, uri);
    }

    return Tooltip(
      message: action.tooltip.tr,
      child: Semantics(
        button: true,
        label: action.label,
        child: SpyButtonAnimation(
          key: action.buttonKey,
          borderRadius: radius,
          onTap: handleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: 0.9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  action.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _resolveAccentColor(
    ThemeData theme,
    SpyThemeConfig? config,
    Color fgColor,
    bool isLight,
  ) {
    if (config != null) {
      return config.accent;
    }
    final candidate = theme.colorScheme.secondary;
    final luminance = candidate.computeLuminance();
    if ((isLight && luminance > 0.55) || (!isLight && luminance < 0.12)) {
      return fgColor;
    }
    return candidate;
  }

  static Color _resolveOuterFill(
    ThemeData theme,
    SpyThemeConfig? config,
    bool isGlass,
  ) {
    if (config == null) {
      return theme.colorScheme.secondary.withAlpha(30);
    }
    if (isGlass) {
      return config.glassFill ?? const Color(0x26FFFFFF);
    }
    return config.cardColor ?? theme.cardColor;
  }

  static Color _resolveOuterBorder(
    ThemeData theme,
    SpyThemeConfig? config,
    bool isGlass,
    Color accentColor,
  ) {
    if (config == null) {
      return theme.colorScheme.secondary.withAlpha(80);
    }
    if (isGlass) {
      return config.glassBorder ?? accentColor.withOpacity(0.4);
    }
    return config.lineColor ?? accentColor.withOpacity(0.35);
  }

  static Future<void> _launchExternalUri(BuildContext context, Uri uri) async {
    try {
      var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            'couldNotOpenLink'.tr.replaceAll('{url}', uri.toString()),
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            'couldNotOpenLink'.tr.replaceAll('{url}', uri.toString()),
            size: SanckBarSize.MEDIUM,
          ),
        );
      }
    }
  }
}

class _SupportInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final Color titleColor;
  final Color bodyColor;
  final bool isLight;
  final VoidCallback onTap;

  const _SupportInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.titleColor,
    required this.bodyColor,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardFill = accentColor.withOpacity(isLight ? 0.08 : 0.12);
    final cardBorder = accentColor.withOpacity(0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder, width: 0.9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: accentColor.withOpacity(0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12.5,
                        height: 1.38,
                      ),
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
