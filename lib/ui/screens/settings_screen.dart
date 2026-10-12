import 'dart:io' show Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/utils/file_downloader.dart';
import '../../providers/settings_provider.dart';
import '../../services/tag_translation_service.dart';
import '../../services/app_update_manager.dart';
import '../widgets/tag_db_update_dialog.dart';
import '../widgets/settings_control_tile.dart';
import '../widgets/theme_color_dialog.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'lan_sync_screen.dart';
import 'reverse_search_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: Text(l10n.isZh ? '搜图引擎' : 'Image search engines'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReverseSearchSettingsScreen(),
              ),
            ),
          ),
          if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(l10n.isZh ? '局域网同步' : 'LAN sync'),
              subtitle: Text(
                l10n.isZh
                    ? 'Windows ↔ Android，含登录信息'
                    : 'Windows ↔ Android, including logins',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanSyncScreen()),
              ),
            ),
          _buildSectionHeader(context, l10n.appearance),
          // Language selector
          SettingsControlTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_getLanguageName(settingsProv.languageCode, l10n)),
            controlWidth: 180,
            control: DropdownButton<String>(
              value: settingsProv.languageCode,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.followSystem),
                ),
                DropdownMenuItem(value: 'zh', child: Text(l10n.chinese)),
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
              ],
              onChanged: (code) {
                if (code != null) settingsProv.setLanguage(code);
              },
            ),
          ),
          SettingsControlTile(
            leading: const Icon(Icons.brightness_medium),
            title: Text(l10n.themeMode),
            subtitle: Text(_getThemeModeName(settingsProv.themeMode, l10n)),
            controlWidth: 180,
            control: DropdownButton<ThemeMode>(
              value: settingsProv.themeMode,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.themeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.themeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.themeDark),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) settingsProv.setThemeMode(mode);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(l10n.amoledBlack),
            subtitle: Text(l10n.amoledBlackSub),
            value: settingsProv.amoled,
            onChanged: (val) => settingsProv.setAmoled(val),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(l10n.accentColor),
            subtitle: Text(
              settingsProv.useGradient ? l10n.gradientEnabled : l10n.solidColor,
            ),
            trailing: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: settingsProv.useGradient
                    ? settingsProv.primaryGradient
                    : null,
                color: settingsProv.useGradient
                    ? null
                    : settingsProv.accentColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: settingsProv.accentColor.withValues(alpha: 0.35),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            onTap: () => _showColorPicker(context, settingsProv, l10n),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.layoutDisplay),
          SettingsControlTile(
            leading: const Icon(Icons.view_column),
            title: Text(l10n.gridColumns),
            subtitle: Text(
              settingsProv.gridColumns == 0
                  ? l10n.gridAuto
                  : l10n.gridCount(settingsProv.gridColumns),
            ),
            controlWidth: 180,
            control: DropdownButton<int>(
              value: settingsProv.gridColumns,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 0, child: Text(l10n.gridAuto)),
                DropdownMenuItem(value: 2, child: Text(l10n.gridCount(2))),
                DropdownMenuItem(value: 3, child: Text(l10n.gridCount(3))),
                DropdownMenuItem(value: 4, child: Text(l10n.gridCount(4))),
                DropdownMenuItem(value: 5, child: Text(l10n.gridCount(5))),
              ],
              onChanged: (cols) {
                if (cols != null) settingsProv.setGridColumns(cols);
              },
            ),
          ),
          SettingsControlTile(
            leading: const Icon(Icons.high_quality),
            title: Text(l10n.defaultImageQuality),
            subtitle: Text(_getQualityName(settingsProv.imageQuality, l10n)),
            controlWidth: 180,
            control: DropdownButton<String>(
              value: settingsProv.imageQuality,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'preview',
                  child: Text(l10n.qualityPreview),
                ),
                DropdownMenuItem(
                  value: 'sample',
                  child: Text(l10n.qualitySample),
                ),
                DropdownMenuItem(
                  value: 'original',
                  child: Text(l10n.qualityOriginal),
                ),
              ],
              onChanged: (q) {
                if (q != null) settingsProv.setImageQuality(q);
              },
            ),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.tagDatabase),
          SettingsControlTile(
            leading: const Icon(Icons.translate),
            title: Text(l10n.tagLanguage),
            subtitle: Text(
              _getTagLanguageName(
                settingsProv.tagLanguage,
                settingsProv.effectiveTagLanguage,
                l10n,
              ),
            ),
            controlWidth: 180,
            control: DropdownButton<String>(
              value: settingsProv.tagLanguage,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.tagLangSystem),
                ),
                DropdownMenuItem(value: 'zh', child: Text(l10n.tagLangZh)),
                DropdownMenuItem(value: 'en', child: Text(l10n.tagLangEn)),
              ],
              onChanged: (code) {
                if (code != null) settingsProv.setTagLanguage(code);
              },
            ),
          ),
          SettingsControlTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.tagDatabase),
            subtitle: Text(
              TagTranslationService().isDatabaseReady
                  ? '${l10n.tagDbReady} (${l10n.tagDbTotalTags(TagTranslationService().getLoadedTagCount())})'
                  : l10n.tagDbEmbedded,
            ),
            control: OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 16),
              label: Text(
                TagTranslationService().isDatabaseReady
                    ? l10n.checkTagDbUpdate
                    : l10n.downloadTagDb,
              ),
              onPressed: () => TagDbUpdateHelper.checkAndUpdate(context),
            ),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.downloadSettings),
          FutureBuilder<Directory>(
            future: FileDownloader.resolveDownloadDirectory(
              settingsProv.downloadPath,
            ),
            builder: (context, snapshot) {
              final resolvedPath = snapshot.data?.path ?? '';
              final isCustom = settingsProv.downloadPath.isNotEmpty;
              return SettingsControlTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.downloadPath),
                subtitle: Text(
                  isCustom
                      ? settingsProv.downloadPath
                      : '${l10n.defaultPath}: $resolvedPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (FileDownloader.isSystemPickerSupported)
                      IconButton(
                        tooltip: l10n.browseViaSystemDialog,
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          final picked =
                              await FileDownloader.pickDirectoryViaSystemDialog(
                                initialPath: isCustom
                                    ? settingsProv.downloadPath
                                    : resolvedPath,
                              );
                          if (picked != null && picked.isNotEmpty) {
                            final isWritable =
                                await FileDownloader.isDirectoryWritable(
                                  picked,
                                );
                            if (isWritable) {
                              await settingsProv.setDownloadPath(picked);
                            }
                          }
                        },
                      ),
                    IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showDownloadPathDialog(
                        context,
                        settingsProv,
                        l10n,
                        resolvedPath,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showDownloadPathDialog(
                  context,
                  settingsProv,
                  l10n,
                  resolvedPath,
                ),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.contentSafety),
          SwitchListTile(
            secondary: const Icon(Icons.shield),
            title: Text(l10n.defaultSafeMode),
            subtitle: Text(l10n.defaultSafeModeSub),
            value: settingsProv.defaultSafeMode,
            onChanged: (val) => settingsProv.setDefaultSafeMode(val),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.networkAntiWaf),
          ListTile(
            leading: const Icon(Icons.http),
            title: Text(l10n.customUserAgent),
            subtitle: Text(
              settingsProv.userAgent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _editUserAgent(context, settingsProv, l10n),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.about),
          AnimatedBuilder(
            animation: AppUpdateManager.instance,
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l10n.checkUpdates),
              subtitle: Text(
                AppUpdateManager.instance.busy
                    ? l10n.downloadingUpdate
                    : AppUpdateManager.instance.state ==
                          UpdateDownloadState.ready
                    ? l10n.updateReady
                    : '${l10n.currentVersion}: v${AppConstants.rawVersion}',
              ),
              trailing: AppUpdateManager.instance.busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: AppUpdateManager.instance.progress,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
              onTap: () => UpdateCheckHelper.checkUpdate(context),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: Text(l10n.autoCheckUpdates),
            subtitle: Text(l10n.autoCheckUpdatesSub),
            value: settingsProv.autoCheckUpdate,
            onChanged: (val) => settingsProv.setAutoCheckUpdate(val),
          ),
          if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
            SwitchListTile(
              secondary: const Icon(Icons.download),
              title: Text(l10n.autoDownloadUpdates),
              subtitle: Text(l10n.autoDownloadUpdatesSub),
              value: settingsProv.autoDownloadUpdate,
              onChanged: settingsProv.setAutoDownloadUpdate,
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${l10n.about} Flexbooru'),
            subtitle: const Text(AppConstants.appVersion),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code, AppLocalizations l10n) {
    switch (code) {
      case 'zh':
        return l10n.chinese;
      case 'en':
        return l10n.english;
      default:
        return l10n.followSystem;
    }
  }

  String _getTagLanguageName(
    String code,
    String effective,
    AppLocalizations l10n,
  ) {
    if (code == 'zh') return l10n.tagLangZh;
    if (code == 'en') return l10n.tagLangEn;
    return '${l10n.tagLangSystem} (${effective == 'zh' ? l10n.tagLangZh : l10n.tagLangEn})';
  }

  String _getThemeModeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
      default:
        return l10n.themeSystem;
    }
  }

  String _getQualityName(String q, AppLocalizations l10n) {
    switch (q) {
      case 'preview':
        return l10n.qualityPreview;
      case 'original':
        return l10n.qualityOriginal;
      default:
        return l10n.qualitySample;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final settingsProv = context.watch<SettingsProvider>();

    Widget text = Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: settingsProv.useGradient
            ? Colors.white
            : theme.colorScheme.primary,
        letterSpacing: 0.3,
      ),
    );

    if (settingsProv.useGradient) {
      text = ShaderMask(
        shaderCallback: (bounds) =>
            settingsProv.primaryGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 14, bottom: 4),
      child: text,
    );
  }

  void _showColorPicker(
    BuildContext context,
    SettingsProvider settingsProv,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) =>
          ThemeColorDialog(settingsProv: settingsProv, l10n: l10n),
    );
  }

  void _editUserAgent(
    BuildContext context,
    SettingsProvider settingsProv,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController(text: settingsProv.userAgent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.customUserAgent),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: l10n.userAgentHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = AppConstants.defaultUserAgent;
            },
            child: Text(l10n.resetDefault),
          ),
          FilledButton(
            onPressed: () {
              settingsProv.setUserAgent(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showDownloadPathDialog(
    BuildContext context,
    SettingsProvider settingsProv,
    AppLocalizations l10n,
    String defaultResolvedPath,
  ) async {
    final controller = TextEditingController(
      text: settingsProv.downloadPath.isNotEmpty
          ? settingsProv.downloadPath
          : defaultResolvedPath,
    );
    final presets = await FileDownloader.getPathPresets();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.folder_outlined),
                  const SizedBox(width: 8),
                  Text(
                    l10n.chooseDownloadPath,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadPathSub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: l10n.downloadPath,
                          hintText: l10n.downloadPathHint,
                          border: const OutlineInputBorder(),
                          errorText: errorMessage,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (FileDownloader.isSystemPickerSupported)
                                IconButton(
                                  tooltip: l10n.browseViaSystemDialog,
                                  icon: const Icon(Icons.folder_open, size: 20),
                                  onPressed: () async {
                                    final picked =
                                        await FileDownloader.pickDirectoryViaSystemDialog(
                                          initialPath:
                                              controller.text.isNotEmpty
                                              ? controller.text
                                              : defaultResolvedPath,
                                        );
                                    if (picked != null && picked.isNotEmpty) {
                                      setDialogState(() {
                                        controller.text = picked;
                                        errorMessage = null;
                                      });
                                    }
                                  },
                                ),
                              if (controller.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      controller.clear();
                                      errorMessage = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        onChanged: (_) {
                          if (errorMessage != null) {
                            setDialogState(() => errorMessage = null);
                          }
                        },
                      ),
                      if (FileDownloader.isSystemPickerSupported) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: Text(l10n.browseViaSystemDialog),
                            onPressed: () async {
                              final picked =
                                  await FileDownloader.pickDirectoryViaSystemDialog(
                                    initialPath: controller.text.isNotEmpty
                                        ? controller.text
                                        : defaultResolvedPath,
                                  );
                              if (picked != null && picked.isNotEmpty) {
                                setDialogState(() {
                                  controller.text = picked;
                                  errorMessage = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                      if (presets.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          l10n.pathPresets,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (presets['downloads'] != null)
                              ActionChip(
                                avatar: const Icon(Icons.download, size: 16),
                                label: Text(l10n.presetDownloads),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = presets['downloads']!;
                                    errorMessage = null;
                                  });
                                },
                              ),
                            if (presets['pictures'] != null)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 16,
                                ),
                                label: Text(l10n.presetPictures),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = presets['pictures']!;
                                    errorMessage = null;
                                  });
                                },
                              ),
                            if (presets['app'] != null)
                              ActionChip(
                                avatar: const Icon(Icons.smartphone, size: 16),
                                label: Text(l10n.presetAppDir),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = presets['app']!;
                                    errorMessage = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      if (!kIsWeb &&
                          (Platform.isWindows ||
                              Platform.isMacOS ||
                              Platform.isLinux)) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(l10n.openFolder),
                          onPressed: () {
                            final p = controller.text.trim();
                            if (p.isNotEmpty) {
                              FileDownloader.openDirectory(p);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await settingsProv.setDownloadPath('');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(l10n.resetDefault),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final targetPath = controller.text.trim();
                    if (targetPath.isEmpty) {
                      await settingsProv.setDownloadPath('');
                      if (ctx.mounted) Navigator.pop(ctx);
                      return;
                    }

                    final isWritable = await FileDownloader.isDirectoryWritable(
                      targetPath,
                    );
                    if (!isWritable) {
                      setDialogState(() {
                        errorMessage = l10n.pathNotWritable;
                      });
                      return;
                    }

                    await settingsProv.setDownloadPath(targetPath);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
