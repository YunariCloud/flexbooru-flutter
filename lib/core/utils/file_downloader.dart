import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../network/api_client.dart';
import 'url_util.dart';

class FileDownloader {
  static final Dio _dio = ApiClient().dio;

  /// Downloads an image or video file and saves it to device downloads folder
  static Future<String?> downloadFile({
    required String fileUrl,
    required String host,
    String? customFileName,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final fileName = customFileName ?? UrlUtil.getFileName(fileUrl);

      Directory? saveDir;
      if (Platform.isAndroid) {
        // Try public download directory
        saveDir = Directory('/storage/emulated/0/Download/Flexbooru');
        if (!await saveDir.exists()) {
          try {
            await saveDir.create(recursive: true);
          } catch (_) {
            saveDir = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        saveDir = await getDownloadsDirectory();
        if (saveDir != null) {
          saveDir = Directory('${saveDir.path}/Flexbooru');
          if (!await saveDir.exists()) {
            await saveDir.create(recursive: true);
          }
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      saveDir ??= await getApplicationDocumentsDirectory();

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
