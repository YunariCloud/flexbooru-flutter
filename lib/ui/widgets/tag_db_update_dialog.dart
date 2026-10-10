import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/tag_translation_service.dart';

class TagDbUpdateDialog extends StatelessWidget {
  final TagDbUpdateInfo updateInfo;
  final VoidCallback onConfirmDownload;

  const TagDbUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onConfirmDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final sizeMb = (updateInfo.remoteSize ?? 24547328) / (1024 * 1024);
    final dateStr = updateInfo.remoteDate != null
        ? updateInfo.remoteDate!.substring(0, updateInfo.remoteDate!.length >= 10 ? 10 : updateInfo.remoteDate!.length)
        : '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.menu_book, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              updateInfo.isDownloaded ? l10n.tagDbUpdateFound : l10n.downloadTagDb,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tagDatabase,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '~${sizeMb.toStringAsFixed(1)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '更新日期',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tagDatabaseDesc,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '包含 33万+ Danbooru 标签中英对照、画师/角色/原作智能分类',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: Text(updateInfo.isDownloaded ? '更新词库' : '立即下载'),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmDownload();
          },
        ),
      ],
    );
  }
}

class TagDbUpdateHelper {
  static Future<void> checkAndUpdate(
    BuildContext context, {
    VoidCallback? onUpdated,
  }) async {
    final l10n = context.l10n;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在检查 Danbooru 词库更新...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final info = await TagTranslationService().checkForUpdate();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (dialogCtx) => TagDbUpdateDialog(
            updateInfo: info,
            onConfirmDownload: () {
              _startDownload(context, onUpdated: onUpdated);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.tagDbUpToDate} (${l10n.tagDbTotalTags(info.localTagCount)})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查词库更新失败: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static void _startDownload(
    BuildContext context, {
    VoidCallback? onUpdated,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _DownloadProgressDialog(
        onSuccess: () {
          Navigator.of(dialogCtx).pop();
          onUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.l10n.tagDbUpdatedSuccess} (${context.l10n.tagDbTotalTags(TagTranslationService().getLoadedTagCount())})',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (err) {
          Navigator.of(dialogCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('下载词库失败: $err'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      ),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final ValueChanged<String> onError;

  const _DownloadProgressDialog({
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  int _received = 0;
  int _total = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        _doDownload();
      }
    });
  }

  void _doDownload() async {
    try {
      await TagTranslationService().downloadDatabase(
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
              if (total > 0) {
                _progress = received / total;
              }
            });
          }
        },
      );
      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        widget.onError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mbReceived = (_received / (1024 * 1024)).toStringAsFixed(1);
    final mbTotal = _total > 0 ? (_total / (1024 * 1024)).toStringAsFixed(1) : '~23.4';
    final percent = (_progress * 100).toInt();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.tagDbDownloading,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$mbReceived MB / $mbTotal MB',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
