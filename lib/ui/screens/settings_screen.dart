import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/settings_provider.dart';
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
          _buildSectionHeader(l10n.appearance),
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
            trailing: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: settingsProv.accentColor,
                shape: BoxShape.circle,
              ),
            ),
            onTap: () => _showColorPicker(context, settingsProv, l10n),
          ),

          const Divider(),
          _buildSectionHeader(l10n.layoutDisplay),
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
          _buildSectionHeader(l10n.contentSafety),
          SwitchListTile(
            secondary: const Icon(Icons.shield),
            title: Text(l10n.defaultSafeMode),
            subtitle: Text(l10n.defaultSafeModeSub),
            value: settingsProv.defaultSafeMode,
            onChanged: (val) => settingsProv.setDefaultSafeMode(val),
          ),

          const Divider(),
          _buildSectionHeader(l10n.networkAntiWaf),
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
          _buildSectionHeader(l10n.about),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider settingsProv, AppLocalizations l10n) {
    final colors = [
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF607D8B), // Blue Grey
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chooseAccentColor),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final isSelected = c.toARGB32() == settingsProv.accentColor.toARGB32();
            return GestureDetector(
              onTap: () {
                settingsProv.setAccentColor(c);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
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
}
