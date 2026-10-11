import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flexbooru/services/tag_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'support/mock_http_adapter.dart';
import 'support/tag_database_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String path;
  final service = TagTranslationService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('flexbooru_db_update_');
    path = '${directory.path}/tags.sqlite';
    createTagDatabase(path);
    service.setCustomDbPath(path);
    await service.init();
  });
  tearDown(() async {
    service.setCustomDbPath(null);
    for (final file in directory.listSync()) {
      await file.delete();
    }
    await directory.delete();
  });

  test(
    'valid download pins revision, refreshes cache and stops update notices',
    () async {
      final newPath = '${directory.path}/new.sqlite';
      createTagDatabase(newPath, translation: '新版翻译');
      final bytes = await File(newPath).readAsBytes();
      expect(service.getTranslation('1girl')?.cnName, '单个女孩');
      var remoteSha = 'revision-one';
      final downloads = <String>[];
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          if (request.uri.path.endsWith('/commits')) {
            return jsonResponse([
              {
                'sha': remoteSha,
                'commit': {
                  'committer': {'date': '2026-10-11T00:00:00Z'},
                },
              },
            ]);
          }
          downloads.add(request.uri.path);
          return ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/octet-stream'],
              Headers.contentLengthHeader: ['${bytes.length}'],
              'etag': ['"etag-one"'],
            },
          );
        });
      await service.downloadDatabase(client: dio);
      expect(downloads.single, contains('/revision-one/tag.sqlite'));
      expect(service.getTranslation('1girl')?.cnName, '新版翻译');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TagTranslationService.keyTagDbSha),
        'revision-one',
      );
      expect(
        prefs.getString(TagTranslationService.keyTagDbDate),
        '2026-10-11T00:00:00Z',
      );
      expect((await service.checkForUpdate(client: dio)).hasUpdate, isFalse);
      remoteSha = 'revision-two';
      expect((await service.checkForUpdate(client: dio)).hasUpdate, isTrue);
      expect(await File('$path.bak').exists(), isFalse);
      expect(await File('$path.tmp').exists(), isFalse);
    },
  );

  for (final invalid in ['html', 'wrong-schema']) {
    test('$invalid download preserves the old DB and its metadata', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TagTranslationService.keyTagDbSha, 'old-revision');
      final originalBytes = await File(path).readAsBytes();
      List<int> bytes = '<html>temporary error</html>'.codeUnits;
      if (invalid == 'wrong-schema') {
        final invalidPath = '${directory.path}/wrong.sqlite';
        final database = sqlite3.open(invalidPath);
        database.execute('CREATE TABLE unrelated (id INTEGER)');
        database.close();
        bytes = await File(invalidPath).readAsBytes();
      }
      var attempts = 0;
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          if (request.uri.path.endsWith('/commits')) {
            return jsonResponse([
              {'sha': 'new-revision'},
            ]);
          }
          attempts++;
          return ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/octet-stream'],
            },
          );
        });
      await expectLater(
        service.downloadDatabase(client: dio),
        throwsA(anything),
      );
      expect(attempts, TagTranslationService.downloadMirrors.length);
      expect(await File(path).readAsBytes(), originalBytes);
      expect(service.isDatabaseReady, isTrue);
      expect(service.getTranslation('1girl')?.cnName, '单个女孩');
      expect(
        prefs.getString(TagTranslationService.keyTagDbSha),
        'old-revision',
      );
      expect(await File('$path.tmp').exists(), isFalse);
    });
  }

  test(
    'API fallback uses ETag rather than comparing download and commit dates',
    () async {
      final bytes = await File(path).readAsBytes();
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          if (request.uri.path.endsWith('/commits')) {
            return jsonResponse({}, status: 503);
          }
          return ResponseBody.fromBytes(
            request.method == 'HEAD' ? [] : bytes,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/octet-stream'],
              'etag': ['"stable-etag"'],
              'last-modified': ['Sun, 11 Oct 2026 00:00:00 GMT'],
            },
          );
        });
      await service.downloadDatabase(client: dio);
      expect((await service.checkForUpdate(client: dio)).hasUpdate, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TagTranslationService.keyTagDbSha), isNull);
      expect(
        prefs.getString(TagTranslationService.keyTagDbEtag),
        'stable-etag',
      );
    },
  );

  test(
    'old installs with only an ETag do not repeatedly show unchanged updates',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TagTranslationService.keyTagDbEtag, 'stable-etag');
      await prefs.setString(TagTranslationService.keyTagDbDate, '2026-10-10');
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((request) {
          if (request.uri.path.endsWith('/commits')) {
            return jsonResponse([
              {
                'sha': 'current-revision',
                'commit': {
                  'committer': {'date': '2026-10-11T00:00:00Z'},
                },
              },
            ]);
          }
          return ResponseBody.fromString(
            '',
            200,
            headers: {
              'etag': ['"stable-etag"'],
            },
          );
        });
      expect((await service.checkForUpdate(client: dio)).hasUpdate, isFalse);
    },
  );

  test('concurrent downloads share one operation', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final bytes = await File(path).readAsBytes();
    var downloads = 0;
    final dio = Dio()
      ..httpClientAdapter = MockHttpAdapter((request) async {
        if (request.uri.path.endsWith('/commits')) {
          return jsonResponse([
            {'sha': 'one'},
          ]);
        }
        downloads++;
        started.complete();
        await release.future;
        return ResponseBody.fromBytes(bytes, 200);
      });
    final first = service.downloadDatabase(client: dio);
    await started.future;
    final second = service.downloadDatabase(client: dio);
    expect(identical(first, second), isTrue);
    release.complete();
    await Future.wait([first, second]);
    expect(downloads, 1);
  });
}
