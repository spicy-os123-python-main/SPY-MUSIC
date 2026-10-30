import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';

class ThemedHeading extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double fontSize;

  const ThemedHeading(
    this.text, {
    super.key,
    this.style,
    this.fontSize = 28.0,
  });

  @override
  State<ThemedHeading> createState() => _ThemedHeadingState();
}

class _ThemedHeadingState extends State<ThemedHeading>
    with TickerProviderStateMixin {
  late AnimationController _glitchController;
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      final textTheme = Theme.of(context).textTheme;
      final baseStyle = (widget.style ?? textTheme.titleLarge)!.copyWith(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w800,
      );

      if (config == null || reduceEffects) {
        return Text(widget.text, style: baseStyle);
      }

      if (config.isSignal) {
        return _buildSignalHeading(config, baseStyle);
      } else if (config.isWarp) {
        return _buildWarpHeading(config, baseStyle);
      } else if (config.isFlame) {
        return _buildFlameHeading(config, baseStyle);
      }

      return Text(
        widget.text,
        style: baseStyle.copyWith(color: config.fg),
      );
    });
  }

  Widget _buildFlameHeading(SpyThemeConfig config, TextStyle baseStyle) {
    final f1 = config.flameOuter ?? config.accent;
    final f3 = config.flameCore ?? config.accent;
    final f4 = config.flameHot ?? Colors.white;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [f4, f3, f1],
          stops: const [0.0, 0.45, 0.9],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        config.type == ThemeType.emberGlass ? widget.text : widget.text.toUpperCase(),
        style: baseStyle.copyWith(
          color: Colors.white,
          shadows: [
            Shadow(
              color: (config.flameMid ?? config.accent).withOpacity(0.7),
              blurRadius: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarpHeading(SpyThemeConfig config, TextStyle baseStyle) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, _) {
        final val = _glitchController.value;
        double offsetX = 0.0;
        if (val > 0.92 && val < 0.96) {
          offsetX = (math.sin(val * 100) * 3.0);
        }

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Text(
            widget.text.toUpperCase(),
            style: baseStyle.copyWith(
              color: config.fg,
              letterSpacing: 1.5,
              shadows: const [
                Shadow(color: Color(0xFFFF2E93), offset: Offset(-2, 0)),
                Shadow(color: Color(0xFF00F0FF), offset: Offset(2, 0)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignalHeading(SpyThemeConfig config, TextStyle baseStyle) {
    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, _) {
        final showCursor = _cursorController.value > 0.5;
        return Text(
          "${widget.text.toUpperCase()}${showCursor ? '_' : ' '}",
          style: baseStyle.copyWith(
            color: config.accent,
            letterSpacing: 1.0,
          ),
        );
      },
    );
  }
}

