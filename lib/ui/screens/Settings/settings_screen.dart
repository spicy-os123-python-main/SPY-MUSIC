import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spymusic/utils/lang_mapping.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/common_dialog_widget.dart';
import '../../widgets/cust_switch.dart';
import '../../widgets/export_file_dialog.dart';
import '../../widgets/snackbar.dart';
import '/ui/widgets/inapp_equalizer_sheet.dart';
import '/services/music_service.dart';
import '/services/discord_service.dart';
import '../../widgets/discord_login_dialog.dart';
import '/ui/utils/theme_controller.dart';
import 'components/custom_expansion_tile.dart';
import 'components/auto_backup_settings_widget.dart';
import 'settings_screen_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    final topPadding = context.isLandscape ? 50.0 : 90.0;
    final isDesktop = GetPlatform.isDesktop;
    return Padding(
      padding: isBottomNavActive
          ? EdgeInsets.only(left: 20, top: topPadding, right: 15)
          : EdgeInsets.only(top: topPadding, left: 5, right: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "settings".tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
              child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 200, top: 20),
            children: [
              Obx(
                () => settingsController.isNewVersionAvailable.value
                    ? Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, right: 10, bottom: 8.0),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            onTap: () {
                              launchUrl(
                                Uri.parse(
                                  'https://github.com/spicy-os123-python-main/SPY-MUSIC/releases/latest',
                                ),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            tileColor: Theme.of(context).colorScheme.secondary,
                            contentPadding:
                                const EdgeInsets.only(left: 8, right: 10),
                            leading:
                                const CircleAvatar(child: Icon(Icons.download)),
                            title: Text("newVersionAvailable".tr),
                            visualDensity: const VisualDensity(horizontal: -2),
                            subtitle: Text(
                              "goToDownloadPage".tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                      color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              CustomExpansionTile(
                title: "personalisation".tr,
                icon: Icons.palette,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("themeMode".tr),
                    subtitle: Obx(
                      () => Text(
                          settingsController.themeModetype.value ==
                                  ThemeType.dynamic
                              ? "dynamic".tr
                              : settingsController.themeModetype.value ==
                                      ThemeType.system
                                  ? "systemDefault".tr
                                  : settingsController.themeModetype.value ==
                                          ThemeType.dark
                                      ? "dark".tr
                                      : "light".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => const ThemeSelectorDialog(),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("language".tr),
                    subtitle: Text("languageDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Obx(
                      () => DropdownButton(
                        menuMaxHeight: Get.height - 250,
                        dropdownColor: Theme.of(context).cardColor,
                        underline: const SizedBox.shrink(),
                        style: Theme.of(context).textTheme.titleSmall,
                        value: settingsController.currentAppLanguageCode.value,
                        items: langMap.entries
                            .map((lang) => DropdownMenuItem(
                                  value: lang.key,
                                  child: Text(lang.value),
                                ))
                            .whereType<DropdownMenuItem<String>>()
                            .toList(),
                        selectedItemBuilder: (context) =>
                            langMap.entries.map<Widget>((item) {
                          return Container(
                            alignment: Alignment.centerRight,
                            constraints: const BoxConstraints(minWidth: 50),
                            child: Text(
                              item.value,
                            ),
                          );
                        }).toList(),
                        onChanged: settingsController.setAppLanguage,
                      ),
                    ),
                  ),

                  if (!isDesktop)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("playerUi".tr),
                      subtitle: Text("playerUiDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => DropdownButton(
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox.shrink(),
                          value: settingsController.playerUi.value,
                          items: [
                            DropdownMenuItem(
                                value: 0, child: Text("standard".tr)),
                            DropdownMenuItem(
                              value: 1,
                              child: Text("gesture".tr),
                            ),
                          ],
                          onChanged: settingsController.setPlayerUi,
                        ),
                      ),
                    ),
                  if (!isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("enableBottomNav".tr),
                        subtitle: Text("enableBottomNavDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .isBottomNavBarEnabled.isTrue,
                              onChanged: settingsController.enableBottomNavBar),
                        )),
                  ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("disableTransitionAnimation".tr),
                      subtitle: Text("disableTransitionAnimationDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .isTransitionAnimationDisabled.isTrue,
                            onChanged:
                                settingsController.disableTransitionAnimation),
                      )),
                  ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("enableSlidableAction".tr),
                      subtitle: Text("enableSlidableActionDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value:
                                settingsController.slidableActionEnabled.isTrue,
                            onChanged: settingsController.toggleSlidableAction),
                      )),
                ],
              ),
              CustomExpansionTile(
                title: "Discord Status (Rich Presence)",
                icon: Icons.discord_rounded,
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101422),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF5865F2).withOpacity(0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5865F2).withOpacity(0.12),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5865F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.music_note_rounded,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "discordActivity".tr,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Obx(
                              () => CustSwitch(
                                value:
                                    settingsController.discordRpcEnabled.value,
                                onChanged: (val) {
                                  settingsController.toggleDiscordRpc(val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "discordActivityDes".tr,
                          style:
                              const TextStyle(fontSize: 12.5, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFF5865F2), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Obx(() {
                                  final isEnabled = settingsController
                                      .discordRpcEnabled.value;
                                  final hasToken =
                                      DiscordService().token.isNotEmpty;
                                  return Text(
                                    isEnabled
                                        ? (hasToken
                                            ? "discordStatusActive".tr
                                            : "Status: Active • Synchronized on PC & Android")
                                        : "Status: Disabled",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isEnabled
                                          ? const Color(0xFF5865F2)
                                          : Colors.white38,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _DiscordTokenInputWidget(),
                      ],
                    ),
                  ),
                ],
              ),
              CustomExpansionTile(
                  title: "content".tr,
                  icon: Icons.music_video,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("setDiscoverContent".tr),
                      subtitle: Obx(() => Text(
                          settingsController.discoverContentType.value == "QP"
                              ? "quickpicks".tr
                              : settingsController.discoverContentType.value ==
                                      "TMV"
                                  ? "topmusicvideos".tr
                                  : settingsController
                                              .discoverContentType.value ==
                                          "TR"
                                      ? "trending".tr
                                      : "basedOnLast".tr,
                          style: Theme.of(context).textTheme.bodyMedium)),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) =>
                            const DiscoverContentSelectorDialog(),
                      ),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("homeContentCount".tr),
                      subtitle: Text("homeContentCountDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => DropdownButton(
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox.shrink(),
                          value: settingsController.noOfHomeScreenContent.value,
                          items: ([3, 5, 7, 9, 11])
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text("$e")))
                              .toList(),
                          onChanged: settingsController.setContentNumber,
                        ),
                      ),
                    ),
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("cacheHomeScreenData".tr),
                        subtitle: Text("cacheHomeScreenDataDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value:
                                  settingsController.cacheHomeScreenData.value,
                              onChanged:
                                  settingsController.toggleCacheHomeScreenData),
                        )),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("clearImgCache".tr),
                      subtitle: Text(
                        "clearImgCacheDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      isThreeLine: true,
                      onTap: () {
                        settingsController.clearImagesCache().then((value) =>
                            ScaffoldMessenger.of(Get.context!).showSnackBar(
                                snackbar(Get.context!, "clearImgCacheAlert".tr,
                                    size: SanckBarSize.BIG)));
                      },
                    ),
                  ]),
              CustomExpansionTile(
                title: "music&Playback".tr,
                icon: Icons.music_note,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("streamingQuality".tr),
                    subtitle: Obx(
                      () => Text(
                        settingsController.streamingQuality.value == AudioQuality.Ultra
                            ? "streamingQualityUltra".tr
                            : settingsController.streamingQuality.value == AudioQuality.Mid
                                ? "streamingQualityMid".tr
                                : "streamingQualityNormal".tr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    trailing: Obx(
                      () => DropdownButton<AudioQuality>(
                        dropdownColor: Theme.of(context).cardColor,
                        underline: const SizedBox.shrink(),
                        value: settingsController.streamingQuality.value,
                        items: [
                          DropdownMenuItem(
                            value: AudioQuality.Normal,
                            child: Text("qualityNormal".tr),
                          ),
                          DropdownMenuItem(
                            value: AudioQuality.Mid,
                            child: Text("qualityMid".tr),
                          ),
                          DropdownMenuItem(
                            value: AudioQuality.Ultra,
                            child: Text("qualityUltra".tr),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsController.setStreamingQuality(val);
                        },
                      ),
                    ),
                  ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("loudnessNormalization".tr),
                        subtitle: Text("loudnessNormalizationDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .loudnessNormalizationEnabled.value,
                              onChanged: settingsController
                                  .toggleLoudnessNormalization),
                        )),
                  if (!isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("cacheSongs".tr),
                        subtitle: Text("cacheSongsDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController.cacheSongs.value,
                              onChanged:
                                  settingsController.toggleCachingSongsValue),
                        )),
                  if (!isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("skipSilence".tr),
                        subtitle: Text("skipSilenceDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value:
                                  settingsController.skipSilenceEnabled.value,
                              onChanged: settingsController.toggleSkipSilence),
                        )),
                  if (isDesktop)
                    ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 5, right: 10),
                        title: Text("backgroundPlay".tr),
                        subtitle: Text("backgroundPlayDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .backgroundPlayEnabled.value,
                              onChanged:
                                  settingsController.toggleBackgroundPlay),
                        )),
                  ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("keepScreenOnWhilePlaying".tr),
                      subtitle: Text("keepScreenOnWhilePlayingDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.keepScreenAwake.value,
                            onChanged:
                                settingsController.toggleKeepScreenAwake),
                      )),
                  ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("restoreLastPlaybackSession".tr),
                      subtitle: Text("restoreLastPlaybackSessionDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value:
                                settingsController.restorePlaybackSession.value,
                            onChanged: settingsController
                                .toggleRestorePlaybackSession),
                      )),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("autoOpenPlayer".tr),
                    subtitle: Text("autoOpenPlayerDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Obx(
                      () => CustSwitch(
                          value: settingsController.autoOpenPlayer.value,
                          onChanged: settingsController.toggleAutoOpenPlayer),
                    ),
                  ),
                  if (!isDesktop)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 5, right: 10, top: 0),
                      title: Text("equalizerSettingsTitle".tr),
                      subtitle: Text("equalizerSettingsSub".tr),
                      trailing: const Icon(Icons.equalizer_rounded, color: Color(0xFF00D2FF)),
                      onTap: () {
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 550),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
                          ),
                          isScrollControlled: true,
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.6),
                          builder: (context) => const InAppEqualizerSheet(),
                        );
                      },
                    ),
                  if (!isDesktop)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("stopMusicOnTaskClear".tr),
                      subtitle: Text("stopMusicOnTaskClearDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .stopPlyabackOnSwipeAway.value,
                            onChanged: settingsController
                                .toggleStopPlyabackOnSwipeAway),
                      ),
                    ),
                  if (!isDesktop)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("playDuringCallsTitle".tr),
                      subtitle: Text("playDuringCallsDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.playDuringCalls.value,
                            onChanged: settingsController.togglePlayDuringCalls),
                      ),
                    ),
                  GetPlatform.isAndroid
                      ? Obx(
                          () => ListTile(
                            contentPadding:
                                const EdgeInsets.only(left: 5, right: 10),
                            title: Text("ignoreBatOpt".tr),
                            onTap: settingsController
                                    .isIgnoringBatteryOptimizations.isFalse
                                ? settingsController
                                    .enableIgnoringBatteryOptimizations
                                : null,
                            subtitle: Obx(() => RichText(
                                  text: TextSpan(
                                    text:
                                        "${"status".tr}: ${settingsController.isIgnoringBatteryOptimizations.isTrue ? "enabled".tr : "disabled".tr}\n",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(fontWeight: FontWeight.bold),
                                    children: <TextSpan>[
                                      TextSpan(
                                          text: "ignoreBatOptDes".tr,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                    ],
                                  ),
                                )),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
              CustomExpansionTile(
                title: "download".tr,
                icon: Icons.download,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("autoDownFavSong".tr),
                    subtitle: Text("autoDownFavSongDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Obx(
                      () => CustSwitch(
                          value: settingsController
                              .autoDownloadFavoriteSongEnabled.value,
                          onChanged: settingsController
                              .toggleAutoDownloadFavoriteSong),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 5, right: 10),
                    title: Text("downloadingFormat".tr),
                    subtitle: Text("downloadingFormatDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Obx(
                      () => DropdownButton(
                        dropdownColor: Theme.of(context).cardColor,
                        underline: const SizedBox.shrink(),
                        value: settingsController.downloadingFormat.value,
                        items: const [
                          DropdownMenuItem(
                              value: "opus", child: Text("Opus/Ogg")),
                          DropdownMenuItem(
                            value: "m4a",
                            child: Text("M4a"),
                          ),
                        ],
                        onChanged: settingsController.changeDownloadingFormat,
                      ),
                    ),
                  ),
                  ListTile(
                    trailing: TextButton(
                      child: Text(
                        "reset".tr,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontSize: 15),
                      ),
                      onPressed: () {
                        settingsController.resetDownloadLocation();
                      },
                    ),
                    contentPadding:
                        const EdgeInsets.only(left: 5, right: 10, top: 0),
                    title: Text("downloadLocation".tr),
                    subtitle: Obx(() => Text(
                        settingsController.isCurrentPathsupportDownDir
                            ? "In App storage directory"
                            : settingsController.downloadLocationPath.value,
                        style: Theme.of(context).textTheme.bodyMedium)),
                    onTap: () async {
                      settingsController.setDownloadLocation();
                    },
                  ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("exportDowloadedFiles".tr),
                      subtitle: Text(
                        "exportDowloadedFilesDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      isThreeLine: true,
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const ExportFileDialog(),
                      ).whenComplete(
                          () => Get.delete<ExportFileDialogController>()),
                    ),
                  if (GetPlatform.isAndroid)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 5, right: 10, top: 0),
                      title: Text("exportedFileLocation".tr),
                      subtitle: Obx(() => Text(
                          settingsController.exportLocationPath.value,
                          style: Theme.of(context).textTheme.bodyMedium)),
                      onTap: () async {
                        settingsController.setExportedLocation();
                      },
                    ),
                ],
              ),
              CustomExpansionTile(
                  title: "${"backup".tr} & ${"restore".tr}",
                  icon: Icons.restore,
                  children: const [
                    AutoBackupSettingsWidget(),
                  ]),
              CustomExpansionTile(
                  icon: Icons.miscellaneous_services,
                  title: "misc".tr,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 5, right: 10),
                      title: Text("resetToDefault".tr),
                      subtitle: Text(
                        "resetToDefaultDes".tr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () {
                        settingsController
                            .resetAppSettingsToDefault()
                            .then((_) {
                          ScaffoldMessenger.of(Get.context!).showSnackBar(
                              snackbar(Get.context!, "resetToDefaultMsg".tr,
                                  size: SanckBarSize.BIG,
                                  duration: const Duration(seconds: 2)));
                        });
                      },
                    ),
                  ]),
              CustomExpansionTile(
                icon: Icons.info,
                title: "appInfo".tr,
                children: [
                  ListTile(
                    leading: const Icon(Icons.system_update_rounded,
                        color: Color(0xFF00D2FF)),
                    title: Text("checkForUpdates".tr),
                    subtitle: Text("checkForUpdatesDes".tr),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: Colors.white54),
                    onTap: () =>
                        settingsController.checkForUpdatesManually(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading:
                        const Icon(Icons.code_rounded, color: Colors.white70),
                    contentPadding: const EdgeInsets.only(left: 15, right: 10),
                    title: const Text("GitHub Repository"),
                    subtitle: Text(
                      "${"githubSource".tr}\n${settingsController.currentVersion} by SPY",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    isThreeLine: true,
                    onTap: () {
                      launchUrl(
                        Uri.parse(
                          'https://github.com/spicy-os123-python-main/SPY-MUSIC',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  const Divider(),
                  SizedBox(
                    child: Column(
                      children: [
                        Text(
                          "SPY MUSIC",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(settingsController.currentVersion,
                            style: Theme.of(context).textTheme.titleMedium)
                      ],
                    ),
                  ),
                ],
              )
            ],
          )),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Text(
              "${settingsController.currentVersion} by SPY",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Container(
        height: 300,
        //color: Theme.of(context).cardColor,
        padding: const EdgeInsets.only(top: 30, left: 5, right: 30, bottom: 10),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "themeMode".tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          radioWidget(
            label: "dynamic".tr,
            controller: settingsController,
            value: ThemeType.dynamic,
          ),
          radioWidget(
              label: "systemDefault".tr,
              controller: settingsController,
              value: ThemeType.system),
          radioWidget(
              label: "dark".tr,
              controller: settingsController,
              value: ThemeType.dark),
          radioWidget(
              label: "light".tr,
              controller: settingsController,
              value: ThemeType.light),
          Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("cancel".tr),
                ),
                onTap: () => Navigator.of(context).pop(),
              ))
        ]),
      ),
    );
  }
}

