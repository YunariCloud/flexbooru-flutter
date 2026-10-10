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
      appBar: AppBar(
        title: Text('${l10n.about} ${AppConstants.appName}'),
      ),
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
                  child: Icon(Icons.photo_library, size: 40, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  leading: const Icon(Icons.bug_report_outlined, color: Colors.green),
                  title: Text(l10n.bugFixesAndUpgrades, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    l10n.isZh
                        ? '• 解决 Danbooru HTTP 422 标签超限问题 (自动客户端黑名单与安全分级过滤)\n'
                          '• 修复 Moebooru / Yande.re 协议相对 URL 导致图片加载失败\n'
                          '• 增强 Gelbooru 现代 JSON 多层结构兼容与 XML 智能降级\n'
                          '• 更新 Sankaku Complex API v2 游标分页与防屏蔽请求头\n'
                          '• 修复 Paheal Shimmie XML 解析与相对路径提取\n'
                          '• 升级 Android 13/14+ 分区存储与跨平台下载规范'
                        : '• Fixed Danbooru HTTP 422 2-tag limit with client-side filtering\n'
                          '• Fixed Moebooru / Yande.re protocol-relative image URLs\n'
                          '• Fixed Gelbooru modern JSON varying envelopes & XML fallback\n'
                          '• Fixed Sankaku Complex API v2 keyset & Cloudflare headers\n'
                          '• Fixed Paheal Shimmie XML parsing & relative URLs\n'
                          '• Modern Android 13/14+ scoped storage downloads',
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
                  title: Text(l10n.originalProject),
                  subtitle: const Text('https://github.com/flexbooru/flexbooru'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _launch('https://github.com/flexbooru/flexbooru'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: Text(l10n.license),
                  subtitle: const Text('GNU General Public License v3.0 (GPL-3.0)'),
                  onTap: () => _launch('https://www.gnu.org/licenses/gpl-3.0.html'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
