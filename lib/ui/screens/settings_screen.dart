import 'dart:io' show Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/utils/file_downloader.dart';
import '../../providers/settings_provider.dart';
import '../../services/tag_translation_service.dart';
import '../widgets/tag_db_update_dialog.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.appearance),
          // Language selector
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_getLanguageName(settingsProv.languageCode, l10n)),
            trailing: DropdownButton<String>(
              value: settingsProv.languageCode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'system', child: Text(l10n.followSystem)),
                DropdownMenuItem(value: 'zh', child: Text(l10n.chinese)),
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
              ],
              onChanged: (code) {
                if (code != null) settingsProv.setLanguage(code);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_medium),
            title: Text(l10n.themeMode),
            subtitle: Text(_getThemeModeName(settingsProv.themeMode, l10n)),
            trailing: DropdownButton<ThemeMode>(
              value: settingsProv.themeMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
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
              settingsProv.useGradient
                  ? l10n.gradientEnabled
                  : l10n.solidColor,
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
          ListTile(
            leading: const Icon(Icons.view_column),
            title: Text(l10n.gridColumns),
            subtitle: Text(settingsProv.gridColumns == 0 ? l10n.gridAuto : l10n.gridCount(settingsProv.gridColumns)),
            trailing: DropdownButton<int>(
              value: settingsProv.gridColumns,
              underline: const SizedBox(),
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
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: Text(l10n.defaultImageQuality),
            subtitle: Text(_getQualityName(settingsProv.imageQuality, l10n)),
            trailing: DropdownButton<String>(
              value: settingsProv.imageQuality,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'preview', child: Text(l10n.qualityPreview)),
                DropdownMenuItem(value: 'sample', child: Text(l10n.qualitySample)),
                DropdownMenuItem(value: 'original', child: Text(l10n.qualityOriginal)),
              ],
              onChanged: (q) {
                if (q != null) settingsProv.setImageQuality(q);
              },
            ),
          ),

          const Divider(),
          _buildSectionHeader(context, l10n.tagDatabase),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(l10n.tagLanguage),
            subtitle: Text(_getTagLanguageName(settingsProv.tagLanguage, settingsProv.effectiveTagLanguage, l10n)),
            trailing: DropdownButton<String>(
              value: settingsProv.tagLanguage,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'system', child: Text(l10n.tagLangSystem)),
                DropdownMenuItem(value: 'zh', child: Text(l10n.tagLangZh)),
                DropdownMenuItem(value: 'en', child: Text(l10n.tagLangEn)),
              ],
              onChanged: (code) {
                if (code != null) settingsProv.setTagLanguage(code);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.tagDatabase),
            subtitle: Text(
              TagTranslationService().isDatabaseReady
                  ? '${l10n.tagDbReady} (${l10n.tagDbTotalTags(TagTranslationService().getLoadedTagCount())})'
                  : l10n.tagDbEmbedded,
            ),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 16),
              label: Text(TagTranslationService().isDatabaseReady ? l10n.checkTagDbUpdate : l10n.downloadTagDb),
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
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.downloadPath),
                subtitle: Text(
                  isCustom
                      ? settingsProv.downloadPath
                      : '${l10n.defaultPath}: $resolvedPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
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
                                await FileDownloader.isDirectoryWritable(picked);
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
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(l10n.checkUpdates),
            subtitle: Text('${l10n.currentVersion}: v${AppConstants.rawVersion}'),
            trailing: const Icon(Icons.refresh, size: 20),
            onTap: () => UpdateCheckHelper.checkUpdate(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: Text(l10n.autoCheckUpdates),
            subtitle: Text(l10n.autoCheckUpdatesSub),
            value: settingsProv.autoCheckUpdate,
            onChanged: (val) => settingsProv.setAutoCheckUpdate(val),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${l10n.about} Flexbooru'),
            subtitle: const Text(AppConstants.appVersion),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
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
      builder: (ctx) => _ThemeColorDialog(
        settingsProv: settingsProv,
        l10n: l10n,
      ),
    );
  }

  void _editUserAgent(BuildContext context, SettingsProvider settingsProv, AppLocalizations l10n) {
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
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                                    final picked = await FileDownloader
                                        .pickDirectoryViaSystemDialog(
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

                    final isWritable =
                        await FileDownloader.isDirectoryWritable(targetPath);
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

class _ThemeColorDialog extends StatefulWidget {
  final SettingsProvider settingsProv;
  final AppLocalizations l10n;

  const _ThemeColorDialog({
    required this.settingsProv,
    required this.l10n,
  });

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late bool _isGradient;
  late Color _startColor;
  late Color _endColor;
  late TextEditingController _startController;
  late TextEditingController _endController;
  String? _errorMessage;

  static const List<(String, Color, Color)> _gradientPresets = [
    ('极光紫粉', Color(0xFF7F00FF), Color(0xFFE100FF)),
    ('暮光霞红', Color(0xFFFF416C), Color(0xFFFF4B2B)),
    ('深海蔚蓝', Color(0xFF0052D4), Color(0xFF4364F7)),
    ('碧海青蓝', Color(0xFF00B4DB), Color(0xFF0083B0)),
    ('翡翠生机', Color(0xFF11998E), Color(0xFF38EF7D)),
    ('熔金暖阳', Color(0xFFF7971E), Color(0xFFFFD200)),
    ('赛博朋克', Color(0xFF8A2387), Color(0xFFE94057)),
    ('冰川幽蓝', Color(0xFF3A7BD5), Color(0xFF3A6073)),
    ('幻影粉紫', Color(0xFFF857A6), Color(0xFFFF5858)),
    ('钛金曜灰', Color(0xFF4B6CB7), Color(0xFF182848)),
  ];

  static const List<Color> _solidColors = [
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE53935), // Crimson
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFFA000), // Amber
    Color(0xFF00695C), // Deep Teal
  ];

  static const List<Color> _quickPalette = [
    Color(0xFFF44336),
    Color(0xFFFF5722),
    Color(0xFFFF9800),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF009688),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _isGradient = widget.settingsProv.useGradient;
    _startColor = widget.settingsProv.accentColor;
    _endColor = widget.settingsProv.gradientEndColor ?? _startColor;
    _startController = TextEditingController(text: _colorToHex(_startColor));
    _endController = TextEditingController(text: _colorToHex(_endColor));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  static String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static Color? _tryParseHex(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    if (clean.length == 8) {
      final v = int.tryParse(clean, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }

  void _applyCustom() {
    final start = _tryParseHex(_startController.text);
    if (start == null) {
      setState(() => _errorMessage = widget.l10n.invalidHexColor);
      return;
    }

    if (_isGradient) {
      final end = _tryParseHex(_endController.text);
      if (end == null) {
        setState(() => _errorMessage = widget.l10n.invalidHexColor);
        return;
      }
      widget.settingsProv.setGradientColor(start, end);
    } else {
      widget.settingsProv.setAccentColor(start);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.palette_outlined),
          const SizedBox(width: 8),
          Text(
            l10n.chooseThemeColor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
        child: DefaultTabController(
          length: 3,
          initialIndex: _isGradient ? 0 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.gradientPresets),
                  Tab(text: l10n.solidPresets),
                  Tab(text: l10n.customColors),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGradientTab(),
                    _buildSolidTab(),
                    _buildCustomTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildGradientTab() {
    final currentStart = widget.settingsProv.accentColor.toARGB32();
    final currentEnd =
        (widget.settingsProv.gradientEndColor ?? widget.settingsProv.accentColor)
            .toARGB32();
    final isGradActive = widget.settingsProv.useGradient;

    return GridView.builder(
      itemCount: _gradientPresets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final (title, start, end) = _gradientPresets[index];
        final isSelected = isGradActive &&
            currentStart == start.toARGB32() &&
            currentEnd == end.toARGB32();

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.settingsProv.setGradientColor(start, end);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: start.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 4),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check, color: Colors.white, size: 16),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolidTab() {
    final currentSolid = widget.settingsProv.accentColor.toARGB32();
    final isSolidActive = !widget.settingsProv.useGradient;

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: _solidColors.map((c) {
            final isSelected =
                isSolidActive && currentSolid == c.toARGB32();
            return GestureDetector(
              onTap: () {
                widget.settingsProv.setAccentColor(c);
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomTab() {
    final l10n = widget.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.enableGradient, style: const TextStyle(fontSize: 14)),
            value: _isGradient,
            onChanged: (val) {
              setState(() {
                _isGradient = val;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 8),

          // Start Color Picker
          _buildColorInputRow(
            label: _isGradient ? l10n.startColor : l10n.accentColor,
            color: _startColor,
            controller: _startController,
            onColorChanged: (newColor) {
              setState(() {
                _startColor = newColor;
                _startController.text = _colorToHex(newColor);
                _errorMessage = null;
              });
            },
            onHexChanged: (val) {
              final parsed = _tryParseHex(val);
              if (parsed != null) {
                setState(() {
                  _startColor = parsed;
                  _errorMessage = null;
                });
              }
            },
          ),

          if (_isGradient) ...[
            const SizedBox(height: 12),
            // End Color Picker
            _buildColorInputRow(
              label: l10n.endColor,
              color: _endColor,
              controller: _endController,
              onColorChanged: (newColor) {
                setState(() {
                  _endColor = newColor;
                  _endController.text = _colorToHex(newColor);
                  _errorMessage = null;
                });
              },
              onHexChanged: (val) {
                final parsed = _tryParseHex(val);
                if (parsed != null) {
                  setState(() {
                    _endColor = parsed;
                    _errorMessage = null;
                  });
                }
              },
            ),
          ],

          const SizedBox(height: 14),

          // Live Preview Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.livePreview,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Site Pill preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: _isGradient
                            ? LinearGradient(colors: [_startColor, _endColor])
                            : null,
                        color: _isGradient ? null : _startColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _startColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Flexbooru',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // FAB preview
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: _isGradient
                            ? LinearGradient(colors: [_startColor, _endColor])
                            : null,
                        color: _isGradient ? null : _startColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _startColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _applyCustom,
              child: Text(l10n.applyColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorInputRow({
    required String label,
    required Color color,
    required TextEditingController controller,
    required void Function(Color) onColorChanged,
    required void Function(String) onHexChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: onHexChanged,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickPalette.map((c) {
            final isSel = c.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => onColorChanged(c),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSel
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
