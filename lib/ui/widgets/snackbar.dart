// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

enum SanckBarSize { BIG, MEDIUM, SMALL }

SnackBar snackbar(BuildContext context, String text,
    {SanckBarSize size = SanckBarSize.MEDIUM,
    Duration duration = const Duration(seconds: 1),
    bool top = false}) {
  final scrWidth = MediaQuery.of(context).size.width;
  final rawMargin = size == SanckBarSize.BIG
      ? (scrWidth - 300) / 2
      : size == SanckBarSize.MEDIUM
          ? (scrWidth - 200) / 2
          : (scrWidth - 100) / 2;
  final hrMargin = rawMargin < 16.0 ? 16.0 : rawMargin;
  final bg = Theme.of(context).colorScheme.secondary;
  final fg = bg.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  return SnackBar(
    backgroundColor: bg,
    content: Center(
      child: Text(
        text,
        style: TextStyle(color: fg),
      ),
    ),
    //width: width,

    margin: EdgeInsets.only(
        bottom: top ? MediaQuery.of(context).size.height * 0.8 : 100,
        left: hrMargin,
        right: hrMargin),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}
