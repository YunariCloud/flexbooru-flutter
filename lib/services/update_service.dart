import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String tagName;
  final String title;
  final String releaseNotes;
  final String releaseUrl;
  final String? downloadUrl;
  final String? assetName;
  final int? assetSize;
  final String? assetSha256;
  final String? checksumUrl;
  final DateTime? publishedAt;
  final bool hasUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    required this.releaseUrl,
    this.downloadUrl,
    this.assetName,
    this.assetSize,
    this.assetSha256,
    this.checksumUrl,
    this.publishedAt,
    required this.hasUpdate,
  });
}

class UpdateService {
  final Dio? _customDio;
  final String? targetPlatform;

  UpdateService({Dio? dio, this.targetPlatform}) : _customDio = dio;

  Dio get _dio => _customDio ?? ApiClient().dio;

  Future<UpdateInfo> checkUpdate({String? currentVersion}) async {
    final curVer = (currentVersion ?? await installedVersion()).trim();

    try {
      // 1. Try official GitHub Releases API
      final response = await _dio.get(
        AppConstants.githubLatestReleaseApi,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Flexbooru-Flutter-App',
          },
          responseType: ResponseType.plain,
        ),
      );

      final dynamic parsed = jsonDecode(response.data as String);
      if (parsed is! Map<String, dynamic>) {
        throw FormatException('Unexpected response format: ${response.data}');
      }

      final tagName = (parsed['tag_name'] as String? ?? '').trim();
      final title = (parsed['name'] as String? ?? tagName).trim();
      final releaseNotes = (parsed['body'] as String? ?? '').trim();
      final htmlUrl =
          (parsed['html_url'] as String? ?? AppConstants.githubReleasesUrl)
              .trim();
      final publishedAtStr = parsed['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr)
          : null;

      final latestVer = _releaseVersion(tagName);
      final hasUpdate = isNewerVersion(latestVer, curVer);

      // Extract direct asset download URL for Android or Windows
      final assets = parsed['assets'] as List<dynamic>? ?? [];
      final platform =
          targetPlatform ?? (kIsWeb ? 'web' : Platform.operatingSystem);
      final candidates =
          assets
              .whereType<Map>()
              .where(
                (asset) =>
                    assetScore(asset['name'] as String? ?? '', platform) > 0 &&
                    isTrustedAssetUrl(
                      asset['browser_download_url'] as String? ?? '',
                    ),
              )
              .toList()
            ..sort(
              (a, b) => assetScore(
                b['name'] as String,
                platform,
              ).compareTo(assetScore(a['name'] as String, platform)),
            );
      final asset = candidates.firstOrNull;
      final checksums = assets
          .whereType<Map>()
          .where(
            (asset) =>
                (asset['name'] as String? ?? '').toLowerCase() ==
                    '$platform-sha256sums.txt' &&
                isTrustedAssetUrl(
                  asset['browser_download_url'] as String? ?? '',
                ),
          )
          .firstOrNull;
      final digest = asset?['digest'] as String?;

      return UpdateInfo(
        currentVersion: curVer,
        latestVersion: latestVer,
        tagName: tagName,
        title: title.isEmpty ? tagName : title,
        releaseNotes: releaseNotes,
        releaseUrl: htmlUrl,
        downloadUrl: asset?['browser_download_url'] as String?,
        assetName: asset?['name'] as String?,
        assetSize: asset?['size'] as int?,
        assetSha256:
            digest != null &&
                RegExp(r'^sha256:[0-9a-fA-F]{64}$').hasMatch(digest)
            ? digest.substring(7).toLowerCase()
            : null,
        checksumUrl: checksums?['browser_download_url'] as String?,
        publishedAt: publishedAt,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      // 2. Fallback: try checking redirection from latest release page
      try {
        final redirectResp = await _dio.get(
          AppConstants.githubLatestReleasePage,
          options: Options(
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
            headers: {'User-Agent': 'Flexbooru-Flutter-App'},
          ),
        );

        final location = redirectResp.headers.value('location');
        if (location != null &&
            location.startsWith(
              'https://github.com/${AppConstants.githubRepo}/releases/tag/',
            )) {
          final rawTag = Uri.parse(location).pathSegments.last;
          final latestVer = _releaseVersion(rawTag);
          final hasUpdate = isNewerVersion(latestVer, curVer);
          return UpdateInfo(
            currentVersion: curVer,
            latestVersion: latestVer,
            tagName: rawTag,
            title: 'Flexbooru $rawTag',
            releaseNotes: '',
            releaseUrl: location,
            hasUpdate: hasUpdate,
          );
        }
      } catch (_) {
        // Fallback also failed, propagate original error
      }
      rethrow;
    }
  }

