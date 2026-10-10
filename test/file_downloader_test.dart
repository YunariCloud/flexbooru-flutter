import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexbooru/core/utils/file_downloader.dart';
import 'package:flexbooru/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('FileDownloader Directory Resolution Tests', () {
    test('resolves default directory when custom path is empty or null', () async {
      final defaultDir = await FileDownloader.getDefaultDownloadDirectory();
      expect(defaultDir, isNotNull);
      expect(defaultDir.path.isNotEmpty, isTrue);

      final resolvedNull = await FileDownloader.resolveDownloadDirectory(null);
      expect(resolvedNull.path, equals(defaultDir.path));

      final resolvedEmpty = await FileDownloader.resolveDownloadDirectory('');
      expect(resolvedEmpty.path, equals(defaultDir.path));

      final resolvedWhitespace = await FileDownloader.resolveDownloadDirectory('   ');
      expect(resolvedWhitespace.path, equals(defaultDir.path));
    });

    test('resolves custom directory when valid path provided', () async {
      final tempDir = await Directory.systemTemp.createTemp('flexbooru_test_');
      try {
        final customSub = '${tempDir.path}/custom_downloads';
        final resolved = await FileDownloader.resolveDownloadDirectory(customSub);
        expect(resolved.path, equals(customSub));
        expect(await resolved.exists(), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('checks directory writability correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('flexbooru_write_test_');
      try {
        final isWritable = await FileDownloader.isDirectoryWritable(tempDir.path);
        expect(isWritable, isTrue);

        expect(await FileDownloader.isDirectoryWritable(''), isFalse);
        expect(await FileDownloader.isDirectoryWritable('   '), isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('generates valid path presets', () async {
      final presets = await FileDownloader.getPathPresets();
      expect(presets.containsKey('downloads'), isTrue);
      expect(presets.containsKey('app'), isTrue);
      expect(presets['downloads']!.isNotEmpty, isTrue);
      expect(presets['app']!.isNotEmpty, isTrue);
    });

    test('reports system picker support status consistently', () {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        expect(FileDownloader.isSystemPickerSupported, isTrue);
      } else {
        expect(FileDownloader.isSystemPickerSupported, isFalse);
      }
    });
  });

  group('SettingsProvider Download Path Tests', () {
    test('persists and updates custom download path', () async {
      SharedPreferences.setMockInitialValues({});
      final prov = SettingsProvider();
      await prov.loadSettings();

      expect(prov.downloadPath, isEmpty);

      bool notified = false;
      prov.addListener(() {
        notified = true;
      });

      await prov.setDownloadPath('/custom/download/path');
      expect(prov.downloadPath, equals('/custom/download/path'));
      expect(notified, isTrue);

      // Verify loaded from SharedPreferences
      final reloadedProv = SettingsProvider();
      await reloadedProv.loadSettings();
      expect(reloadedProv.downloadPath, equals('/custom/download/path'));

      // Verify reset to default
      await reloadedProv.setDownloadPath('');
      expect(reloadedProv.downloadPath, isEmpty);
      prov.dispose();
      reloadedProv.dispose();
    });

    test('persists and updates gradient colors', () async {
      SharedPreferences.setMockInitialValues({});
      final prov = SettingsProvider();
      await prov.loadSettings();

      expect(prov.useGradient, isFalse);
      expect(prov.primaryGradient.colors.first, equals(prov.accentColor));

      await prov.setGradientColor(
        const Color(0xFF7F00FF),
        const Color(0xFFE100FF),
      );
      expect(prov.useGradient, isTrue);
      expect(prov.accentColor, equals(const Color(0xFF7F00FF)));
      expect(prov.gradientEndColor, equals(const Color(0xFFE100FF)));
      expect(prov.primaryGradient.colors.length, equals(2));

      // Reload and verify
      final reloaded = SettingsProvider();
      await reloaded.loadSettings();
      expect(reloaded.useGradient, isTrue);
      expect(reloaded.accentColor, equals(const Color(0xFF7F00FF)));
      expect(reloaded.gradientEndColor, equals(const Color(0xFFE100FF)));

      // Switch back to solid
      await reloaded.setAccentColor(const Color(0xFF2196F3));
      expect(reloaded.useGradient, isFalse);
      expect(reloaded.accentColor, equals(const Color(0xFF2196F3)));

      prov.dispose();
      reloaded.dispose();
    });
  });
}
