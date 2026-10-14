import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/app_update_manager.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.updateInfo, this.manager});
  final UpdateInfo updateInfo;
  final AppUpdateManager? manager;
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  AppUpdateManager get manager => widget.manager ?? AppUpdateManager.instance;
  String? _installMessage;
  bool _opening = false;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _installMessage = null;
    });
    try {
      final result = await manager.openDownloadedPackage();
      if (mounted && result == 'permission') {
        setState(() => _installMessage = context.l10n.allowUpdateInstall);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _installMessage = context.l10n.updateOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: manager,
    builder: (context, _) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      final info = widget.updateInfo;
      final matches =
          manager.info?.downloadUrl == info.downloadUrl &&
          manager.info?.tagName == info.tagName;
      final state = matches ? manager.state : UpdateDownloadState.idle;
      final active = matches && manager.busy;
      final compatible = info.downloadUrl != null && info.assetName != null;
      final ready = state == UpdateDownloadState.ready;
      final failed = state == UpdateDownloadState.failed;
      final status = switch (state) {
        UpdateDownloadState.downloading => l10n.downloadingUpdate,
        UpdateDownloadState.verifying => l10n.verifyingUpdate,
        UpdateDownloadState.ready => l10n.updateReady,
        UpdateDownloadState.cancelled => l10n.updateCancelled,
        UpdateDownloadState.failed =>
          manager.error == 'integrity'
              ? l10n.updateIntegrityFailed
              : l10n.updateDownloadFailed,
        _ =>
          compatible
              ? ''
              : info.assetLookupFailed
              ? l10n.updateAssetLookupFailed
              : l10n.noCompatibleUpdate,
      };
      return AlertDialog(
        title: Text(l10n.newVersionAvailable),
        content: SizedBox(
          width: 450,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.currentVersion}: v${info.currentVersion}'),
                  Text(
                    '${l10n.latestVersion}: v${info.latestVersion}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (info.assetName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        info.assetName!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (info.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(l10n.updateNotes, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    SelectableText(
                      info.releaseNotes,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      status,
                      style: TextStyle(
                        color: failed ? theme.colorScheme.error : null,
                      ),
                    ),
                  ],
                  if (active) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: state == UpdateDownloadState.downloading
                          ? manager.progress
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(manager.received / 1048576).toStringAsFixed(1)} MB'
                      '${manager.total > 0 ? ' / ${(manager.total / 1048576).toStringAsFixed(1)} MB' : ''}'
                      '${manager.progress != null ? ' (${(manager.progress! * 100).toStringAsFixed(0)}%)' : ''}',
                    ),
                  ],
                  if (ready && manager.platform == 'windows') ...[
                    const SizedBox(height: 12),
                    Text(l10n.windowsUpdateInstructions),
                  ],
                  if (_installMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_installMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
          if (active)
            TextButton(onPressed: manager.cancel, child: Text(l10n.cancel)),
          if (compatible && !active)
            FilledButton.icon(
              icon: Icon(ready ? Icons.install_mobile : Icons.download),
              label: Text(
                ready
                    ? (manager.platform == 'android'
                          ? l10n.installUpdate
                          : l10n.openUpdatePackage)
                    : failed || state == UpdateDownloadState.cancelled
                    ? l10n.retry
                    : l10n.downloadUpdate,
              ),
              onPressed: manager.busy || _opening
                  ? null
                  : () async {
                      if (ready) {
                        await _open();
                      } else {
                        await manager.download(info);
                      }
                    },
            ),
          if (!compatible)
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.openReleasesPage),
              onPressed: () => launchUrl(
                Uri.parse(info.releaseUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      );
    },
  );
}

class UpdateCheckHelper {
  static Future<void> checkUpdate(
    BuildContext context, {
    bool silentIfLatest = false,
    UpdateService? service,
    AppUpdateManager? updateManager,
  }) async {
    final l10n = context.l10n;
    final manager = updateManager ?? AppUpdateManager.instance;
    if (manager.info != null &&
        (manager.busy || manager.state == UpdateDownloadState.ready)) {
      showDialog(
        context: context,
        builder: (_) =>
            UpdateDialog(updateInfo: manager.info!, manager: manager),
      );
      return;
    }

    // Show loading if interactive
    BuildContext? dialogContext;
    if (!silentIfLatest) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.checkingUpdates)),
              ],
            ),
          );
        },
      );
    }

    try {
      final info = await (service ?? UpdateService()).checkUpdate();

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (!context.mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (_) => UpdateDialog(updateInfo: info, manager: manager),
        );
      } else if (!silentIfLatest) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 10),
                Text(
                  l10n.appName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.alreadyLatestVersion),
                const SizedBox(height: 8),
                Text(
                  '${l10n.currentVersion}: v${info.currentVersion}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (!context.mounted || silentIfLatest) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                l10n.checkUpdateFailed,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.isZh
                    ? '你可以直接前往 GitHub Releases 页面查看或手动下载最新版本。'
                    : 'You can visit the GitHub Releases page to download updates manually.',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l10n.openReleasesPage),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse(AppConstants.githubReleasesUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
    }
  }
}