  static Future<String> installedVersion() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final version = AppConstants.rawVersion.contains('-')
          ? AppConstants.rawVersion
          : package.version;
      return package.buildNumber.isEmpty
          ? version
          : '$version+${package.buildNumber}';
    } catch (_) {
      return AppConstants.rawVersion;
    }
  }

  static String _releaseVersion(String tag) {
    final version = normalizeVersion(tag);
    if (!RegExp(
      r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+\d+)?$',
    ).hasMatch(version)) {
      throw const FormatException('Invalid release version');
    }
    return version;
  }

  static bool isTrustedAssetUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        uri.path.startsWith('/${AppConstants.githubRepo}/releases/download/');
  }

  static int assetScore(String name, String platform) {
    final lower = name.toLowerCase();
    if (platform == 'android' && lower.endsWith('.apk')) {
      if (lower.contains('universal')) return 100;
      if (RegExp(r'arm64|armeabi|armv7|x86').hasMatch(lower)) return 0;
      return 50;
    }
    if (platform == 'windows' && lower.endsWith('.zip')) {
      if (RegExp(
        r'linux|macos|darwin|source|arm64|aarch64|x86(?!_64)',
      ).hasMatch(lower)) {
        return 0;
      }
      if (lower.contains('windows') &&
          (lower.contains('x64') || lower.contains('amd64'))) {
        return 100;
      }
      if (lower.contains('windows') || lower.contains('win64')) return 75;
      return lower == 'app.zip' || lower == 'flexbooru.zip' ? 25 : 0;
    }
    return 0;
  }

  static String normalizeVersion(String v) {
    var ver = v.trim();
    if (ver.startsWith('v') || ver.startsWith('V')) {
      ver = ver.substring(1);
    }
    return ver;
  }

  /// Compare two semantic version strings.
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, and 0 if equal.
  static int compareVersions(String v1, String v2) {
    final clean1 = normalizeVersion(v1);
    final clean2 = normalizeVersion(v2);

    // Split build number (e.g. 1.0.0+1)
    final parts1 = clean1.split('+');
    final parts2 = clean2.split('+');

    final baseWithPre1 = parts1[0];
    final baseWithPre2 = parts2[0];
    final build1 = parts1.length > 1 ? int.tryParse(parts1[1]) ?? 0 : 0;
    final build2 = parts2.length > 1 ? int.tryParse(parts2[1]) ?? 0 : 0;

    // Split pre-release (e.g. 1.0.0-rc.1)
    final preParts1 = baseWithPre1.split('-');
    final preParts2 = baseWithPre2.split('-');

    final main1 = preParts1[0]
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final main2 = preParts2[0]
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    while (main1.length < 3) {
      main1.add(0);
    }
    while (main2.length < 3) {
      main2.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (main1[i] != main2[i]) {
        return main1[i].compareTo(main2[i]);
      }
    }

    // Main versions are identical. Check pre-release status.
    final isPre1 = preParts1.length > 1;
    final isPre2 = preParts2.length > 1;

    if (!isPre1 && isPre2) return 1; // Release is newer than pre-release
    if (isPre1 && !isPre2) return -1;
    if (isPre1 && isPre2) {
      final identifiers1 = preParts1.skip(1).join('-').split('.');
      final identifiers2 = preParts2.skip(1).join('-').split('.');
      for (var i = 0; i < identifiers1.length && i < identifiers2.length; i++) {
        final number1 = int.tryParse(identifiers1[i]);
        final number2 = int.tryParse(identifiers2[i]);
        final int comparison;
        if (number1 != null && number2 != null) {
          comparison = number1.compareTo(number2);
        } else if (number1 != null || number2 != null) {
          comparison = number1 != null ? -1 : 1;
        } else {
          comparison = identifiers1[i].compareTo(identifiers2[i]);
        }
        if (comparison != 0) return comparison;
      }
      final lengthComparison = identifiers1.length.compareTo(
        identifiers2.length,
      );
      if (lengthComparison != 0) return lengthComparison;
    }

    // Check build number
    return build1.compareTo(build2);
  }

  static bool isNewerVersion(String latest, String current) {
    return compareVersions(latest, current) > 0;
  }
}
