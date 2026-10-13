import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flexbooru/core/utils/url_util.dart';
import 'package:flexbooru/core/utils/file_downloader.dart';
import 'package:flexbooru/core/sync/sync_record_codec.dart';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/models/search_state.dart';
import 'package:flexbooru/services/search_store.dart';
import 'package:flexbooru/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/mock_http_adapter.dart';
import 'lan_sync_test.dart' show MemoryPersistence, preferences, sites;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'large trusted snapshots keep tombstones without weakening LAN frame limits',
    () {
      final records = List.generate(
        50001,
        (i) => {
          'key': 'blacklist/${syncId('old_$i')}',
          'clock': 1,
          'device': 'a',
          'value': null,
          'deleted': true,
        },
      );
      final state = SyncState('a');
      expect(() => state.merge(records), throwsFormatException);
      state.merge(records, snapshot: true);
      final copy = state.copy()..capture(blacklistPreference, ['new']);
      expect(state.readPreference(blacklistPreference), []);
      expect(copy.readPreference(blacklistPreference), ['new']);
      expect(copy.entries.length, 50002);
    },
  );
  test('media paths are classified independently of query and fragment', () {
    expect(UrlUtil.isVideo('https://example.org/x.MP4?key=1#t=2'), true);
    expect(UrlUtil.isGif('https://example.org/x.gif?size=full'), true);
    expect(
      UrlUtil.isVideo('https://example.org/x.jpg?format=movie.mp4'),
      false,
    );
  });
  test(
    'damaged local search records retain valid rows and raw backup',
    () async {
      final raw = jsonEncode([
        const SearchRecord(
          id: 'draft:a',
          kind: 'draft',
          siteId: 'a',
          query: 'valid',
        ).toJson(),
        {'id': 'bad', 'kind': 'unknown'},
      ]);
      SharedPreferences.setMockInitialValues({searchPreference: raw});
      final store = SearchStore();
      await store.ready;
      expect(store.draft('a'), 'valid');
      expect(store.invalidRecords, 1);
      await store.recordSearch('a', 'new');
      expect(store.history('a').single.query, 'new');
      expect(
        (await SharedPreferences.getInstance()).getString(
          '${searchPreference}_recovery_backup',
        ),
        raw,
      );
      await store.dismissRecoveryWarning();
      expect(store.invalidRecords, 0);
      store.dispose();
    },
  );
  test(
    'sync migration recovers malformed searches without blocking vault',
    () async {
      final prefs = await preferences({
        sitesPreference: sites(),
        searchPreference: '{bad json',
      });
      final sync = LanSyncService(
        preferences: prefs,
        persistence: MemoryPersistence(),
        attachToApp: false,
      );
      await sync.initialize();
      expect(prefs.getString(searchPreference), '[]');
      expect(
        prefs.getString('${searchPreference}_recovery_backup'),
        '{bad json',
      );
      await sync.updatePreference('flex_image_quality', 'original');
      expect(prefs.getString('flex_image_quality'), 'original');
      await sync.shutdown();
    },
  );
  test(
    'compressed journal preserves order, deletion versions and legacy data',
    () {
      final state = SyncState('a');
      state.capture(blacklistPreference, ['first', 'second']);
      state.capture(blacklistPreference, ['second']);
      final original = {'device': 'a', 'records': state.records};
      expect(unpackSyncJournal(packSyncJournal(original)), original);
      expect(unpackSyncJournal(original), original);
      final restored = SyncState('b')
        ..merge(
          (unpackSyncJournal(packSyncJournal(original)))['records'] as List,
        );
      expect(restored.readPreference(blacklistPreference), ['second']);
      final stale = SyncState('old')
        ..capture(blacklistPreference, ['first'], seed: true);
      restored.merge(stale.records);
      expect(restored.readPreference(blacklistPreference), ['second']);
    },
  );
  test(
    'downloads use unique identity names and preserve existing file on failure',
    () async {
      final dir = await Directory.systemTemp.createTemp('flex-download-safe-');
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter(
          (_) => ResponseBody.fromBytes(
            Uint8List.fromList([1, 2, 3, 4]),
            200,
            headers: {
              'content-length': ['4'],
            },
          ),
        );
      try {
        final first = await FileDownloader.downloadFile(
          fileUrl: 'https://example.org/shared.jpg',
          host: 'example.org',
          customSavePath: dir.path,
          siteId: 'a',
          postId: 1,
          client: dio,
        );
        final results = await Future.wait(
          List.generate(
            2,
            (_) => FileDownloader.downloadFile(
              fileUrl: 'https://example.org/shared.jpg',
              host: 'example.org',
              customSavePath: dir.path,
              siteId: 'a',
              postId: 1,
              client: dio,
            ),
          ),
        );
        expect({first, ...results}.length, 3);
        dio.httpClientAdapter = MockHttpAdapter(
          (_) => jsonResponse({}, status: 500),
        );
        await expectLater(
          FileDownloader.downloadFile(
            fileUrl: 'https://example.org/shared.jpg',
            host: 'example.org',
            customSavePath: dir.path,
            siteId: 'a',
            postId: 1,
            client: dio,
          ),
          throwsA(isA<DioException>()),
        );
        expect(await File(first!).readAsBytes(), [1, 2, 3, 4]);
        final names = await dir.list().map((f) => f.path).toList();
        expect(names.length, 3);
        expect(
          names.any((n) => n.endsWith('.part') || n.endsWith('.download-lock')),
          false,
        );
      } finally {
        dio.close(force: true);
        expect(
          dir.absolute.path.startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}flex-download-safe-',
          ),
          true,
        );
        await dir.delete(recursive: true);
      }
    },
  );
}
