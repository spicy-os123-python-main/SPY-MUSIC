import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum InteractionAnimationType {
  standard,
  bookFlip,
  cube3d,
  cardStack,
  elasticBounce,
  jellySquish,
  neonGlow,
  tilt3d,
  zoomPop,
  smoothSlide,
}

String getInteractionAnimationName(InteractionAnimationType type) {
  switch (type) {
    case InteractionAnimationType.standard:
      return 'interAnimStandard'.tr;
    case InteractionAnimationType.bookFlip:
      return 'interAnimBookFlip'.tr;
    case InteractionAnimationType.cube3d:
      return 'interAnimCube3d'.tr;
    case InteractionAnimationType.cardStack:
      return 'interAnimCardStack'.tr;
    case InteractionAnimationType.elasticBounce:
      return 'interAnimElastic'.tr;
    case InteractionAnimationType.jellySquish:
      return 'interAnimJelly'.tr;
    case InteractionAnimationType.neonGlow:
      return 'interAnimNeonGlow'.tr;
    case InteractionAnimationType.tilt3d:
      return 'interAnimTilt3d'.tr;
    case InteractionAnimationType.zoomPop:
      return 'interAnimZoomPop'.tr;
    case InteractionAnimationType.smoothSlide:
      return 'interAnimSmoothSlide'.tr;
  }
}

String getInteractionAnimationDescription(InteractionAnimationType type) {
  switch (type) {
    case InteractionAnimationType.standard:
      return 'interAnimStandardDesc'.tr;
    case InteractionAnimationType.bookFlip:
      return 'interAnimBookFlipDesc'.tr;
    case InteractionAnimationType.cube3d:
      return 'interAnimCube3dDesc'.tr;
    case InteractionAnimationType.cardStack:
      return 'interAnimCardStackDesc'.tr;
    case InteractionAnimationType.elasticBounce:
      return 'interAnimElasticDesc'.tr;
    case InteractionAnimationType.jellySquish:
      return 'interAnimJellyDesc'.tr;
    case InteractionAnimationType.neonGlow:
      return 'interAnimNeonGlowDesc'.tr;
    case InteractionAnimationType.tilt3d:
      return 'interAnimTilt3dDesc'.tr;
    case InteractionAnimationType.zoomPop:
      return 'interAnimZoomPopDesc'.tr;
    case InteractionAnimationType.smoothSlide:
      return 'interAnimSmoothSlideDesc'.tr;
  }
}

IconData getInteractionAnimationIcon(InteractionAnimationType type) {
  switch (type) {
    case InteractionAnimationType.standard:
      return Icons.touch_app_rounded;
    case InteractionAnimationType.bookFlip:
      return Icons.menu_book_rounded;
    case InteractionAnimationType.cube3d:
      return Icons.view_in_ar_rounded;
    case InteractionAnimationType.cardStack:
      return Icons.layers_rounded;
    case InteractionAnimationType.elasticBounce:
      return Icons.sports_volleyball_rounded;
    case InteractionAnimationType.jellySquish:
      return Icons.bubble_chart_rounded;
    case InteractionAnimationType.neonGlow:
      return Icons.bolt_rounded;
    case InteractionAnimationType.tilt3d:
      return Icons.rotate_90_degrees_cw_rounded;
    case InteractionAnimationType.zoomPop:
      return Icons.zoom_out_map_rounded;
    case InteractionAnimationType.smoothSlide:
      return Icons.swipe_rounded;
  }
}

