import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/Home/home_screen_controller.dart';
import 'common_dialog_widget.dart';

class NewVersionDialog extends StatelessWidget {
  const NewVersionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: 32, bottom: 20, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "newVersionAvailable".tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SizedBox.square(
                  dimension: 100,
                  child: FittedBox(
                    child: FloatingActionButton(
                      onPressed: () async {
                        try {
                          final uri = Uri.parse(
                            'https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest/download/spymusic-arm64-v8a.apk',
                          );
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched) {
                            await launchUrl(uri,
                                mode: LaunchMode.platformDefault);
                          }
                        } catch (_) {}
                      },
                      child: const Icon(
                        Icons.download,
                        size: 30,
                      ),
                    ),
                  ),
                )),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GetX<HomeScreenController>(builder: (controller) {
                    return Checkbox(
                        value: controller.showVersionDialog.isFalse,
                        onChanged: (val) {
                          controller.onChangeVersionVisibility(val ?? false);
                        },
                        shape: const CircleBorder());
                  }),
                  Flexible(
                    child: Text("dontShowInfoAgain".tr),
                  )
                ],
              ),
            ),
            Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).textTheme.titleLarge!.color,
                    borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: Text("dismiss".tr,
                        style: TextStyle(color: Theme.of(context).canvasColor)),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ))
            ],
          ),
        ),
      ),
    );
  }
}
