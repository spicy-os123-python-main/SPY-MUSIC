import 'package:flutter/material.dart';

class CustSwitch extends StatelessWidget {
  const CustSwitch({super.key, this.onChanged, required this.value});
  final void Function(bool)? onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;
    final Color? preferredAccent =
        theme.colorScheme.primary.computeLuminance() < 0.7
            ? theme.colorScheme.primary
            : (theme.primaryColor.computeLuminance() < 0.7
                ? theme.primaryColor
                : (theme.colorScheme.secondary.computeLuminance() < 0.7
                    ? theme.colorScheme.secondary
                    : null));
    final lightActiveThumb = preferredAccent ?? Colors.black87;
    return Switch(
        activeColor: isLightMode ? lightActiveThumb : Colors.white,
        activeTrackColor:
            isLightMode ? lightActiveThumb.withOpacity(0.4) : null,
        inactiveTrackColor: isLightMode ? Colors.grey[350] : null,
        inactiveThumbColor:
            isLightMode ? Colors.grey[600] : Colors.white.withOpacity(0.5),
        value: value,
        onChanged: onChanged);
  }
}
