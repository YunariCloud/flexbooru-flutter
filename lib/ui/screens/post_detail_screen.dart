import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/file_downloader.dart';
import '../../models/booru_site.dart';
import '../../models/post.dart';
import '../../providers/favorites_provider.dart';
import '../../services/booru_service.dart';
import '../widgets/tag_chip.dart';

class PostDetailScreen extends StatefulWidget {
  final Post initialPost;
  final BooruSite site;

  const PostDetailScreen({
    super.key,
    required this.initialPost,
    required this.site,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _loadOriginal = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
  }

  void _downloadImage() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    final targetUrl = _post.originUrl.isNotEmpty
        ? _post.originUrl
        : _post.sampleUrl;

    try {
      final savedPath = await FileDownloader.downloadFile(
        fileUrl: targetUrl,
        host: widget.site.host,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedTo(savedPath ?? '')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
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
          _isDownloading = false;
        });
      }
    }
  }

  void _sharePost() {
    final postUrl = '${widget.site.websiteUrl}/posts/${_post.id}';
    final imgUrl = _post.originUrl.isNotEmpty
        ? _post.originUrl
        : _post.sampleUrl;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Check out this artwork (#${_post.id}) on ${widget.site.name}: $imgUrl\n$postUrl',
      ),
    );
  }

  void _openSauceNao() async {
    final imgUrl = _post.sampleUrl.isNotEmpty
        ? _post.sampleUrl
        : _post.previewUrl;
    final sauceUrl = Uri.parse(
      'https://saucenao.com/search.php?url=${Uri.encodeComponent(imgUrl)}',
    );
    if (await canLaunchUrl(sauceUrl)) {
      await launchUrl(sauceUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showInfoSheet() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
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
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.postDetailsTitle(_post.id),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info grid cards
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            l10n.dimensions,
                            '${_post.width} × ${_post.height}',
                          ),
                          const Divider(height: 12),
                          _buildInfoRow(l10n.rating, _post.ratingDisplay),
                          const Divider(height: 12),
                          _buildInfoRow(l10n.score, '${_post.score}'),
                          if (_post.uploader.isNotEmpty) ...[
                            const Divider(height: 12),
                            _buildInfoRow(l10n.uploader, _post.uploader),
                          ],
                          if (_post.source != null &&
                              _post.source!.isNotEmpty) ...[
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.source,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                Flexible(
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontSize: 13,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
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
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(l10n.copyAll),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _post.tagString),
                          );
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    children: _post.tags.map((t) => TagChip(tag: t)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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
              future: BooruService().getComments(
                site: widget.site,
                postId: _post.id,
              ),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favProv = context.watch<FavoritesProvider>();
    final isFav = favProv.isFavorite(_post.id, widget.site.id);
    final headers = ApiClient.getImageHeaders(host: widget.site.host);

    final imageUrl = _loadOriginal && _post.originUrl.isNotEmpty
        ? _post.originUrl
        : (_post.sampleUrl.isNotEmpty ? _post.sampleUrl : _post.originUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        title: Text(
          '#${_post.id} (${widget.site.name})',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // Original / Sample resolution switcher
          if (_post.originUrl.isNotEmpty && _post.originUrl != _post.sampleUrl)
            TextButton(
              onPressed: () {
                setState(() => _loadOriginal = !_loadOriginal);
              },
              child: Text(
                _loadOriginal ? l10n.original : l10n.sample,
                style: TextStyle(
                  color: _loadOriginal ? Colors.amber : Colors.white70,
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
            onPressed: _openSauceNao,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(
              imageUrl,
              headers: headers,
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.5,
            loadingBuilder: (context, event) {
              return Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: event == null || event.expectedTotalBytes == null
                        ? null
                        : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 56,
                      color: Colors.white60,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.failedToLoadFullImage,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            },
          ),

          // Download progress indicator overlay
          if (_isDownloading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 70,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _downloadProgress > 0
                              ? _downloadProgress
                              : null,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${l10n.downloading} ${(_downloadProgress * 100).toInt()}%...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: l10n.postDetailsTitle(_post.id),
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: _showInfoSheet,
              ),
              IconButton(
                tooltip: l10n.commentsCount(0),
                icon: const Icon(Icons.comment_outlined, color: Colors.white),
                onPressed: _showCommentsSheet,
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
    );
  }
}
