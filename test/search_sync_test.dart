import 'dart:convert';
import 'dart:io';
import 'package:flexbooru/models/search_state.dart';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lan_sync_test.dart'
    show preferences, MemoryPersistence, eventually, sites;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final flags in [(true, true), (true, false), (false, true)]) {
    test(
      'authenticated search capability negotiation host=${flags.$1} client=${flags.$2}',
      () async {
        final oldOverride = HttpOverrides.current;
        HttpOverrides.global = null;
        final initial = jsonEncode([
          const SearchRecord(
            id: 'draft:site',
            kind: 'draft',
            siteId: 'site',
            query: 'solo',
          ).toJson(),
        ]);
        final hp = await preferences({
          sitesPreference: sites(),
          searchPreference: initial,
        });
        final cp = await preferences({sitesPreference: sites()});
        final host = LanSyncService(
          preferences: hp,
          persistence: MemoryPersistence(),
          attachToApp: false,
          supportsSearchState: flags.$1,
        );
        final client = LanSyncService(
          preferences: cp,
          persistence: MemoryPersistence(),
          attachToApp: false,
          supportsSearchState: flags.$2,
        );
        try {
          await host.startHost(
            listenPort: 0,
            address: InternetAddress.loopbackIPv4,
          );
          await client.pair(host.pairingLink('127.0.0.1'));
          await eventually(() => host.pending.length == 1);
          await host.approve(host.pending.single);
          await eventually(() => host.isConnected && client.isConnected);
          await host.updatePreference('flex_image_quality', 'original');
          await eventually(
            () => cp.getString('flex_image_quality') == 'original',
          );
          if (flags.$1 && flags.$2) {
            await eventually(
              () => SearchRecord.decode(
                cp.getString(searchPreference),
              ).isNotEmpty,
            );
            expect(
              SearchRecord.decode(cp.getString(searchPreference)).single.query,
              'solo',
            );
            await client.updatePreference(searchPreference, '[]');
            await eventually(
              () => SearchRecord.decode(hp.getString(searchPreference)).isEmpty,
            );
          } else {
            expect(
              SearchRecord.decode(cp.getString(searchPreference)),
              isEmpty,
            );
          }
          expect(host.isConnected, true);
          expect(client.isConnected, true);
        } finally {
          await client.shutdown();
          await host.shutdown();
          HttpOverrides.global = oldOverride;
        }
      },
    );
  }
}
