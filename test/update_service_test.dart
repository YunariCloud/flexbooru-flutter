import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'support/mock_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('uses installed package version and build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Flexbooru',
      packageName: 'com.flexbooru.app.flexbooru',
      version: '1.2.3',
      buildNumber: '7',
      buildSignature: '',
    );
    expect(await UpdateService.installedVersion(), '1.2.3+7');
  });

  test(
    'selects universal APK and Windows x64 ZIP from mixed release assets',
    () async {
      const root =
          'https://github.com/YunariCloud/flexbooru-flutter/releases/download/v2.0.0';
      final assets = [
        'flexbooru-linux-x64.zip',
        'flexbooru-windows-arm64.zip',
        'flexbooru-android-arm64.apk',
        'flexbooru-android.aab',
        'flexbooru-android-universal.apk',
        'flexbooru-windows-x64.zip',
        'windows-SHA256SUMS.txt',
      ];
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter(
          (_) => jsonResponse({
            'tag_name': 'v2.0.0',
            'assets': [
              {
                'name': 'fake-universal.apk',
                'browser_download_url': 'https://example.com/app.apk',
              },
              ...assets.map(
                (name) => {'name': name, 'browser_download_url': '$root/$name'},
              ),
            ],
          }),
        );
      final android = await UpdateService(
        dio: dio,
        targetPlatform: 'android',
      ).checkUpdate(currentVersion: '1.0.0');
      final windows = await UpdateService(
        dio: dio,
        targetPlatform: 'windows',
      ).checkUpdate(currentVersion: '1.0.0');
      expect(android.assetName, 'flexbooru-android-universal.apk');
      expect(windows.assetName, 'flexbooru-windows-x64.zip');
      expect(windows.checksumUrl, '$root/windows-SHA256SUMS.txt');
    },
  );

  test('release without a compatible asset offers only release page', () async {
    final dio = Dio()
      ..httpClientAdapter = MockHttpAdapter(
        (_) => jsonResponse({
          'tag_name': 'v2.0.0',
          'assets': [
            {
              'name': 'flexbooru-android.aab',
              'browser_download_url':
                  'https://github.com/YunariCloud/flexbooru-flutter/releases/download/v2.0.0/app.aab',
            },
          ],
        }),
      );
    final info = await UpdateService(
      dio: dio,
      targetPlatform: 'android',
    ).checkUpdate(currentVersion: '1.0.0');
    expect(info.hasUpdate, isTrue);
    expect(info.downloadUrl, isNull);
    expect(info.assetName, isNull);
  });

  group('UpdateService Version Comparison Tests', () {
    test('compares standard major.minor.patch versions', () {
      expect(UpdateService.compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), equals(0));
      expect(UpdateService.compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(UpdateService.compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('handles v prefix correctly', () {
      expect(UpdateService.compareVersions('v1.0.1', '1.0.0'), greaterThan(0));
      expect(UpdateService.compareVersions('V1.0.0', 'v1.0.0'), equals(0));
      expect(UpdateService.compareVersions('v0.9.5', '1.0.0'), lessThan(0));
    });

    test('handles build numbers', () {
      expect(
        UpdateService.compareVersions('1.0.0+2', '1.0.0+1'),
        greaterThan(0),
      );
      expect(UpdateService.compareVersions('1.0.0+1', '1.0.0+2'), lessThan(0));
      expect(UpdateService.compareVersions('1.0.0+1', '1.0.0+1'), equals(0));
    });

    test('handles pre-release tags', () {
      expect(
        UpdateService.compareVersions('1.0.0', '1.0.0-rc.1'),
        greaterThan(0),
      );
      expect(UpdateService.compareVersions('1.0.0-rc.1', '1.0.0'), lessThan(0));
      expect(
        UpdateService.compareVersions('1.0.0-rc.2', '1.0.0-rc.1'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareVersions('1.0.0-rc.10', '1.0.0-rc.2'),
        greaterThan(0),
      );
    });

    test('isNewerVersion returns correct boolean', () {
      expect(UpdateService.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v0.9.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0+2', '1.0.0+1'), isTrue);
    });
  });

  group('UpdateService checkUpdate Tests', () {
    test('successfully parses latest GitHub release API response', () async {
      final mockData = {
        'tag_name': 'v1.1.0',
        'name': 'Flexbooru Flutter v1.1.0',
        'body': '• New features\n• Bug fixes',
        'html_url':
            'https://github.com/YunariCloud/flexbooru-flutter/releases/tag/v1.1.0',
        'published_at': '2026-10-10T12:00:00Z',
        'assets': [
          {
            'name': 'flexbooru-flutter-v1.1.0-android-universal.apk',
            'browser_download_url':
                'https://github.com/YunariCloud/flexbooru-flutter/releases/download/v1.1.0/app.apk',
            'size': 12345,
            'digest': 'sha256:${List.filled(64, 'a').join()}',
          },
          {
            'name': 'flexbooru-flutter-v1.1.0-windows-x64.zip',
            'browser_download_url': 'https://example.com/app.zip',
          },
        ],
      };

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: jsonEncode(mockData),
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final service = UpdateService(dio: dio, targetPlatform: 'android');
      final info = await service.checkUpdate(currentVersion: '1.0.0');

      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, equals('1.1.0'));
      expect(info.currentVersion, equals('1.0.0'));
      expect(info.tagName, equals('v1.1.0'));
      expect(info.title, equals('Flexbooru Flutter v1.1.0'));
      expect(info.releaseNotes, contains('New features'));
      expect(info.releaseUrl, contains('v1.1.0'));
      expect(info.downloadUrl, isNotNull);
      expect(info.assetName, endsWith('universal.apk'));
      expect(info.assetSize, 12345);
      expect(info.assetSha256, List.filled(64, 'a').join());
    });

    test('reports hasUpdate = false when versions match', () async {
      final mockData = {
        'tag_name': 'v1.0.0',
        'name': 'Flexbooru Flutter v1.0.0',
        'body': 'Initial release',
        'html_url':
            'https://github.com/YunariCloud/flexbooru-flutter/releases/tag/v1.0.0',
        'assets': [],
      };

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: jsonEncode(mockData),
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final service = UpdateService(dio: dio);
      final info = await service.checkUpdate(currentVersion: '1.0.0');

      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, equals('1.0.0'));
    });

    test('falls back to location header redirect when API throws', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.contains('/api.github.com/')) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 403,
                    statusMessage: 'Rate limit exceeded',
                  ),
                ),
              );
            } else {
              // Redirect fallback response
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': [
                      'https://github.com/YunariCloud/flexbooru-flutter/releases/tag/v1.0.5',
                    ],
                  }),
                ),
              );
            }
          },
        ),
      );

      final service = UpdateService(dio: dio);
      final info = await service.checkUpdate(currentVersion: '1.0.0');

      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, equals('1.0.5'));
      expect(info.tagName, equals('v1.0.5'));
      expect(info.downloadUrl, isNull);
    });
  });
}
