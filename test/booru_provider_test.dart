import 'dart:async';
import 'dart:convert';

import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/providers/booru_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<BooruProvider> _loadProvider() async {
  final provider = BooruProvider();
  final loaded = Completer<void>();
  void listener() {
    if (!provider.isLoading && !loaded.isCompleted) loaded.complete();
  }

  provider.addListener(listener);
  await loaded.future;
  provider.removeListener(listener);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default presets exclude Lolibooru', () {
    expect(BooruSite.defaultPresets.any((site) => site.isRetiredPreset), false);
    expect(
      BooruSite.defaultPresets.any((site) => site.id == 'lolibooru'),
      false,
    );
  });

  test(
    'saved Lolibooru is removed and active site migrates without losing credentials',
    () async {
      final retired = BooruSite(
        id: 'lolibooru',
        name: 'Lolibooru',
        host: 'lolibooru.moe',
        type: BooruType.moebooru,
      );
      final retained = BooruSite(
        id: 'custom',
        name: 'Custom',
        host: 'custom.example',
        type: BooruType.gelbooru,
        username: '123',
        token: 'key',
      );
      SharedPreferences.setMockInitialValues({
        'flexbooru_sites': jsonEncode([retired.toJson(), retained.toJson()]),
        'flexbooru_active_site_id': retired.id,
      });
      final provider = await _loadProvider();
      expect(provider.sites.single.id, 'custom');
      expect(provider.sites.single.token, 'key');
      expect(provider.activeSite?.id, 'custom');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('flexbooru_active_site_id'), 'custom');
      final saved = jsonDecode(prefs.getString('flexbooru_sites')!) as List;
      expect(saved.single['host'], 'custom.example');
      provider.dispose();
    },
  );

  test(
    'only retired sites fall back to defaults and persist a valid selection',
    () async {
      final retired = BooruSite(
        id: 'old',
        name: 'Old',
        host: 'WWW.LOLIBOORU.MOE',
        type: BooruType.moebooru,
      );
      SharedPreferences.setMockInitialValues({
        'flexbooru_sites': jsonEncode([retired.toJson()]),
        'flexbooru_active_site_id': retired.id,
      });
      final provider = await _loadProvider();
      expect(provider.sites, isNotEmpty);
      expect(provider.sites.any((site) => site.isRetiredPreset), false);
      expect(provider.activeSite?.id, provider.sites.first.id);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('flexbooru_active_site_id'),
        provider.sites.first.id,
      );
      provider.dispose();
    },
  );
}
