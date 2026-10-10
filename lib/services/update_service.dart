import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    this.publishedAt,
    required this.hasUpdate,
  });
}

class UpdateService {
  final Dio? _customDio;

  UpdateService({Dio? dio}) : _customDio = dio;

  Dio get _dio => _customDio ?? ApiClient().dio;

  Future<UpdateInfo> checkUpdate({String? currentVersion}) async {
    final curVer = (currentVersion ?? AppConstants.rawVersion).trim();

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
      final htmlUrl = (parsed['html_url'] as String? ?? AppConstants.githubReleasesUrl).trim();
      final publishedAtStr = parsed['published_at'] as String?;
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final latestVer = normalizeVersion(tagName);
      final hasUpdate = isNewerVersion(latestVer, curVer);

      // Extract direct asset download URL for Android or Windows
      String? downloadUrl;
      final assets = parsed['assets'] as List<dynamic>? ?? [];
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        } else if (Platform.isWindows) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.zip')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }
      }

      return UpdateInfo(
        currentVersion: curVer,
        latestVersion: latestVer,
        tagName: tagName,
        title: title.isEmpty ? tagName : title,
        releaseNotes: releaseNotes,
        releaseUrl: htmlUrl,
        downloadUrl: downloadUrl ?? htmlUrl,
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
        if (location != null && location.contains('/releases/tag/')) {
          final rawTag = location.split('/releases/tag/').last.split('?').first.trim();
          final latestVer = normalizeVersion(rawTag);
          final hasUpdate = isNewerVersion(latestVer, curVer);
          return UpdateInfo(
            currentVersion: curVer,
            latestVersion: latestVer,
            tagName: rawTag,
            title: 'Flexbooru $rawTag',
            releaseNotes: '',
            releaseUrl: location,
            downloadUrl: location,
            hasUpdate: hasUpdate,
          );
        }
      } catch (_) {
        // Fallback also failed, propagate original error
      }
      rethrow;
    }
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

    final main1 = preParts1[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final main2 = preParts2[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

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
      final comp = preParts1[1].compareTo(preParts2[1]);
      if (comp != 0) return comp;
    }

    // Check build number
    return build1.compareTo(build2);
  }

  static bool isNewerVersion(String latest, String current) {
    return compareVersions(latest, current) > 0;
  }
}
