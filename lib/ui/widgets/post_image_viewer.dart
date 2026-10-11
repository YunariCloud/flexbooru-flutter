import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/post.dart';

class PostImageViewer extends StatefulWidget {
  const PostImageViewer({
    super.key,
    required this.post,
    required this.quality,
    required this.headers,
  });
  final Post post;
  final String quality;
  final Map<String, String> headers;

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer> {
  int _retry = 0;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final imageUrl = switch (widget.quality) {
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
