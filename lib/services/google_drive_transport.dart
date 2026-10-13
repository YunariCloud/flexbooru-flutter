import 'dart:convert';
import 'package:dio/dio.dart';

class DriveSyncFile {
  const DriveSyncFile(this.id, this.name);
  final String id, name;
}

abstract class DriveSyncTransport {
  Future<List<DriveSyncFile>> list();
  Future<String> read(String id);
  Future<void> write(String name, String data, {String? id});
  void cancel() {}
}

/// Uses only the appDataFolder scope. No access to ordinary user Drive files.
class GoogleDriveTransport implements DriveSyncTransport {
  GoogleDriveTransport(this.token, this.invalidate, {Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
  final Future<String> Function() token;
  final Future<void> Function(String) invalidate;
  final Dio dio;
  CancelToken _cancel = CancelToken();
  @override
  void cancel() {
    _cancel.cancel();
    _cancel = CancelToken();
  }

  Future<Response<String>> _request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    String? contentType,
  }) async {
    final cancel = _cancel;
    for (var attempt = 0; ; attempt++) {
      final access = await token();
      try {
        return await dio.request<String>(
          'https://www.googleapis.com/$path',
          data: data,
          queryParameters: query,
          cancelToken: cancel,
          options: Options(
            method: method,
            responseType: ResponseType.plain,
            contentType: contentType,
            headers: {'Authorization': 'Bearer $access'},
          ),
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 401 || attempt > 0) rethrow;
        await invalidate(access);
      }
    }
  }

  @override
  Future<List<DriveSyncFile>> list() async {
    final result = <DriveSyncFile>[];
    String? page;
    do {
      final response = await _request(
        'drive/v3/files',
        query: {
          'spaces': 'appDataFolder',
          'q': "trashed = false and name contains 'flexbooru-sync-v1-'",
          'fields': 'nextPageToken,files(id,name)',
          'pageSize': 100,
          'pageToken': ?page,
        },
      );
      final data = jsonDecode(response.data!) as Map;
      for (final file in data['files'] as List? ?? []) {
        if (RegExp(
          r'^flexbooru-sync-v1-[a-zA-Z0-9_=-]+\.json$',
        ).hasMatch(file['name'] as String)) {
          result.add(
            DriveSyncFile(file['id'] as String, file['name'] as String),
          );
        }
      }
      if (result.length > 100) {
        throw const FormatException('Too many cloud sync devices');
      }
      page = data['nextPageToken'] as String?;
    } while (page != null);
    return result;
  }

  @override
  Future<String> read(String id) async {
    final response = await _request(
      'drive/v3/files/${Uri.encodeComponent(id)}',
      query: {'alt': 'media'},
    );
    final data = response.data!;
    if (data.length > 32 * 1024 * 1024) {
      throw const FormatException('Cloud sync file too large');
    }
    return data;
  }

  @override
  Future<void> write(String name, String data, {String? id}) async {
    if (id != null) {
      await _request(
        'upload/drive/v3/files/${Uri.encodeComponent(id)}',
        method: 'PATCH',
        query: {'uploadType': 'media'},
        data: data,
        contentType: 'application/json',
      );
      return;
    }
    const boundary = 'flexbooru_drive_sync_boundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
    });
    final body =
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'
        '--$boundary\r\nContent-Type: application/json\r\n\r\n$data\r\n--$boundary--\r\n';
    await _request(
      'upload/drive/v3/files',
      method: 'POST',
      query: {'uploadType': 'multipart'},
      data: body,
      contentType: 'multipart/related; boundary=$boundary',
    );
  }
}
