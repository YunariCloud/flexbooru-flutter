class UrlUtil {
  /// Fixes protocol-relative URLs (e.g., `//assets.yande.re/...`) and ensures valid HTTP/HTTPS URLs.
  static String normalizeUrl(
    String? url, {
    String defaultScheme = 'https',
    String? host,
  }) {
    if (url == null || url.trim().isEmpty) return '';
    var trimmed = url.trim();

    if (trimmed.startsWith('//')) {
      return '$defaultScheme:$trimmed';
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (host != null && host.isNotEmpty) {
        if (!trimmed.startsWith('/')) {
          trimmed = '/$trimmed';
        }
        return '$defaultScheme://$host$trimmed';
      }
      return '$defaultScheme://$trimmed';
    }

    return trimmed;
  }

  /// Checks if a file URL is a video format (webm, mp4, etc.)
  static bool isVideo(String? url) {
    if (url == null) return false;
    final lower = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv');
  }

  /// Checks if a file URL is an animated gif
  static bool isGif(String? url) {
    if (url == null) return false;
    return (Uri.tryParse(url)?.path ?? url).toLowerCase().endsWith('.gif');
  }

  /// Extracts file extension from URL
  static String getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot + 1).toLowerCase();
      }
    } catch (_) {}
    return 'jpg';
  }

  /// Extracts filename from URL
  static String getFileName(String url, {String fallback = 'image'}) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {}
    return '$fallback.${getFileExtension(url)}';
  }
}
