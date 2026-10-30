import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../utils/theme_controller.dart';
import '../app_themes.dart';

const List<double> kSaturationMatrix1_8 = <double>[
  1.62992, -0.57216, -0.05776, 0.0, 0.0,
  -0.17008, 1.22784, -0.05776, 0.0, 0.0,
  -0.17008, -0.57216, 1.74224, 0.0, 0.0,
  0.0,      0.0,      0.0,      1.0, 0.0,
];

class GlassCard extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableBlur;
  final bool showLeftAccentBar;
  final Color? customFill;
  final BoxBorder? customBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.enableBlur = true,
    this.showLeftAccentBar = false,
    this.customFill,
    this.customBorder,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  Offset? _pointerPos;
  bool _isPressed = false;
  bool _isHovered = false;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (!GetPlatform.isDesktop) {
      _sweepController.repeat();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final settingsController = Get.find<SettingsScreenController>();

    return Obx(() {
      final config = themeController.activeCustomTheme.value;
      final reduceEffects = settingsController.reduceEffects.value;

      final radius = widget.borderRadius ??
          BorderRadius.circular(config != null ? config.radius : 14.0);

      if (config == null) {
        return _buildStandardCard(context, radius);
      }

      if (config.isGlass) {
        return _buildGlassCard(context, config, radius, reduceEffects);
      } else {
        return _buildThemedSolidCard(context, config, radius, reduceEffects);
      }
    });
  }

  Widget _buildStandardCard(BuildContext context, BorderRadius radius) {
    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.customFill ?? Theme.of(context).cardColor,
        borderRadius: radius,
        border: widget.customBorder,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: content,
      );
    }
    return content;
  }

  Widget _buildGlassCard(
    BuildContext context,
    SpyThemeConfig config,
    BorderRadius radius,
    bool reduceEffects,
  ) {
    final fillColor = widget.customFill ?? config.glassFill ?? const Color(0x1AFFFFFF);
    final borderColor = config.glassBorder ?? const Color(0x33FFFFFF);
    final highlightColor = config.glassHighlight ?? const Color(0x66FFFFFF);
    final shadeColor = config.glassInnerShade ?? Colors.transparent;
    final shadowColor = config.glassDropShadow ?? Colors.black26;

    Widget body = Stack(
      children: [
        // Base fill with inner shade gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: fillColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  fillColor,
                  fillColor,
                  shadeColor,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Specular highlight
        if (!reduceEffects)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sweepController,
              builder: (context, _) {
                Alignment centerAlign;
                if (GetPlatform.isDesktop && _pointerPos != null) {
                  final w = widget.width ?? 300.0;
                  final h = widget.height ?? 80.0;
                  centerAlign = Alignment(
                    ((_pointerPos!.dx / w) * 2.0 - 1.0).clamp(-1.0, 1.0),
                    ((_pointerPos!.dy / h) * 2.0 - 1.0).clamp(-1.0, 1.0),
                  );
                } else {
                  final progress = _sweepController.value;
                  centerAlign = Alignment(-1.6 + progress * 3.2, -0.4);
                }

                return ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: centerAlign,
                        radius: 0.85,
                        colors: [
                          Colors.white.withOpacity(config.isLight ? 0.35 : 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Thin top highlight line
        Positioned(
          top: 0,
          left: 10,
          right: 10,
          height: 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  highlightColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Child content
        Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ],
    );

    Widget cardWidget;
    if (reduceEffects || !widget.enableBlur) {
      cardWidget = Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: widget.customBorder ?? Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: body,
        ),
      );
    } else {
      cardWidget = Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: widget.customBorder ?? Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                inner: const ColorFilter.matrix(kSaturationMatrix1_8),
              ),
              child: body,
            ),
          ),
        ),
      );
    }

    return _wrapInteraction(cardWidget, radius);
  }

  Widget _buildThemedSolidCard(
    BuildContext context,
    SpyThemeConfig config,
    BorderRadius radius,
    bool reduceEffects,
  ) {
    final cardColor = widget.customFill ?? config.cardColor ?? config.bg;
    final lineColor = config.lineColor ?? config.accent.withOpacity(0.3);

    final showAccentGlow = (_isHovered || _isPressed) && !reduceEffects;
    final glowColor = config.accent.withOpacity(0.4);

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        border: widget.customBorder ??
            Border.all(
              color: showAccentGlow ? config.accent : lineColor,
              width: 1.0,
            ),
        boxShadow: showAccentGlow
            ? [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (widget.showLeftAccentBar && (config.isFlame || config.isWarp))
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: radius.topLeft,
                  bottomLeft: radius.bottomLeft,
                ),
                child: Container(color: config.accent),
              ),
            ),
          Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: widget.child,
          ),
        ],
      ),
    );

    if (config.isWarp && !reduceEffects && (_isPressed || _isHovered)) {
      final transform = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..translate(6.0, 0.0, 0.0)
        ..rotateY(-0.1);
      content = Transform(
        transform: transform,
        child: content,
      );
    }

    return _wrapInteraction(content, radius);
  }

  Widget _wrapInteraction(Widget child, BorderRadius radius) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _pointerPos = null;
      }),
      onHover: (event) => setState(() => _pointerPos = event.localPosition),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

