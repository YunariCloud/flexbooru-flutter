import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/google_drive_auth.dart';
import '../../services/google_drive_sync_service.dart';

class GoogleDriveSyncScreen extends StatefulWidget {
  const GoogleDriveSyncScreen({super.key});
  @override
  State<GoogleDriveSyncScreen> createState() => _GoogleDriveSyncScreenState();
}

class _GoogleDriveSyncScreenState extends State<GoogleDriveSyncScreen> {
  final _android = TextEditingController(), _windows = TextEditingController();
  final _secret = TextEditingController(), _password = TextEditingController();
  bool _loading = true, _working = false;
  String t(String zh, String en) => context.l10n.isZh ? zh : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = context.read<GoogleDriveSyncService>();
      await service.auth.load();
      if (!mounted) return;
      final config = service.auth.config;
      _android.text = config.androidServerId;
      _windows.text = config.windowsClientId;
      _secret.text = config.windowsSecret;
    } catch (_) {
      /* Configuration remains editable when secure storage fails. */
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError &&
                      error.message.toString().contains('Restart')
                  ? t(
                      '更换 Android 客户端需要先重启应用。',
                      'Restart before changing the Android client.',
                    )
                  : t(
                      '操作失败，请检查 OAuth 配置、密码和网络。',
                      'Check OAuth configuration, password and network.',
                    ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_android, _windows, _secret, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _status(GoogleDriveSyncService service) => switch (service.error ??
      service.status) {
    'password' => t(
      '同步密码不正确，或云端内容校验失败。原数据未覆盖。',
      'Wrong sync password or cloud integrity failure. Original data was preserved.',
    ),
    'authorization' => t(
      '需要重新登录，或 OAuth / Drive API 配置不完整。',
      'Sign in again or check OAuth / Drive API configuration.',
    ),
    'network' => t(
      '网络暂不可用，将自动重试。',
      'Network unavailable. Automatic retry is enabled.',
    ),
    'data' => t(
      '云端数据格式异常，请保留原文件并检查配置。',
      'Cloud data format is invalid. Keep the original files and check configuration.',
    ),
    'storage' => t(
      '无法读取安全存储，请重试。',
      'Secure storage is unavailable. Please retry.',
    ),
    'connecting' => t('正在登录 Google…', 'Signing in to Google…'),
    'syncing' => t('正在加密并合并数据…', 'Encrypting and merging data…'),
    'connected' => t('已连接', 'Connected'),
    _ => t('未开启', 'Disabled'),
  };
  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_working,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final service = context.watch<GoogleDriveSyncService>();
    return Scaffold(
      appBar: AppBar(title: Text(t('Google Drive 同步', 'Google Drive sync'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t(
                    '在同一个 Google Cloud 项目配置两端登录，并使用同一 Google 账号和独立同步密码。首次连接会合并两端信息。',
                    'Configure both platforms in the same Google Cloud project. Use the same Google account and independent sync password. Initial connection merges data.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    '同步设置、收藏、搜索草稿/历史/预设及站点登录信息。已下载文件、缓存、下载目录和 Google 授权令牌不参与同步。前台每 30 秒检查，本地修改合并后自动上传；手机进入后台暂停。',
                    'Sync settings, favorites, searches and site credentials. Downloads, caches, local paths and Google tokens stay local. Check every 30 seconds in the foreground; local edits upload automatically. Mobile pauses in the background.',
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_status(service)),
                        if (service.auth.email != null)
                          Text(service.auth.email!),
                        if (service.lastSync != null)
                          Text(
                            '${t('上次同步', 'Last sync')}: ${service.lastSync!.toLocal()}',
                          ),
                        if (service.busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
                ExpansionTile(
                  title: Text(t('首次配置说明', 'First-time setup')),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        t(
                          '1. 在 Google Cloud 创建一个项目，启用 Google Drive API。\n'
                              '2. 配置 OAuth 同意屏幕；测试阶段把自己的 Google 邮箱加入测试用户。申请 drive.appdata 权限。\n'
                              '3. Android：创建 Android OAuth 客户端（包名 com.flexbooru.app.flexbooru，填写已安装 APK 的签名 SHA-1），再创建 Web 客户端，将 Web Client ID 填到下方 Android Server Client ID。无需填写 Web Secret。\n'
                              '4. Windows：在同一项目创建 Desktop app OAuth 客户端，填写 Client ID 与 Client Secret。登录会在系统浏览器打开，并回到本机回调地址。\n'
                              '5. 两端使用同一个 Google 账号、同一个至少 12 字符的同步密码。忘记密码无法恢复云端密文；不要填写 Google 账号密码。\n'
                              '6. 云端内容位于隐藏 appDataFolder，普通 Drive 文件不受访问。断开连接保留云端信息。更换 Android 客户端 ID 前需重启应用。',
                          '1. Create a Google Cloud project and enable Google Drive API.\n'
                              '2. Configure OAuth consent and add your account as a test user. Request drive.appdata.\n'
                              '3. Android: register an Android OAuth client with package com.flexbooru.app.flexbooru and the installed APK signing SHA-1. Also create a Web client; enter its Client ID as Android Server Client ID. No Web secret is needed.\n'
                              '4. Windows: create a Desktop app OAuth client in the same project, then enter its ID and secret. Sign-in opens the system browser with a loopback callback.\n'
                              '5. Both devices need the same Google account and sync password (12+ characters). A forgotten password cannot decrypt cloud data. Never enter your Google account password here.\n'
                              '6. Data is in hidden appDataFolder; ordinary Drive files are not accessed. Disconnect keeps cloud data. Restart before changing the Android client ID.',
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://console.cloud.google.com/apis/credentials',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        t(
                          '打开 Google Cloud 配置',
                          'Open Google Cloud configuration',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (Platform.isAndroid)
                  _field(_android, 'Android Server Client ID (Web OAuth)'),
                if (Platform.isWindows) ...[
                  _field(_windows, 'Windows Desktop Client ID'),
                  _field(
                    _secret,
                    'Windows Desktop Client Secret',
                    secret: true,
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: _working || service.busy
                      ? null
                      : () => _run(
                          () => service.configure(
                            DriveOAuthConfig(
                              androidServerId: _android.text.trim(),
                              windowsClientId: _windows.text.trim(),
                              windowsSecret: _secret.text.trim(),
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(t('保存 OAuth 配置', 'Save OAuth configuration')),
                ),
                const SizedBox(height: 16),
                _field(
                  _password,
                  t(
                    '独立同步密码（至少 12 字符）',
                    'Independent sync password (12+ characters)',
                  ),
                  secret: true,
                ),
                FilledButton.icon(
                  onPressed: _working || service.busy
                      ? null
                      : () => _run(() async {
                          await service.connect(_password.text);
                          if (service.enabled) _password.clear();
                        }),
                  icon: const Icon(Icons.cloud_sync),
                  label: Text(t('Google 登录并开始同步', 'Sign in and start sync')),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: !service.enabled || _working || service.busy
                          ? null
                          : () => _run(service.syncNow),
                      child: Text(t('立即同步 / 重试', 'Sync now / retry')),
                    ),
                    TextButton(
                      onPressed: !service.enabled && !service.busy
                          ? null
                          : () async {
                              await service.disconnect();
                              _password.clear();
                            },
                      child: Text(t('断开连接 / 取消', 'Disconnect / cancel')),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
