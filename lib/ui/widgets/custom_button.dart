import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/components/spy_button_animation.dart';

class ProceedButton extends StatelessWidget {
  const ProceedButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
  });
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SpyButtonAnimation(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).textTheme.titleLarge!.color,
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
          child: Text(
            buttonText,
            style: TextStyle(color: Theme.of(context).canvasColor),
          ),
        ),
      ),
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SpyButtonAnimation(
      onTap: () {
        Navigator.of(context).pop();
        if (onPressed != null) {
          onPressed!();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Text("cancel".tr),
      ),
    );
  }
}
