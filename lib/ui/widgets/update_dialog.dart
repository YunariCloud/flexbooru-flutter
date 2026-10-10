import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.newVersionAvailable,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350, maxWidth: 450),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.currentVersion}: v${updateInfo.currentVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 14),
                    Text(
                      '${l10n.latestVersion}: v${updateInfo.latestVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (updateInfo.title.isNotEmpty &&
                  updateInfo.title != 'v${updateInfo.latestVersion}')
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    updateInfo.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                Text(
                  l10n.updateNotes,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SelectableText(
                    updateInfo.releaseNotes,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.later),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l10n.viewUpdate),
          onPressed: () async {
            Navigator.of(context).pop();
            final url = updateInfo.downloadUrl ?? updateInfo.releaseUrl;
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

class UpdateCheckHelper {
  static Future<void> checkUpdate(
    BuildContext context, {
    bool silentIfLatest = false,
  }) async {
    final l10n = context.l10n;

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
      final info = await UpdateService().checkUpdate();

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (!context.mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (_) => UpdateDialog(updateInfo: info),
        );
      } else if (!silentIfLatest) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 10),
                Text(
                  l10n.appName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                l10n.checkUpdateFailed,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
