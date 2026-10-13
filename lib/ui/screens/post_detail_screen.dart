import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/file_downloader.dart';
import '../../models/booru_site.dart';
import '../../models/post.dart';
import '../../models/tag.dart';
import '../../providers/favorites_provider.dart';
import '../../models/browse_session.dart';
import '../widgets/reverse_image_search_sheet.dart';
import 'search_screen.dart';
import '../../providers/settings_provider.dart';
import '../../services/booru_service.dart';
import '../../services/tag_translation_service.dart';
import '../widgets/tag_chip.dart';
import '../widgets/post_image_viewer.dart';

class PostDetailScreen extends StatefulWidget {
  final Post initialPost;
  final BooruSite site;
  final BrowseSource? source;
  final Future<String?> Function(Post, BooruSite, void Function(int, int))?
  downloader;

  const PostDetailScreen({
    super.key,
    required this.initialPost,
    required this.site,
    this.source,
    this.downloader,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  bool get _isDownloading =>
      _downloads.contains('${_post.booruId}:${_post.id}');
  final Set<String> _downloads = {};
  bool _fullscreen = false;
  int _index = 0;
  late final PageController _pages;
  BooruSite get _site {
    if (widget.source == null) return widget.site;
    return widget.source!.entries[_index].site ??
        BooruSite(
          id: _post.booruId,
          name: context.l10n.isZh ? '已删除的站点' : 'Removed site',
          host: Uri.tryParse(_post.sampleUrl)?.host ?? '',
          type: -1,
        );
  }

  bool get _siteMissing =>
      widget.source != null && widget.source!.entries[_index].site == null;
  final Map<String, double> _downloadValues = {};
  final _downloadProgress = ValueNotifier<double>(0);
  late String _imageQuality;
  String? _tagLanguageOverride;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _index =
        widget.source?.entries.indexWhere(
          (e) => e.identity == '${_post.booruId}:${_post.id}',
        ) ??
        0;
    if (_index < 0) _index = 0;
    _pages = PageController(initialPage: _index);
    widget.source?.addListener(_galleryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefetch();
    });
    _imageQuality = context.read<SettingsProvider>().imageQuality;
    _enrichPostTags();
  }

  @override
  void dispose() {
    widget.source?.removeListener(_galleryChanged);
    widget.source?.dispose();
    _pages.dispose();
    _downloadProgress.dispose();
    super.dispose();
  }

  void _enrichPostTags() async {
    final identity = '${_post.booruId}:${_post.id}';
    await TagTranslationService().init();
    if (mounted && identity == '${_post.booruId}:${_post.id}') {
      final enriched = TagTranslationService().enrichTags(_post.tags);
      setState(() {
        _post = _post.copyWith(tags: enriched);
      });
    }
  }