class DiscoverContentSelectorDialog extends StatelessWidget {
  const DiscoverContentSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Container(
        height: 300,
        //color: Theme.of(context).cardColor,
        padding: const EdgeInsets.only(top: 30, left: 5, right: 30, bottom: 10),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "setDiscoverContent".tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  radioWidget(
                      label: "quickpicks".tr,
                      controller: settingsController,
                      value: "QP"),
                  radioWidget(
                      label: "topmusicvideos".tr,
                      controller: settingsController,
                      value: "TMV"),
                  radioWidget(
                      label: "trending".tr,
                      controller: settingsController,
                      value: "TR"),
                  radioWidget(
                      label: "basedOnLast".tr,
                      controller: settingsController,
                      value: "BOLI"),
                ],
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
          Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("cancel".tr),
                ),
                onTap: () => Navigator.of(context).pop(),
              ))
        ]),
      ),
    );
  }
}

Widget radioWidget(
    {required String label,
    required SettingsScreenController controller,
    required value}) {
  return Obx(() => ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        onTap: () {
          if (value.runtimeType == ThemeType) {
            controller.onThemeChange(value);
          } else {
            controller.onContentChange(value);
            Navigator.of(Get.context!).pop();
          }
        },
        leading: Radio(
            value: value,
            groupValue: value.runtimeType == ThemeType
                ? controller.themeModetype.value
                : controller.discoverContentType.value,
            onChanged: value.runtimeType == ThemeType
                ? controller.onThemeChange
                : controller.onContentChange),
        title: Text(label),
      ));
}

