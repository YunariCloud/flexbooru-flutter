import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.about} ${AppConstants.appName}')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppConstants.appVersion,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.aboutAppSub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.bug_report_outlined,
                    color: Colors.green,
                  ),
                  title: Text(
                    l10n.bugFixesAndUpgrades,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l10n.isZh
                        ? '• 修复 Danbooru 默认 User-Agent 与自定义 UA 不生效的问题\n'
                              '• 补齐 Gelbooru API 认证与错误提示\n'
                              '• 修复 Rule34 API 地址、安全查询与假空结果\n'
                              '• 更新 Sankaku API、字符串 ID 与游标分页\n'
                              '• 区分认证、403、Cloudflare 验证和网络超时\n'
                              '• 移除 Lolibooru 预设并清理旧配置'
                        : '• Fixed Danbooru default and custom User-Agent behavior\n'
                              '• Added Gelbooru API authentication and error guidance\n'
                              '• Fixed Rule34 API endpoint, safe searches and false empty results\n'
                              '• Updated Sankaku API, string IDs and cursor pagination\n'
                              '• Distinguish authentication, 403, challenges and timeouts\n'
                              '• Removed Lolibooru presets and migrated saved sites',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.currentProject),
                  subtitle: const Text(
                    'https://github.com/YunariCloud/flexbooru-flutter',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _launch(
                    'https://github.com/YunariCloud/flexbooru-flutter',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.originalProject),
                  subtitle: const Text(
                    'https://github.com/flexbooru/flexbooru',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () =>
                      _launch('https://github.com/flexbooru/flexbooru'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: Text(l10n.license),
                  subtitle: const Text(
                    'GNU General Public License v3.0 (GPL-3.0)',
                  ),
                  onTap: () =>
                      _launch('https://www.gnu.org/licenses/gpl-3.0.html'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
