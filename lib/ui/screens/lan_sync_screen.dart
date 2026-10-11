import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/lan_sync_service.dart';

class LanSyncScreen extends StatefulWidget {
  const LanSyncScreen({super.key});
  @override
  State<LanSyncScreen> createState() => _LanSyncScreenState();
}

class _LanSyncScreenState extends State<LanSyncScreen> {
  List<String> _addresses = [];
  String? _address;
  bool _busy = false;
  String t(String zh, String en) => context.l10n.isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await LanSyncService.lanAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _address = addresses.contains(_address)
            ? _address
            : addresses.firstOrNull;
      });
    } catch (_) {
      // The refresh action lets users retry after joining Wi-Fi.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '操作未完成，请检查连接或输入后重试。',
              'Could not complete the action. Check your connection or input and retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _input(
    String title,
    String initial, {
    bool secret = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(context.l10n.confirm),
            ),
          ],
        );
      },
    );
    // The route's exit animation may still be using the controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<void> _scan(LanSyncService sync) async {
    final link = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _PairScanner()),
    );
    if (link != null && mounted) await _run(() => sync.pair(link));
  }

  String _status(LanSyncService sync) {
    if (sync.isConnected) return t('已连接，实时同步中', 'Connected · syncing live');
    return switch (sync.status) {
      'hosting' => t('主机已启动，等待手机连接', 'Host running · waiting for phone'),
      'connecting' => t('正在连接 Windows', 'Connecting to Windows'),
      'approval' => t('请在 Windows 上确认配对', 'Approve pairing on Windows'),
      'waiting' => t(
        '连接已暂停或断开，将自动重连',
        'Paused or disconnected · reconnects automatically',
      ),
      'error' => t('同步暂不可用', 'Sync unavailable'),
      _ => t('同步未开启', 'Sync is off'),
    };
  }

  String _error(String code) => switch (code) {
    'vault' => t(
      '无法读取加密存储，原有数据已保留。请重试。',
      'Cannot read encrypted storage. Existing data is preserved. Please retry.',
    ),
    'host' => t(
      '无法启动主机，端口可能被占用。关闭占用 45873 端口的程序后重试。',
      'Cannot start host. Port 45873 may be in use. Free the port and retry.',
    ),
    'auth' => t(
      '配对已失效或设备授权已撤销，请重新扫码。',
      'Pairing expired or access was revoked. Scan a new code.',
    ),
    'rejected' => t(
      'Windows 已拒绝配对或撤销授权，请重新扫码。',
      'Windows rejected pairing or revoked access. Scan a new code.',
    ),
    'data' => t(
      '同步数据未能保存，请检查设备剩余空间后重连。',
      'Could not save sync data. Check free storage and reconnect.',
    ),
    _ => t(
      '无法连接主机。请检查同一局域网、Windows 应用是否打开，以及防火墙是否允许 TCP 45873。',
      'Cannot reach host. Check the LAN, keep Windows app open, and allow TCP 45873 through the firewall.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<LanSyncService>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t('局域网同步', 'LAN sync'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t(
                  'Windows 和 Android 连接同一局域网即可同步。',
                  'Connect Windows and Android to the same local network.',
                ),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  '同步站点及登录信息、收藏、黑名单、搜索历史和设置。已下载的图片/视频、缓存和下载目录保留在各自设备。',
                  'Sync sites and logins, favorites, blacklists, search history and settings. Downloaded images/videos, caches and download folders stay on each device.',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    sync.isConnected ? Icons.sync : Icons.sync_disabled,
                  ),
                  title: Text(_status(sync)),
                  subtitle: sync.connectedDevices.isNotEmpty
                      ? Text(sync.connectedDevices.join(', '))
                      : null,
                  trailing: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              if (sync.error != null) ...[
                Text(
                  _error(sync.error!),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run(sync.resumeSavedMode),
                  child: Text(context.l10n.retry),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('本设备名称', 'Device name')),
                subtitle: Text(sync.deviceName),
                trailing: const Icon(Icons.edit),
                onTap: _busy
                    ? null
                    : () async {
                        final name = await _input(
                          t('本设备名称', 'Device name'),
                          sync.deviceName,
                        );
                        if (name != null && mounted) {
                          await _run(() => sync.setDeviceName(name));
                        }
                      },
              ),
              if (Platform.isWindows) ..._hostControls(sync),
              if (Platform.isAndroid) ..._clientControls(sync),
              const SizedBox(height: 16),
              Text(
                t(
                  '首次配对会合并两端已有数据。同一项同时修改时，以较新的修改为准；删除也会同步。登录凭据通过加密连接传输，并在本机加密保存。',
                  'First pairing merges existing data. Newer edits win conflicts on the same item; deletions also sync. Login credentials travel over an encrypted connection and are encrypted locally.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  '同步时请保持 Windows 应用打开。Android 在前台实时同步，回到前台或断线重连后自动补齐离线修改。更换局域网地址后，可在手机上修改主机 IP。',
                  'Keep the Windows app open. Android syncs live in the foreground and catches up on resume or reconnection. If the host IP changes, update it on the phone.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _hostControls(LanSyncService sync) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(t('作为 Windows 同步主机', 'Windows sync host')),
      subtitle: Text(
        t('手机扫码后，在此确认配对', 'Scan with your phone, then approve here'),
      ),
      value: sync.isHosting,
      onChanged: _busy
          ? null
          : (value) => _run(value ? sync.startHost : sync.stop),
    ),
    if (sync.isHosting) ...[
      if (_addresses.isEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            t(
              '未找到局域网地址，请连接网络后刷新',
              'No LAN address found. Connect to a network and refresh.',
            ),
          ),
          trailing: IconButton(
            onPressed: _loadAddresses,
            icon: const Icon(Icons.refresh),
          ),
        ),
      if (_addresses.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _address,
                key: ValueKey(_address),
                decoration: InputDecoration(
                  labelText: t('主机局域网地址', 'Host LAN address'),
                ),
                items: _addresses
                    .map(
                      (address) => DropdownMenuItem(
                        value: address,
                        child: Text('$address:${sync.port}'),
                      ),
                    )
                    .toList(),
                onChanged: (address) => setState(() => _address = address),
              ),
            ),
            IconButton(
              onPressed: _loadAddresses,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      if (_address != null && sync.pairingLink(_address!).isNotEmpty) ...[
        const SizedBox(height: 12),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: sync.pairingLink(_address!),
                size: min(280, constraints.maxWidth - 24),
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            '二维码 5 分钟内有效，配对成功后会自动更换。请仅向自己的设备展示。',
            'Code expires in 5 minutes and rotates after pairing. Show it only to your own devices.',
          ),
          textAlign: TextAlign.center,
        ),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(t('复制配对链接', 'Copy pairing link')),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: sync.pairingLink(_address!)),
              );
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
              }
            },
          ),
        ),
      ],
      Center(
        child: TextButton.icon(
          onPressed: _busy ? null : sync.newInvitation,
          icon: const Icon(Icons.refresh),
          label: Text(t('刷新配对二维码', 'Refresh pairing code')),
        ),
      ),
      for (final request in sync.pending.toList())
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    '设备请求配对：${request.name}',
                    'Pairing request: ${request.name}',
                  ),
                ),
                Text(
                  t(
                    '请确认这是你刚扫码的设备；允许后会共享登录信息。',
                    'Approve only the device you just scanned with. This shares login credentials.',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => sync.reject(request)),
                      child: Text(t('拒绝', 'Reject')),
                    ),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => sync.approve(request)),
                      child: Text(t('允许配对', 'Approve')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
    if (sync.trustedDevices.isNotEmpty) ...[
      const Divider(),
      Text(t('已授权设备', 'Trusted devices')),
      for (final entry in sync.trustedDevices.entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_android),
          title: Text(entry.value),
          trailing: TextButton(
            onPressed: _busy ? null : () => _run(() => sync.revoke(entry.key)),
            child: Text(t('撤销授权', 'Revoke')),
          ),
        ),
    ],
  ];

  List<Widget> _clientControls(LanSyncService sync) => [
    FilledButton.icon(
      onPressed: _busy ? null : () => _scan(sync),
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(t('扫描 Windows 配对二维码', 'Scan Windows pairing code')),
    ),
    TextButton(
      onPressed: _busy
          ? null
          : () async {
              final link = await _input(
                t('粘贴 Windows 配对链接', 'Paste Windows pairing link'),
                '',
                secret: true,
              );
              if (link != null && mounted) await _run(() => sync.pair(link));
            },
      child: Text(t('使用配对链接', 'Use pairing link')),
    ),
    if (sync.hostAddress != null) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('Windows 主机', 'Windows host')),
        subtitle: Text(sync.hostAddress!),
        trailing: const Icon(Icons.edit),
        onTap: _busy
            ? null
            : () async {
                final address = await _input(
                  t('主机局域网 IP', 'Host LAN IP'),
                  sync.hostAddress!,
                );
                if (address != null && mounted) {
                  await _run(() => sync.updateHostAddress(address));
                }
              },
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _run(sync.reconnect),
            child: Text(t('立即重连', 'Reconnect')),
          ),
          TextButton(
            onPressed: _busy ? null : () => _run(sync.forgetHost),
            child: Text(t('解除配对', 'Unpair')),
          ),
        ],
      ),
    ],
  ];
}

class _PairScanner extends StatefulWidget {
  const _PairScanner();
  @override
  State<_PairScanner> createState() => _PairScannerState();
}

class _PairScannerState extends State<_PairScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.isZh ? '扫描配对二维码' : 'Scan pairing code'),
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_handled) return;
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value == null) continue;
              try {
                LanSyncService.parsePairingLink(value);
                _handled = true;
                Navigator.pop(context, value);
                return;
              } catch (_) {
                if (!_invalid) setState(() => _invalid = true);
              }
            }
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.isZh
                    ? '无法打开摄像头。请在系统设置中允许相机权限，或返回使用配对链接。'
                    : 'Camera unavailable. Allow camera access in system settings, or go back and use a pairing link.',
              ),
            ),
          ),
        ),
        if (_invalid)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.isZh
                      ? '这不是有效的配对码，请扫描 Windows 同步页的二维码。'
                      : 'Invalid pairing code. Scan the code on the Windows sync page.',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
