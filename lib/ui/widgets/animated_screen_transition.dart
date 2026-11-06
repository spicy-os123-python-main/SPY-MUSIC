import 'dart:math' as math;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/Settings/settings_screen_controller.dart';
import '../themes/interaction_animations/interaction_animation_types.dart';

class AnimatedScreenTransition extends StatelessWidget {
  const AnimatedScreenTransition({
    super.key,
    this.enabled = true,
    this.resverse = false,
    this.horizontalTransition = false,
    required this.child,
  });

  final bool enabled;
  final bool resverse;
  final Widget child;
  final bool horizontalTransition;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final settings = Get.isRegistered<SettingsScreenController>()
        ? Get.find<SettingsScreenController>()
        : null;

    final type = settings?.interactionAnimationType.value ??
        InteractionAnimationType.standard;

    Duration duration;
    switch (type) {
      case InteractionAnimationType.bookFlip:
        duration = const Duration(milliseconds: 720);
        break;
      case InteractionAnimationType.cube3d:
        duration = const Duration(milliseconds: 620);
        break;
      case InteractionAnimationType.elasticBounce:
        duration = const Duration(milliseconds: 580);
        break;
      case InteractionAnimationType.jellySquish:
        duration = const Duration(milliseconds: 540);
        break;
      case InteractionAnimationType.cardStack:
        duration = const Duration(milliseconds: 540);
        break;
      case InteractionAnimationType.tilt3d:
        duration = const Duration(milliseconds: 520);
        break;
      case InteractionAnimationType.zoomPop:
      case InteractionAnimationType.neonGlow:
      case InteractionAnimationType.smoothSlide:
      case InteractionAnimationType.standard:
        duration = const Duration(milliseconds: 500);
        break;
    }

    return PageTransitionSwitcher(
      duration: duration,
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        switch (type) {
          case InteractionAnimationType.bookFlip:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                // Entering page turns gracefully from soft angle to 0
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeInOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final angle = (1.0 - curved.value) * (math.pi / 4.5);
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0008)
                        ..rotateY(resverse ? -angle : angle),
                      alignment: resverse
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                            parent: animation, curve: Curves.easeOut),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              reverseBuilder: (context, animation, child) {
                // Exiting page turns away gracefully with subtle fade
                final curved = CurvedAnimation(
                    parent: secondaryAnimation, curve: Curves.easeInOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final angle = curved.value * (math.pi / 4.5);
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0008)
                        ..rotateY(resverse ? angle : -angle),
                      alignment: resverse
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0)
                            .animate(CurvedAnimation(
                                parent: secondaryAnimation, curve: Curves.easeIn)),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              child: child,
            );

          case InteractionAnimationType.cube3d:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final angle = (1.0 - curved.value) * (math.pi / 4.0);
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0010)
                        ..rotateY(resverse ? -angle : angle),
                      alignment: resverse
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                            parent: animation, curve: Curves.easeOut),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              reverseBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: secondaryAnimation, curve: Curves.easeOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final angle = curved.value * (math.pi / 4.0);
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0010)
                        ..rotateY(resverse ? angle : -angle),
                      alignment: resverse
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0)
                            .animate(CurvedAnimation(
                                parent: secondaryAnimation, curve: Curves.easeIn)),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              child: child,
            );

          case InteractionAnimationType.cardStack:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                final offsetTween = resverse
                    ? Tween<Offset>(
                        begin: const Offset(-0.35, 0), end: Offset.zero)
                    : Tween<Offset>(
                        begin: const Offset(0.35, 0), end: Offset.zero);
                return SlideTransition(
                  position: offsetTween.animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
                    child: FadeTransition(
                      opacity: curved,
                      child: child,
                    ),
                  ),
                );
              },
              reverseBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: secondaryAnimation, curve: Curves.easeInCubic);
                return ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 0.85).animate(curved),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.3).animate(curved),
                    child: child,
                  ),
                );
              },
              child: child,
            );

          case InteractionAnimationType.elasticBounce:
            final forwardTween = resverse
                ? Tween<Offset>(begin: const Offset(-1.0, 0), end: Offset.zero)
                : Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero);
            final reverseTween = resverse
                ? Tween<Offset>(begin: Offset.zero, end: const Offset(1.0, 0))
                : Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0));
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) => SlideTransition(
                position: forwardTween.animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutBack)),
                child: child,
              ),
              reverseBuilder: (context, animation, child) => SlideTransition(
                position: reverseTween.animate(CurvedAnimation(
                    parent: secondaryAnimation, curve: Curves.easeInBack)),
                child: child,
              ),
              child: child,
            );

          case InteractionAnimationType.jellySquish:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final progress = curved.value;
                    // Squash and stretch oscillation
                    final scaleX = 1.0 + math.sin(progress * math.pi) * 0.08;
                    final scaleY = 1.0 - math.sin(progress * math.pi) * 0.06;
                    return Transform(
                      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                      alignment: Alignment.center,
                      child: FadeTransition(
                        opacity: curved,
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              reverseBuilder: (context, animation, child) {
                return FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0)
                      .animate(secondaryAnimation),
                  child: child,
                );
              },
              child: child,
            );

          case InteractionAnimationType.neonGlow:
          case InteractionAnimationType.zoomPop:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) => ScaleTransition(
                scale: Tween<double>(begin: 0.84, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: Curves.easeOut),
                  child: child,
                ),
              ),
              reverseBuilder: (context, animation, child) => ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 0.88).animate(
                    CurvedAnimation(
                        parent: secondaryAnimation, curve: Curves.easeInCubic)),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0)
                      .animate(secondaryAnimation),
                  child: child,
                ),
              ),
              child: child,
            );

          case InteractionAnimationType.tilt3d:
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, child) {
                    final tilt = (1.0 - curved.value) * 0.16;
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(tilt)
                        ..scale(0.92 + (0.08 * curved.value)),
                      alignment: Alignment.center,
                      child: FadeTransition(
                        opacity: curved,
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              reverseBuilder: (context, animation, child) => FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0)
                    .animate(secondaryAnimation),
                child: child,
              ),
              child: child,
            );

          case InteractionAnimationType.smoothSlide:
          case InteractionAnimationType.standard:
            final offsetEnter = resverse
                ? Tween<Offset>(begin: const Offset(-0.14, 0), end: Offset.zero)
                : Tween<Offset>(begin: const Offset(0.14, 0), end: Offset.zero);
            final offsetExit = resverse
                ? Tween<Offset>(begin: Offset.zero, end: const Offset(0.10, 0))
                : Tween<Offset>(begin: Offset.zero, end: const Offset(-0.10, 0));
            return DualTransitionBuilder(
              animation: primaryAnimation,
              forwardBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                return SlideTransition(
                  position: offsetEnter.animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: animation, curve: Curves.easeOut),
                      child: child,
                    ),
                  ),
                );
              },
              reverseBuilder: (context, animation, child) {
                final curved = CurvedAnimation(
                    parent: secondaryAnimation, curve: Curves.easeOutCubic);
                return SlideTransition(
                  position: offsetExit.animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 0.97).animate(curved),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                          CurvedAnimation(
                              parent: secondaryAnimation, curve: Curves.easeIn)),
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            );
        }
      },
      child: child,
    );
  }
}
