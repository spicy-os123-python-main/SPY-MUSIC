import 'package:flutter/material.dart';

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
      return 'Standard / Sanft';
    case InteractionAnimationType.bookFlip:
      return 'Buchseiten 3D (Book Flip)';
    case InteractionAnimationType.cube3d:
      return '3D Würfel (Cube Rotation)';
    case InteractionAnimationType.cardStack:
      return 'Karten-Stapel & Tiefe (Card Depth)';
    case InteractionAnimationType.elasticBounce:
      return 'Elastischer Bounce (Spring Pop)';
    case InteractionAnimationType.jellySquish:
      return 'Gelee / Jelly Squish';
    case InteractionAnimationType.neonGlow:
      return 'Neon Glow & Cyber Pulse';
    case InteractionAnimationType.tilt3d:
      return '3D Neigung & Druck (Haptic Tilt)';
    case InteractionAnimationType.zoomPop:
      return 'Zoom & Dynamik (Scale Flow)';
    case InteractionAnimationType.smoothSlide:
      return 'Horizontales Gleiten (Smooth Slide)';
  }
}

String getInteractionAnimationDescription(InteractionAnimationType type) {
  switch (type) {
    case InteractionAnimationType.standard:
      return 'Klassische, minimalistische Übergänge und dezente Klick-Skalierung.';
    case InteractionAnimationType.bookFlip:
      return 'Seiten blättern sich mit 3D-Biegung und Schatten wie echte Buchseiten um; Buttons neigen sich am Buchrücken.';
    case InteractionAnimationType.cube3d:
      return 'Seiten rotieren wie ein echter 3D-Würfel im Raum; Buttons sinken mit räumlicher Tiefe ein.';
    case InteractionAnimationType.cardStack:
      return 'Seiten zoomen heraus und schieben sich wie ein Kartenstapel übereinander; Buttons drücken sich plastisch ein.';
    case InteractionAnimationType.elasticBounce:
      return 'Seiten und Buttons federn mit lebendigem, elastischem Schwung nach (Spring-Effekt).';
    case InteractionAnimationType.jellySquish:
      return 'Buttons und Seiten verformen sich saftig wie Gelee (horizontales und vertikales Stauchen).';
    case InteractionAnimationType.neonGlow:
      return 'Buttons pulsieren beim Berühren mit einer intensiven Neon-Lichtwelle und energiegeladenem Glühen.';
    case InteractionAnimationType.tilt3d:
      return 'Buttons neigen sich dynamisch in 3D zur Berührungsposition; Seiten kippen sanft in den Raum.';
    case InteractionAnimationType.zoomPop:
      return 'Dynamischer Zoom-Pop beim Öffnen von Seiten; blitzschnelles Einschnappen bei Buttons.';
    case InteractionAnimationType.smoothSlide:
      return 'Butterweiches, horizontales Gleiten mit eleganter kubischer Beschleunigungskurve.';
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

