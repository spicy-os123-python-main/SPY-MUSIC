import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const String paypalUrl = 'https://www.paypal.me/NuayaYauan';
  static const String discordUrl = 'https://discord.gg/3XczVdSHdG';

  static final List<_SupportAction> _actions = <_SupportAction>[
    const _SupportAction(
      buttonKey: ValueKey<String>('support_paypal_button'),
      label: 'PayPal',
      tooltip: 'Support via PayPal',
      icon: Ionicons.logo_paypal,
      url: paypalUrl,
    ),
    const _SupportAction(
      buttonKey: ValueKey<String>('support_discord_button'),
      label: 'Discord',
      tooltip: 'Join Discord',
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
        label: 'Support me',
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
                'Support me',
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
            ],
          ),
        ),
      ),
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
      message: action.tooltip,
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
          snackbar(context, 'Could not open link', size: SanckBarSize.MEDIUM),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(context, 'Could not open link', size: SanckBarSize.MEDIUM),
        );
      }
    }
  }
}
