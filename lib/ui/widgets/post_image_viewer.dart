import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../models/browse_session.dart';
import '../../core/network/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/post.dart';

class PostImageViewer extends StatefulWidget {
  const PostImageViewer({
    super.key,
    required this.post,
    required this.quality,
    required this.headers,
    this.onTap,
  });
  final Post post;
  final String quality;
  final Map<String, String> headers;
  final VoidCallback? onTap;

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer> {
  int _retry = 0;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final imageUrl = post.isVideo
        ? (post.previewUrl.isNotEmpty ? post.previewUrl : post.sampleUrl)
        : switch (widget.quality) {
            'original' when post.originUrl.isNotEmpty => post.originUrl,
            'preview' when post.previewUrl.isNotEmpty => post.previewUrl,
            _ => post.sampleUrl.isNotEmpty ? post.sampleUrl : post.originUrl,
          };
    final l10n = context.l10n;
    return PhotoView(
      key: ValueKey((imageUrl, _retry)),
      imageProvider: CachedNetworkImageProvider(
        imageUrl,
        headers: widget.headers,
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3.5,
      onTapUp: (context, details, value) => widget.onTap?.call(),
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes == null
                ? null
                : event!.cumulativeBytesLoaded / event.expectedTotalBytes!,
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, size: 56, color: Colors.white60),
            const SizedBox(height: 12),
            Text(
              l10n.failedToLoadFullImage,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => _retry++),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class PostGalleryViewer extends StatefulWidget {
  const PostGalleryViewer({
    super.key,
    required this.source,
    required this.controller,
    required this.index,
    required this.quality,
    required this.onChanged,
    required this.onTap,
    this.evictImage,
  });
  final BrowseSource source;
  final PageController controller;
  final int index;
  final String quality;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;
  final Future<void> Function(String, String?)? evictImage;
  @override
  State<PostGalleryViewer> createState() => _PostGalleryViewerState();
}

class _PostGalleryViewerState extends State<PostGalleryViewer> {
  bool _zoomed = false;
  final Map<int, int> _retries = {};
  final Map<int, PhotoViewScaleStateController> _scales = {};
  @override
  void didUpdateWidget(covariant PostGalleryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.quality != widget.quality) {
      _zoomed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final index in _scales.keys.toList()) {
          if ((index - widget.index).abs() > 2) {
            _scales.remove(index)!.dispose();
            _retries.remove(index);
          } else {
            _scales[index]!.scaleState = PhotoViewScaleState.initial;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _scales.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.source,
    builder: (context, _) => PhotoViewGallery.builder(
      pageController: widget.controller,
      itemCount: widget.source.entries.length,
      onPageChanged: widget.onChanged,
      scrollPhysics: _zoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      scaleStateChangedCallback: (state) {
        if (mounted && _zoomed != (state != PhotoViewScaleState.initial)) {
          setState(() => _zoomed = state != PhotoViewScaleState.initial);
        }
      },
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      builder: (context, index) {
        final entry = widget.source.entries[index];
        final post = entry.post;
        final url = post.isVideo
            ? (post.previewUrl.isNotEmpty ? post.previewUrl : post.sampleUrl)
            : switch (widget.quality) {
                'original' when post.originUrl.isNotEmpty => post.originUrl,
                'preview' when post.previewUrl.isNotEmpty => post.previewUrl,
                _ =>
                  post.sampleUrl.isNotEmpty ? post.sampleUrl : post.originUrl,
              };
        final retry = _retries[index] ?? 0;
        final cacheKey = retry == 0 ? null : '$url#flexbooru-retry-$retry';
        return PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(
            url,
            cacheKey: cacheKey,
            headers: ApiClient.getImageHeaders(host: entry.site?.host),
          ),
          scaleStateController: _scales.putIfAbsent(
            index,
            PhotoViewScaleStateController.new,
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.5,
          initialScale: PhotoViewComputedScale.contained,
          onTapUp: (context, details, value) => widget.onTap(),
          errorBuilder: (context, error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                Text(
                  context.l10n.failedToLoadFullImage,
                  style: const TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: () async {
                    if (widget.evictImage != null) {
                      await widget.evictImage!(url, cacheKey);
                    } else {
                      await CachedNetworkImage.evictFromCache(
                        url,
                        cacheKey: cacheKey,
                      );
                    }
                    if (mounted) {
                      setState(() {
                        _retries[index] = retry + 1;
                        _zoomed = false;
                      });
                    }
                  },
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class DownloadProgressOverlay extends StatelessWidget {
  const DownloadProgressOverlay({super.key, required this.progress});
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: progress,
    builder: (context, value, _) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                value: value > 0 ? value : null,
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${context.l10n.downloading} ${(value * 100).toInt()}%...',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
