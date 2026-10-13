import 'dart:convert';
import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/core/sync/drive_sync_crypto.dart';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/models/search_state.dart';
import 'package:flexbooru/services/google_drive_auth.dart';
import 'package:flexbooru/services/google_drive_transport.dart';
import 'package:flexbooru/services/google_drive_sync_service.dart';
import 'package:flexbooru/services/lan_sync_service.dart';
import 'lan_sync_test.dart'
    show MemoryPersistence, preferences, sites, favorites;

class FakeAuth extends GoogleDriveAuth {
  @override
  Future<void> load() async {}
  @override
  Future<String> token({bool interactive = false}) async => 'fake-test-token';
  @override
  Future<void> signOut() async {}
}

class MemoryDrive implements DriveSyncTransport {
  final Map<String, (String, String)> files = {};
  bool fail = false;
  int writes = 0;
  @override
  void cancel() {}
  @override
  Future<List<DriveSyncFile>> list() async {
    if (fail) throw StateError('offline');
    return files.entries.map((e) => DriveSyncFile(e.key, e.value.$1)).toList();
  }

  @override
  Future<String> read(String id) async => files[id]!.$2;
  @override
  Future<void> write(String name, String data, {String? id}) async {
    writes++;
    files[id ?? '${files.length}'] = (name, data);
  }
}

class SlowAuth extends FakeAuth {
  final tokenReady = Completer<String>();
  @override
  Future<String> token({bool interactive = false}) => tokenReady.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'disconnect during sign-in does not enable sync or upload later',
    () async {
      final local = LanSyncService(
        preferences: await preferences({sitesPreference: sites()}),
        persistence: MemoryPersistence(),
        attachToApp: false,
      );
      final auth = SlowAuth();
      final drive = MemoryDrive();
      final service = GoogleDriveSyncService(
        local,
        auth: auth,
        transport: drive,
      );
      final connecting = service.connect('independent-password');
      await Future<void>.delayed(Duration.zero);
      await service.disconnect();
      auth.tokenReady.complete('example');
      await connecting;
      expect(service.enabled, false);
      expect(service.status, 'off');
      expect(drive.writes, 0);
      service.dispose();
      await local.shutdown();
    },
  );
  test(
    'cloud encryption rejects incorrect password and retains deletions',
    () async {
      final cipher = DriveSyncCipher('independent-strong-password');
      final state = SyncState('a')
        ..capture(blacklistPreference, ['secret_tag']);
      state.capture(blacklistPreference, []);
      final raw = await cipher.seal(state.records, device: 'a');
      expect(raw.contains('secret_tag'), false);
      final restored = SyncState('b')
        ..merge((await cipher.open(raw))['records'] as List);
      expect(restored.readPreference(blacklistPreference), []);
      await expectLater(
        DriveSyncCipher('incorrect-password').open(raw),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test(
    'two devices merge cloud edits, credentials and searches; wrong password never uploads',
    () async {
      final ap = await preferences({
        sitesPreference: sites(token: 'private-login'),
        favoritesPreference: favorites([1]),
      });
      final bp = await preferences({
        sitesPreference: sites(),
        favoritesPreference: favorites([2]),
      });
      final a = LanSyncService(
        preferences: ap,
        persistence: MemoryPersistence(),
        attachToApp: false,
      );
      final b = LanSyncService(
        preferences: bp,
        persistence: MemoryPersistence(),
        attachToApp: false,
      );
      final drive = MemoryDrive();
      final ca = GoogleDriveSyncService(a, auth: FakeAuth(), transport: drive);
      final cb = GoogleDriveSyncService(b, auth: FakeAuth(), transport: drive);
      try {
        await ca.connect('same-independent-password');
        expect(ca.error, isNull);
        final before = drive.writes;
        await cb.connect('wrong-independent-password');
        expect(cb.error, 'password');
        expect(drive.writes, before);
        expect(
          (jsonDecode(bp.getString(favoritesPreference)!) as List).length,
          1,
        );
        await cb.connect('same-independent-password');
        expect(cb.error, isNull);
        await ca.syncNow();
        expect(
          (jsonDecode(ap.getString(favoritesPreference)!) as List).map(
            (e) => e['id'],
          ),
          unorderedEquals([1, 2]),
        );
        expect(
          (jsonDecode(bp.getString(sitesPreference)!) as List).single['token'],
          isNull,
        );
        expect(
          (b.records.firstWhere(
                (e) => (e['key'] as String).endsWith('/credentials'),
              )['value']
              as Map)['token'],
          'private-login',
        );
        expect(
          drive.files.values.any((f) => f.$2.contains('private-login')),
          false,
        );
        await a.updatePreference(
          searchPreference,
          jsonEncode([
            const SearchRecord(
              id: 'preset:a',
              kind: 'preset',
              siteId: 'site',
              name: 'A',
              query: 'cat',
            ).toJson(),
          ]),
        );
        await b.updatePreference(
          searchPreference,
          jsonEncode([
            const SearchRecord(
              id: 'preset:b',
              kind: 'preset',
              siteId: 'site',
              name: 'B',
              query: 'dog',
            ).toJson(),
          ]),
        );
        await ca.syncNow();
        await cb.syncNow();
        await ca.syncNow();
        expect(SearchRecord.decode(ap.getString(searchPreference)).length, 2);
        await a.updatePreference(searchPreference, '[]');
        await ca.syncNow();
        await cb.syncNow();
        expect(SearchRecord.decode(bp.getString(searchPreference)), isEmpty);
        final count = drive.writes;
        await cb.syncNow();
        expect(drive.writes, count);
        expect(ca.enabled, true);
      } finally {
        ca.dispose();
        cb.dispose();
        await a.shutdown();
        await b.shutdown();
      }
    },
  );
}
