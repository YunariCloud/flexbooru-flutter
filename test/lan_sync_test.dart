import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flexbooru/core/sync/sync_crypto.dart';
import 'package:flexbooru/core/sync/sync_persistence.dart';
import 'package:flexbooru/core/sync/sync_preferences.dart';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/providers/booru_provider.dart';
import 'package:flexbooru/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String sites({String name = 'Site', String? token, String? username}) =>
    jsonEncode([
      BooruSite(
        id: 'site',
        name: name,
        host: 'example.org',
        type: 0,
        token: token,
        username: username,
      ).toJson(),
    ]);

String favorites(List<Object> ids) => jsonEncode(
  ids
      .map(
        (id) => Post(
          id: id,
          booruId: 'site',
          width: 100,
          height: 80,
          rating: 's',
          previewUrl: 'https://example.org/$id.jpg',
          sampleUrl: '',
          originUrl: '',
          tags: [],
          tagString: '',
          isFavored: true,
        ).toJson(),
      )
      .toList(),
);

Future<SharedPreferences> preferences(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

class MemoryPersistence implements SyncPersistence {
  Map<String, dynamic>? data;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> load() async => data;
  @override
  Future<void> save(Map<String, dynamic> next) async {
    if (fail) throw StateError('No space');
    data = (jsonDecode(jsonEncode(next)) as Map).cast<String, dynamic>();
  }
}

Future<void> eventually(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) fail('Sync condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('merge journal', () {
    test(
      'editing a site does not undo a concurrent active-site selection',
      () async {
        final initial = BooruSite(
          id: 'first',
          name: 'First',
          host: 'example.org',
          type: 0,
        );
        final other = initial.copyWith(id: 'other', name: 'Other');
        final prefs = await preferences({
          sitesPreference: jsonEncode([initial.toJson(), other.toJson()]),
          'flexbooru_active_site_id': initial.id,
        });
        final provider = BooruProvider();
        addTearDown(provider.dispose);
        await provider.ready;
        await prefs.setString('flexbooru_active_site_id', other.id);
        await provider.updateSite(initial.copyWith(name: 'Renamed'));
        expect(prefs.getString('flexbooru_active_site_id'), other.id);
      },
    );
    test(
      'stale UI writes preserve newly received items, deletions and credentials',
      () {
        final a = SyncState('a')
          ..capture(sitesPreference, sites(token: 'old', username: 'old-user'));
        a.capture(favoritesPreference, favorites([1]));
        final b = SyncState('b')..merge(a.records);
        b.capture(sitesPreference, sites(token: 'new', username: 'new-user'));
        b.capture(favoritesPreference, favorites([1, 2]));
        a.merge(b.records);
        a.capture(
          sitesPreference,
          sites(name: 'Local rename', token: 'old', username: 'old-user'),
          previousValue: sites(token: 'old', username: 'old-user'),
        );
        a.capture(
          favoritesPreference,
          favorites([1, 3]),
          previousValue: favorites([1]),
        );
        final site =
            (jsonDecode(a.readPreference(sitesPreference) as String) as List)
                .single;
        expect(site['name'], 'Local rename');
        expect(site['username'], 'new-user');
        expect(site['token'], 'new');
        expect(
          (jsonDecode(a.readPreference(favoritesPreference) as String) as List)
              .map((p) => p['id']),
          unorderedEquals([1, 2, 3]),
        );
        b.merge(a.records);
        b.capture(favoritesPreference, favorites([2, 3]));
        a.merge(b.records);
        a.capture(
          favoritesPreference,
          favorites([1, 2, 3, 4]),
          previousValue: favorites([1, 2, 3]),
        );
        expect(
          (jsonDecode(a.readPreference(favoritesPreference) as String) as List)
              .map((p) => p['id']),
          unorderedEquals([2, 3, 4]),
        );
      },
    );
    test(
      'offline additions and different site fields survive in both directions',
      () {
        final a = SyncState('a')
          ..capture(sitesPreference, sites(token: 'old', username: 'user'));
        final b = SyncState('b')..merge(a.records);
        a.capture(
          sitesPreference,
          sites(name: 'Renamed', token: 'old', username: 'user'),
        );
        b.capture(sitesPreference, sites(token: 'new', username: 'user'));
        a.capture(favoritesPreference, favorites([1]));
        b.capture(favoritesPreference, favorites(['opaque-id']));
        a.capture(blacklistPreference, ['tag_a']);
        b.capture(blacklistPreference, ['tag_b']);
        final aRecords = a.records;
        a.merge(b.records);
        b.merge(aRecords);
        expect(
          a.readPreference(sitesPreference),
          b.readPreference(sitesPreference),
        );
        final site =
            (jsonDecode(a.readPreference(sitesPreference) as String) as List)
                .single;
        expect(site['name'], 'Renamed');
        expect(site['token'], 'new');
        expect(
          (jsonDecode(a.readPreference(favoritesPreference) as String) as List)
              .length,
          2,
        );
        expect(
          a.readPreference(blacklistPreference),
          unorderedEquals(['tag_a', 'tag_b']),
        );
        expect(a.merge(b.records), isEmpty);
      },
    );

    test('deletions survive old peer state and may be explicitly re-added', () {
      final a = SyncState('a')..capture(favoritesPreference, favorites([1, 2]));
      a.capture(sitesPreference, sites(token: 'secret'));
      final b = SyncState('b')..merge(a.records);
      a.capture(favoritesPreference, favorites([2]));
      a.capture(sitesPreference, '[]');
      final offline = b.records;
      b.merge(a.records);
      a.merge(offline);
      expect(a.readPreference(sitesPreference), '[]');
      expect(b.readPreference(sitesPreference), '[]');
      expect(
        (jsonDecode(b.readPreference(favoritesPreference) as String) as List)
            .single['id'],
        2,
      );
      b.capture(sitesPreference, sites(token: 'secret'));
      a.merge(b.records);
      expect(
        jsonDecode(a.readPreference(sitesPreference) as String),
        hasLength(1),
      );
    });

    test(
      'fresh presets do not erase credentials; ordering and history touches persist',
      () {
        final a = SyncState('a')
          ..capture(
            sitesPreference,
            sites(token: 'secret', username: 'login'),
            seed: true,
          );
        final fresh = SyncState('z')
          ..capture(sitesPreference, sites(), seed: true);
        a.merge(fresh.records);
        expect(
          (jsonDecode(a.readPreference(sitesPreference) as String) as List)
              .single['token'],
          'secret',
        );
        a.capture(historyPreference, ['first', 'second', 'third'], seed: true);
        expect(a.readPreference(historyPreference), [
          'first',
          'second',
          'third',
        ]);
        a.capture(historyPreference, ['third', 'first', 'second']);
        expect((a.readPreference(historyPreference) as List).first, 'third');
        a.capture(favoritesPreference, favorites([9, 8, 7]), seed: true);
        expect(
          (jsonDecode(a.readPreference(favoritesPreference) as String) as List)
              .map((p) => p['id']),
          [9, 8, 7],
        );
      },
    );

    test('equal-version conflicts converge and invalid input is atomic', () {
      final a = SyncState('a');
      final low = SyncEntry('setting/flex_amoled', true, 12, 'a').toJson();
      final high = SyncEntry('setting/flex_amoled', false, 12, 'b').toJson();
      a.merge([high, low]);
      expect(a.readPreference('flex_amoled'), false);
      expect(
        () => a.merge([
          SyncEntry('setting/flex_columns', 2, 15, 'b').toJson(),
          SyncEntry('setting/flex_download_path', 'C:/files', 16, 'b').toJson(),
        ]),
        throwsFormatException,
      );
      expect(a.readPreference('flex_columns'), isNull);
      expect(a.capture('flex_download_path', 'D:/pictures'), false);
      expect(a.capture('tag_db_revision', '1'), false);
      expect(
        () => a.capture(
          sitesPreference,
          sites().replaceFirst('"type":0', '"type":999'),
        ),
        throwsFormatException,
      );
      expect(a.readPreference(sitesPreference), '[]');
    });
  });

  group('encryption', () {
    test(
      'frames are confidential, bidirectional, session-bound and replay-safe',
      () async {
        final key = randomSyncKey();
        final a = await SyncCipher.create(key, 'session-1', server: true);
        final b = await SyncCipher.create(key, 'session-1', server: false);
        final frame = await a.encode({'token': 'secret-login'});
        expect(frame, isNot(contains('secret-login')));
        expect(await b.decode(frame), {'token': 'secret-login'});
        await expectLater(b.decode(frame), throwsFormatException);
        expect(await a.decode(await b.encode({'reply': true})), {
          'reply': true,
        });
        final wrongSession = await SyncCipher.create(
          key,
          'session-2',
          server: false,
        );
        await expectLater(
          wrongSession.decode(frame),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        final next = await a.encode({'next': 1});
        final tampered = (jsonDecode(next) as Map).cast<String, dynamic>();
        tampered['mac'] = base64UrlEncode(List.filled(16, 0));
        await expectLater(
          b.decode(jsonEncode(tampered)),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        expect(await b.decode(next), {'next': 1});
      },
    );

    test(
      'journal is encrypted and missing keys never replace existing data',
      () async {
        final prefs = await preferences({});
        String? storedKey;
        final vault = EncryptedSyncPersistence(
          prefs,
          readKey: () async => storedKey,
          writeKey: (value) async => storedKey = value,
        );
        await vault.save({
          'token': 'private-secret',
          'trusted': 'private-pair-key',
        });
        final encrypted = prefs.getString(EncryptedSyncPersistence.journalKey)!;
        expect(encrypted, isNot(contains('private-secret')));
        expect(encrypted, isNot(contains(storedKey!)));
        expect(await vault.load(), {
          'token': 'private-secret',
          'trusted': 'private-pair-key',
        });
        final missing = EncryptedSyncPersistence(
          prefs,
          readKey: () async => null,
          writeKey: (_) async => fail('Must not reset key'),
        );
        await expectLater(missing.load(), throwsStateError);
        expect(prefs.getString(EncryptedSyncPersistence.journalKey), encrypted);
      },
    );

    test(
      'migration removes plaintext logins and failed persistence does not broadcast edits',
      () async {
        final prefs = await preferences({
          sitesPreference: sites(token: 'private-secret', username: 'login'),
          'flex_download_path': 'D:/downloads',
        });
        final memory = MemoryPersistence();
        final sync = LanSyncService(preferences: prefs, persistence: memory);
        addTearDown(sync.shutdown);
        await sync.initialize();
        expect(
          prefs.getString(sitesPreference),
          isNot(contains('private-secret')),
        );
        expect(
          (await SyncPreferences.getInstance()).getString(sitesPreference),
          contains('private-secret'),
        );
        expect(sync.records.toString(), isNot(contains('D:/downloads')));
        memory.fail = true;
        final before = sync.records.toString();
        await expectLater(
          sync.updatePreference('flex_amoled', true),
          throwsStateError,
        );
        expect(sync.records.toString(), before);
        expect(prefs.getBool('flex_amoled'), isNull);
      },
    );
  });

  group('real WebSocket transport', () {
    HttpOverrides? previous;
    LanSyncService? host;
    LanSyncService? phone;
    setUp(() {
      previous = HttpOverrides.current;
      HttpOverrides.global = null;
    });
    tearDown(() async {
      await phone?.shutdown();
      await host?.shutdown();
      phone = null;
      host = null;
      HttpOverrides.global = previous;
    });

    test(
      'approval gates data, live edits sync, offline edits catch up, trust survives restart',
      () async {
        final hostPrefs = await preferences({
          sitesPreference: sites(token: 'windows-secret', username: 'user'),
          favoritesPreference: favorites([1]),
          'flex_download_path': 'D:/windows-downloads',
        });
        final phonePrefs = await preferences({
          sitesPreference: sites(),
          favoritesPreference: favorites(['phone-id']),
          'flex_download_path': '/phone/downloads',
        });
        final hostVault = MemoryPersistence();
        final phoneVault = MemoryPersistence();
        host = LanSyncService(
          preferences: hostPrefs,
          persistence: hostVault,
          attachToApp: false,
        );
        phone = LanSyncService(
          preferences: phonePrefs,
          persistence: phoneVault,
          attachToApp: false,
        );
        await host!.startHost(
          listenPort: 0,
          address: InternetAddress.loopbackIPv4,
        );
        await phone!.pair(host!.pairingLink('127.0.0.1'));
        await eventually(
          () => host!.pending.length == 1 && phone!.status == 'approval',
        );
        expect(phone!.records.toString(), isNot(contains('windows-secret')));
        expect(phone!.isConnected, false);
        final invitation = host!.pairingLink('127.0.0.1');
        await host!.approve(host!.pending.single);
        await eventually(
          () =>
              phone!.isConnected &&
              phone!.records.toString().contains('windows-secret') &&
              (jsonDecode(hostPrefs.getString(favoritesPreference)!) as List)
                      .length ==
                  2,
        );
        expect(host!.pairingLink('127.0.0.1'), isNot(invitation));
        expect(
          hostPrefs.getString(sitesPreference),
          isNot(contains('windows-secret')),
        );
        expect(
          phonePrefs.getString(sitesPreference),
          isNot(contains('windows-secret')),
        );
        expect(
          hostPrefs.getString('flex_download_path'),
          'D:/windows-downloads',
        );
        expect(phonePrefs.getString('flex_download_path'), '/phone/downloads');
        await phone!.updatePreference(blacklistPreference, ['from_phone']);
        await eventually(
          () =>
              hostPrefs
                  .getStringList(blacklistPreference)
                  ?.contains('from_phone') ==
              true,
        );
        await host!.updatePreference('flex_theme_mode', 'dark');
        await eventually(
          () => phonePrefs.getString('flex_theme_mode') == 'dark',
        );
        await phone!.pauseClient(true);
        await eventually(() => !host!.isConnected);
        await phone!.updatePreference(historyPreference, ['offline search']);
        await host!.updatePreference('flex_columns', 4);
        await phone!.pauseClient(false);
        await eventually(
          () =>
              phonePrefs.getInt('flex_columns') == 4 &&
              hostPrefs.getStringList(historyPreference)?.first ==
                  'offline search',
        );
        await host!.updatePreference(favoritesPreference, favorites([1]));
        await eventually(
          () =>
              (jsonDecode(phonePrefs.getString(favoritesPreference)!) as List)
                  .length ==
              1,
        );
        await phone!.shutdown();
        phone = LanSyncService(
          preferences: phonePrefs,
          persistence: phoneVault,
          attachToApp: false,
        );
        await phone!.resumeSavedMode();
        await eventually(() => phone!.isConnected);
        expect(host!.pending, isEmpty);
        await host!.revoke(phone!.deviceId);
        await eventually(() => !phone!.isConnected);
        await phone!.reconnect();
        await eventually(
          () =>
              phone!.error == 'auth' ||
              phone!.error == 'rejected' ||
              phone!.status == 'waiting',
        );
        expect(phone!.isConnected, false);
        expect(host!.trustedDevices, isEmpty);
      },
    );

    test(
      'wrong pairing keys cannot read data or create approval requests',
      () async {
        host = LanSyncService(
          preferences: await preferences({
            sitesPreference: sites(token: 'hidden'),
          }),
          persistence: MemoryPersistence(),
          attachToApp: false,
        );
        phone = LanSyncService(
          preferences: await preferences({}),
          persistence: MemoryPersistence(),
          attachToApp: false,
        );
        await host!.startHost(
          listenPort: 0,
          address: InternetAddress.loopbackIPv4,
        );
        final uri = Uri.parse(host!.pairingLink('127.0.0.1'));
        await phone!.pair(
          uri
              .replace(
                queryParameters: {
                  ...uri.queryParameters,
                  'key': randomSyncKey(),
                },
              )
              .toString(),
        );
        await eventually(() => phone!.status == 'waiting');
        expect(host!.pending, isEmpty);
        expect(phone!.records.toString(), isNot(contains('hidden')));
        expect(
          () => LanSyncService.parsePairingLink(
            uri
                .replace(
                  queryParameters: {...uri.queryParameters, 'host': '8.8.8.8'},
                )
                .toString(),
          ),
          throwsFormatException,
        );
        expect(
          () => LanSyncService.parsePairingLink(
            uri
                .replace(
                  queryParameters: {
                    ...uri.queryParameters,
                    'host': 'example.org',
                  },
                )
                .toString(),
          ),
          throwsFormatException,
        );
      },
    );
  });
}