  void _downloadImage() async {
    if (_isDownloading) return;
    setState(() {
      _downloads.add('${_post.booruId}:${_post.id}');
      _downloadValues['${_post.booruId}:${_post.id}'] = 0;
      _downloadProgress.value = 0;
    });

    final downloadPost = _post;
    final downloadSite = _site;
    final downloadIdentity = '${downloadPost.booruId}:${downloadPost.id}';
    final targetUrl = _post.originUrl.isNotEmpty
        ? _post.originUrl
        : _post.sampleUrl;

    try {
      final settingsProv = context.read<SettingsProvider>();
      void progress(int received, int total) {
        if (mounted && total > 0) {
          _downloadValues[downloadIdentity] = received / total;
          if ('${_post.booruId}:${_post.id}' == downloadIdentity) {
            _downloadProgress.value = received / total;
          }
        }
      }

      final savedPath = widget.downloader != null
          ? await widget.downloader!(downloadPost, downloadSite, progress)
          : await FileDownloader.downloadFile(
              fileUrl: targetUrl,
              host: downloadSite.host,
              siteId: downloadPost.booruId,
              postId: downloadPost.id,
              customSavePath: settingsProv.downloadPath.isNotEmpty
                  ? settingsProv.downloadPath
                  : null,
              onProgress: progress,
            );

      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedTo(savedPath ?? '')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action:
                (savedPath != null &&
                    (Platform.isWindows ||
                        Platform.isMacOS ||
                        Platform.isLinux))
                ? SnackBarAction(
                    label: l10n.openFolder,
                    textColor: Colors.white,
                    onPressed: () {
                      final dir = File(savedPath).parent.path;
                      FileDownloader.openDirectory(dir);
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadFailed}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloads.remove(downloadIdentity);
          _downloadValues.remove(downloadIdentity);
        });
      }
    }
  }

  void _sharePost() {
    final postUrl = '${_site.websiteUrl}/posts/${_post.id}';
    final imgUrl = _post.originUrl.isNotEmpty
        ? _post.originUrl
        : _post.sampleUrl;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Check out this artwork (#${_post.id}) on ${_site.name}: $imgUrl\n$postUrl',
      ),
    );
  }

  void _galleryChanged() {
    if (mounted) setState(() {});
  }

  void _prefetch() {
    final source = widget.source;
    if (source != null &&
        _index >= source.entries.length - 3 &&
        source.error == null) {
      source.loadNext();
    }
  }

  void _changeImage(int index) {
    if (index < 0 || index >= (widget.source?.entries.length ?? 1)) return;
    setState(() {
      _index = index;
      _post = widget.source!.entries[index].post;
      _downloadProgress.value =
          _downloadValues['${_post.booruId}:${_post.id}'] ?? 0;
    });
    _enrichPostTags();
    _prefetch();
  }

  Future<void> _step(int delta) async {
    final source = widget.source;
    if (source == null) return;
    var next = _index + delta;
    if (next >= source.entries.length && source.hasMore) {
      await source.loadNext();
    }
    if (!mounted) return;
    if (next >= 0 && next < source.entries.length) {
      await _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _searchTag(Tag tag) {
    if (_siteMissing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isZh ? '原站点已删除，无法搜索' : 'The original site was removed',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          site: _site,
          initialQuery: tag.name,
          executeInitially: true,
          safeMode: widget.source?.safeMode,
        ),
      ),
    );
  }

  String _formatAspectRatio(int w, int h) {
    if (w <= 0 || h <= 0) return '';
    final ratio = w / h;
    if ((ratio - 16 / 9).abs() < 0.05) return '16:9';
    if ((ratio - 9 / 16).abs() < 0.05) return '9:16';
    if ((ratio - 4 / 3).abs() < 0.05) return '4:3';
    if ((ratio - 3 / 4).abs() < 0.05) return '3:4';
    if ((ratio - 1.0).abs() < 0.05) return '1:1';
    if ((ratio - 21 / 9).abs() < 0.05) return '21:9';
    return ratio.toStringAsFixed(2);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  String _getFileFormat(String sampleUrl, String originUrl) {
    final target = originUrl.isNotEmpty ? originUrl : sampleUrl;
    try {
      final uri = Uri.parse(target);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.contains('.')) {
        final ext = last.split('.').last.toUpperCase();
        if (ext.length <= 5 && !ext.contains('?')) return ext;
      }
    } catch (_) {}
    return 'IMAGE';
  }

  void _showTagActionsSheet(Tag tag, String effectiveLang) {
    final l10n = context.l10n;
    final isZh = effectiveLang == 'zh';
    final hasCn =
        tag.translatedName != null &&
        tag.translatedName!.isNotEmpty &&
        tag.translatedName != tag.name;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tag.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (isZh && hasCn) ? tag.translatedName! : tag.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasCn && isZh)
                            Text(
                              tag.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else if (hasCn && !isZh)
                            Text(
                              tag.translatedName!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tag.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tag.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isZh
                            ? TagCategory.getCategoryNameZh(tag.category)
                            : tag.categoryName,
                        style: TextStyle(
                          color: tag.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(l10n.searchTag),
                  subtitle: Text(tag.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    _searchTag(tag);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(l10n.copyTag),
                  subtitle: Text(tag.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: tag.name));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.copiedTag(tag.name))),
                    );
                  },
                ),
                if (hasCn)
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(l10n.copyTagZh),
                    subtitle: Text(tag.translatedName!),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(
                        ClipboardData(text: tag.translatedName!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.copiedTag(tag.translatedName!)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInfoSheet() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settingsProv = context.read<SettingsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final effectiveLang =
                _tagLanguageOverride ?? settingsProv.effectiveTagLanguage;
            final isZh = effectiveLang == 'zh';

            final groupedTags = <int, List<Tag>>{};
            for (final tag in _post.tags) {
              groupedTags.putIfAbsent(tag.category, () => []).add(tag);
            }
            final categoryOrder = [
              TagCategory.artist,
              TagCategory.character,
              TagCategory.copyright,
              TagCategory.general,
              TagCategory.meta,
              5,
              TagCategory.studio,
              TagCategory.circle,
              TagCategory.faults,
            ];

            final ratio = _formatAspectRatio(_post.width, _post.height);
            final format = _getFileFormat(_post.sampleUrl, _post.originUrl);
            final sizeText = _formatFileSize(_post.fileSize);
            final postWebUrl = '${_site.websiteUrl}/posts/${_post.id}';

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header Row
                      Row(
                        children: [
                          Text(
                            '#${_post.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _site.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.open_in_browser, size: 20),
                            tooltip: l10n.openInBrowser,
                            onPressed: () async {
                              final uri = Uri.tryParse(postWebUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.link, size: 20),
                            tooltip: l10n.copyPostUrl,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: postWebUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.copiedPostUrl)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stat Metrics Grid Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    icon: Icons.aspect_ratio,
                                    label: l10n.dimensions,
                                    value: '${_post.width} × ${_post.height}',
                                    extra: ratio.isNotEmpty ? '($ratio)' : null,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    icon: Icons.shield_outlined,
                                    label: l10n.rating,
                                    value: _post.ratingDisplay,
                                    valueColor: _post.ratingColor,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    icon: Icons.thumb_up_alt_outlined,
                                    label: l10n.score,
                                    value: '${_post.score}',
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    context,
                                    icon: Icons.insert_drive_file_outlined,
                                    label: l10n.format,
                                    value: format,
                                    extra: sizeText.isNotEmpty
                                        ? '($sizeText)'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Detailed metadata container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (_post.uploader.isNotEmpty) ...[
                              _buildDetailRow(
                                icon: Icons.person_outline,
                                label: l10n.uploader,
                                child: Text(
                                  _post.uploader,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            if (_post.source != null &&
                                _post.source!.isNotEmpty) ...[
                              if (_post.uploader.isNotEmpty)
                                const Divider(height: 14),
                              _buildDetailRow(
                                icon: Icons.link,
                                label: l10n.source,
                                child: InkWell(
                                  onTap: () async {
                                    final uri = Uri.tryParse(_post.source!);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  child: Text(
                                    _post.source!,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_post.createdAt != null) ...[
                              if (_post.uploader.isNotEmpty ||
                                  (_post.source != null &&
                                      _post.source!.isNotEmpty))
                                const Divider(height: 14),
                              _buildDetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: '日期',
                                child: Text(
                                  _post.createdAt!
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags Toolbar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.tagsCount(_post.tags.length),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              ActionChip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.translate, size: 14),
                                label: Text(
                                  isZh ? '中' : 'EN',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  setSheetState(() {
                                    _tagLanguageOverride = isZh ? 'en' : 'zh';
                                  });
                                  setState(() {});
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.copy, size: 14),
                                label: Text(
                                  l10n.copyAll,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _post.tagString),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.copied)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Grouped Category Tags
                      ...categoryOrder
                          .where(
                            (c) =>
                                groupedTags.containsKey(c) &&
                                groupedTags[c]!.isNotEmpty,
                          )
                          .map((cat) {
                            final catTags = groupedTags[cat]!;
                            final catName = isZh
                                ? TagCategory.getCategoryNameZh(cat)
                                : TagCategory.getCategoryName(cat);
                            final catColor = catTags.first.color;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: catColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$catName (${catTags.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: catColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: catTags.map((t) {
                                      return TagChip(
                                        tag: t,
                                        tagLanguage: effectiveLang,
                                        onTap: () => _searchTag(t),
                                        onLongPress: () => _showTagActionsSheet(
                                          t,
                                          effectiveLang,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }),

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCommentsSheet() async {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder(
              future: BooruService().getComments(site: _site, postId: _post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.commentsCount(comments.length),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: comments.isEmpty
                            ? Center(child: Text(l10n.noCommentsYet))
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: comments.length,
                                separatorBuilder: (ctx, idx) => const Divider(),
                                itemBuilder: (context, index) {
                                  final c = comments[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      child: Text(
                                        c.author.isNotEmpty
                                            ? c.author[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    title: Text(
                                      c.author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(c.body),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? extra,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: valueColor ?? theme.colorScheme.onSurface,
                      ),
                    ),
                    if (extra != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        extra,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favProv = context.watch<FavoritesProvider>();
    final isFav = favProv.isFavorite(_post.id, _post.booruId);
    final headers = ApiClient.getImageHeaders(host: _site.host);

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) setState(() => _fullscreen = false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                title: Text(
                  '#${_post.id} (${_site.name})',
                  style: const TextStyle(fontSize: 16),
                ),
                actions: [
                  // Original / Sample resolution switcher
                  if (_post.originUrl.isNotEmpty &&
                      _post.originUrl != _post.sampleUrl)
                    TextButton(
                      onPressed: () {
                        setState(
                          () => _imageQuality = _imageQuality == 'original'
                              ? 'sample'
                              : 'original',
                        );
                      },
                      child: Text(
                        switch (_imageQuality) {
                          'original' => l10n.original,
                          'preview' => l10n.qualityPreview,
                          _ => l10n.sample,
                        },
                        style: TextStyle(
                          color: _imageQuality == 'original'
                              ? Colors.amber
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: l10n.share,
                    icon: const Icon(Icons.share),
                    onPressed: _sharePost,
                  ),
                  IconButton(
                    tooltip: l10n.reverseSearch,
                    icon: const Icon(Icons.travel_explore),
                    onPressed: () => showReverseImageSearch(context, _post),
                  ),
                ],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _step(1);
                  return KeyEventResult.handled;
                }
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _step(-1);
                  return KeyEventResult.handled;
                }
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape &&
                    _fullscreen) {
                  setState(() => _fullscreen = false);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: widget.source == null
                  ? PostImageViewer(
                      post: _post,
                      quality: _imageQuality,
                      headers: headers,
                      onTap: () => setState(() => _fullscreen = !_fullscreen),
                    )
                  : PostGalleryViewer(
                      source: widget.source!,
                      controller: _pages,
                      index: _index,
                      quality: _imageQuality,
                      onChanged: _changeImage,
                      onTap: () => setState(() => _fullscreen = !_fullscreen),
                    ),
            ),
            if (widget.source != null && !_fullscreen) ...[
              Positioned(
                left: 8,
                top: MediaQuery.sizeOf(context).height * .35,
                child: IconButton.filledTonal(
                  tooltip: context.l10n.isZh ? '上一张' : 'Previous image',
                  onPressed: _index > 0 ? () => _step(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Positioned(
                right: 8,
                top: MediaQuery.sizeOf(context).height * .35,
                child: IconButton.filledTonal(
                  tooltip: context.l10n.isZh ? '下一张' : 'Next image',
                  onPressed:
                      _index < widget.source!.entries.length - 1 ||
                          widget.source!.hasMore
                      ? () => _step(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_index + 1} / ${widget.source!.entries.length}${widget.source!.hasMore ? ' +' : ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (widget.source!.loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (widget.source!.error != null)
                        TextButton(
                          onPressed: () => widget.source!.loadNext(),
                          child: Text(l10n.retry),
                        ),
                      if (_siteMissing)
                        Text(
                          l10n.isZh ? '原站点已删除' : 'Original site removed',
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (_isDownloading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 70,
                child: DownloadProgressOverlay(progress: _downloadProgress),
              ),
          ],
        ),
        bottomNavigationBar: _fullscreen
            ? null
            : Container(
                color: Colors.black.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        tooltip: l10n.postDetailsTitle(_post.id),
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                        onPressed: _showInfoSheet,
                      ),
                      IconButton(
                        tooltip: l10n.commentsCount(0),
                        icon: const Icon(
                          Icons.comment_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _siteMissing ? null : _showCommentsSheet,
                      ),
                      IconButton(
                        tooltip: isFav ? l10n.removeFavorite : l10n.addFavorite,
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () {
                          favProv.toggleFavorite(_post);
                        },
                      ),
                      IconButton(
                        tooltip: l10n.download,
                        icon: Icon(
                          _isDownloading ? Icons.downloading : Icons.download,
                          color: Colors.white,
                        ),
                        onPressed: _downloadImage,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
