import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../network/api_client.dart';
import 'url_util.dart';

class FileDownloader {
  static final Dio _dio = ApiClient().dio;

  /// Returns the default download directory for the current platform
  static Future<Directory> getDefaultDownloadDirectory() async {
    Directory? saveDir;
    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          saveDir = Directory('/storage/emulated/0/Download/Flexbooru');
          if (!await saveDir.exists()) {
            try {
              await saveDir.create(recursive: true);
            } catch (_) {
              saveDir = await getExternalStorageDirectory();
            }
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final baseDir = await getDownloadsDirectory();
          if (baseDir != null) {
            saveDir = Directory('${baseDir.path}/Flexbooru');
            if (!await saveDir.exists()) {
              try {
                await saveDir.create(recursive: true);
              } catch (_) {
                saveDir = baseDir;
              }
            }
          }
        }
      }
    } catch (_) {
      // Fall through to app documents
    }

    try {
      saveDir ??= await getApplicationDocumentsDirectory();
    } catch (_) {
      saveDir ??= Directory.systemTemp;
    }
    return saveDir;
  }

  /// Resolves the actual download directory, respecting custom path if valid
  static Future<Directory> resolveDownloadDirectory(String? customPath) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      try {
        final dir = Directory(customPath.trim());
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {
        // Fallback to default if custom directory is not accessible
        return getDefaultDownloadDirectory();
      }
    }
    return getDefaultDownloadDirectory();
  }

  /// Verifies if a given directory path is valid and writable
  static Future<bool> isDirectoryWritable(String path) async {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return false;
    try {
      final dir = Directory(cleanPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(
        '${dir.path}/.flexbooru_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get common path presets for the current platform
  static Future<Map<String, String>> getPathPresets() async {
    final presets = <String, String>{};
    try {
      final defaultDir = await getDefaultDownloadDirectory();
      presets['downloads'] = defaultDir.path;
    } catch (_) {}

    try {
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final downloads = await getDownloadsDirectory();
          if (downloads != null) {
            final picturesDir =
                Directory('${downloads.parent.path}/Pictures/Flexbooru');
            presets['pictures'] = picturesDir.path;
          }
        } else if (Platform.isAndroid) {
          presets['pictures'] = '/storage/emulated/0/Pictures/Flexbooru';
        }
      }
    } catch (_) {}

    try {
      final appDir = await getApplicationDocumentsDirectory();
      presets['app'] = '${appDir.path}/Downloads';
    } catch (_) {
      presets['app'] = '${Directory.systemTemp.path}/Flexbooru';
    }
    return presets;
  }

  /// Checks whether invoking the OS-native system directory picker is supported
  static bool get isSystemPickerSupported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Prompts the user with the platform native folder picker dialog
  static Future<String?> pickDirectoryViaSystemDialog({
    String? initialPath,
  }) async {
    if (kIsWeb) return null;
    try {
      if (Platform.isWindows) {
        final initial = (initialPath != null && initialPath.trim().isNotEmpty)
            ? initialPath.trim().replaceAll("'", "''")
            : '';
        final script = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
\$dialog.Description = 'Select Flexbooru Download Folder'
\$dialog.ShowNewFolderButton = \$true
if ('$initial' -ne '' -and (Test-Path '$initial')) {
    \$dialog.SelectedPath = '$initial'
}
\$form = New-Object System.Windows.Forms.Form
\$form.TopMost = \$true
\$result = \$dialog.ShowDialog(\$form)
\$form.Dispose()
if (\$result -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write(\$dialog.SelectedPath)
}
''';
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-WindowStyle',
            'Hidden',
            '-STA',
            '-Command',
            script,
          ],
          stdoutEncoding: utf8,
        );
        final selected = result.stdout.toString().trim();
        if (selected.isNotEmpty) {
          final dir = Directory(selected);
          if (await dir.exists()) {
            return dir.path;
          }
        }
        return null;
      } else if (Platform.isMacOS) {
        final script =
            'POSIX path of (choose folder with prompt "Select Flexbooru Download Folder")';
        final result = await Process.run(
          'osascript',
          ['-e', script],
          stdoutEncoding: utf8,
        );
        final selected = result.stdout.toString().trim();
        if (selected.isNotEmpty) {
          final dir = Directory(selected);
          if (await dir.exists()) {
            return dir.path;
          }
        }
        return null;
      } else if (Platform.isLinux) {
        ProcessResult? result;
        try {
          result = await Process.run(
            'zenity',
            [
              '--file-selection',
              '--directory',
              '--title=Select Flexbooru Download Folder',
            ],
            stdoutEncoding: utf8,
          );
        } catch (_) {
          try {
            result = await Process.run(
              'kdialog',
              ['--getexistingdirectory', initialPath ?? ''],
              stdoutEncoding: utf8,
            );
          } catch (_) {}
        }
        if (result != null) {
          final selected = result.stdout.toString().trim();
          if (selected.isNotEmpty) {
            final dir = Directory(selected);
            if (await dir.exists()) {
              return dir.path;
            }
          }
        }
        return null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Opens the directory in the platform's file explorer
  static Future<void> openDirectory(String dirPath) async {
    if (kIsWeb) return;
    try {
      final dir = Directory(dirPath.trim());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      }
    } catch (_) {
      // Ignore launch errors
    }
  }

  /// Downloads an image or video file and saves it to device downloads folder
  static Future<String?> downloadFile({
    required String fileUrl,
    required String host,
    String? customFileName,
    String? customSavePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final fileName = customFileName ?? UrlUtil.getFileName(fileUrl);
      final saveDir = await resolveDownloadDirectory(customSavePath);

      final filePath = '${saveDir.path}/$fileName';
      final file = File(filePath);

      final headers = ApiClient.getImageHeaders(host: host);

      await _dio.download(
        fileUrl,
        filePath,
        options: Options(headers: headers),
        onReceiveProgress: onProgress,
      );

      return file.path;
    } catch (e) {
      rethrow;
    }
  }
}