class _DiscordTokenInputWidget extends StatefulWidget {
  const _DiscordTokenInputWidget();

  @override
  State<_DiscordTokenInputWidget> createState() => _DiscordTokenInputWidgetState();
}

class _DiscordTokenInputWidgetState extends State<_DiscordTokenInputWidget> {
  late TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: DiscordService().token);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveToken() {
    final text = _controller.text.trim();
    DiscordService().setToken(text);
    ScaffoldMessenger.of(context).showSnackBar(
      snackbar(
        context,
        text.isNotEmpty
            ? "discordTokenSaved".tr
            : "discordTokenRemoved".tr,
        size: SanckBarSize.BIG,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = DiscordService().isGatewayConnected;
    final hasToken = DiscordService().token.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF5865F2)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smartphone_rounded,
                size: 16,
                color: isConnected ? const Color(0xFF5865F2) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                "discordMobileStatus".tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (isConnected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5865F2).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF5865F2), width: 0.8),
                  ),
                  child: Text(
                    "connected".tr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5865F2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "discordTokenDes".tr,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => const DiscordLoginDialog(),
              );
              if (result == true) {
                _controller.text = DiscordService().token;
                setState(() {});
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5865F2), Color(0xFF4752C4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5865F2).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.discord_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "🎮 1-Klick Discord Login",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(0.12),
                  thickness: 0.8,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "orManualToken".tr,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(0.12),
                  thickness: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _controller,
                    obscureText: _obscureText,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "discordTokenHint".tr,
                      hintStyle:
                          const TextStyle(fontSize: 12, color: Colors.white30),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.black38,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF5865F2)),
                      ),
                      suffixIcon: IconButton(
                        iconSize: 18,
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _saveToken,
                  child: Text("save".tr, style: const TextStyle(fontSize: 12)),
                ),
              ),
              if (hasToken) ...[
                const SizedBox(width: 6),
                SizedBox(
                  height: 40,
                  child: IconButton(
                    iconSize: 20,
                    tooltip: "deleteToken".tr,
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () {
                      _controller.clear();
                      _saveToken();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
