import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flexbooru/services/google_drive_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_http_adapter.dart';

void main() {
  test(
    'Drive transport limits access to appDataFolder and paginates',
    () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          calls++;
          expect(request.uri.host, 'www.googleapis.com');
          expect(request.queryParameters['spaces'], 'appDataFolder');
          expect(request.headers['Authorization'], 'Bearer example');
          return jsonResponse({
            'files': [
              {'id': '$calls', 'name': 'flexbooru-sync-v1-device$calls.json'},
              {'id': 'unrelated', 'name': 'holiday.jpg'},
            ],
            if (calls == 1) 'nextPageToken': 'next',
          });
        });
      final transport = GoogleDriveTransport(
        () async => 'example',
        (_) async {},
        dio: dio,
      );
      expect((await transport.list()).length, 2);
      expect(calls, 2);
    },
  );
  test(
    'expired token is cleared once; upload targets only its own device file',
    () async {
      var cleared = 0, calls = 0;
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          calls++;
          if (calls == 1) return jsonResponse({}, status: 401);
          expect(request.method, 'PATCH');
          expect(request.uri.path, '/upload/drive/v3/files/own-file');
          expect(request.queryParameters['uploadType'], 'media');
          return jsonResponse({});
        });
      final transport = GoogleDriveTransport(() async => 'example', (_) async {
        cleared++;
      }, dio: dio);
      await transport.write(
        'flexbooru-sync-v1-device.json',
        '{}',
        id: 'own-file',
      );
      expect(cleared, 1);
      expect(calls, 2);
    },
  );
  test(
    'new snapshot upload explicitly requests hidden parent folder',
    () async {
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          expect(request.uri.path, '/upload/drive/v3/files');
          expect(request.queryParameters['uploadType'], 'multipart');
          expect(
            request.data.toString(),
            contains(
              jsonEncode({
                'name': 'flexbooru-sync-v1-device.json',
                'parents': ['appDataFolder'],
                'mimeType': 'application/json',
              }),
            ),
          );
          return jsonResponse({'id': 'created'});
        });
      await GoogleDriveTransport(
        () async => 'example',
        (_) async {},
        dio: dio,
      ).write('flexbooru-sync-v1-device.json', '{"encrypted":true}');
    },
  );
}
