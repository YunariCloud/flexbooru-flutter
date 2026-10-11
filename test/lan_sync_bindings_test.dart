import 'dart:convert';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/core/sync/sync_preferences.dart';
import 'package:flexbooru/core/sync/sync_state.dart';
import 'package:flexbooru/main.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/providers/booru_provider.dart';
import 'package:flexbooru/providers/favorites_provider.dart';
import 'package:flexbooru/providers/posts_provider.dart';
import 'package:flexbooru/providers/settings_provider.dart';
import 'package:flexbooru/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/mock_http_adapter.dart';

void main() {
  testWidgets(
    'remote changes reload app models, retain browsing query and clear deleted sites',
    (tester) async {
      final site = BooruSite(
        id: 'site',
        name: 'Site',
        host: 'example.org',
        type: 0,
      );
      SharedPreferences.setMockInitialValues({
        sitesPreference: jsonEncode([site.toJson()]),
        'flex_auto_check_update': false,
        'flex_download_path': 'D:/local-only',
      });
      final original = ApiClient().dio.httpClientAdapter;
      ApiClient().dio.httpClientAdapter = MockHttpAdapter(
        (request) =>
            jsonResponse(List.generate(12, (index) => postJson(index + 1))),
      );
      addTearDown(() {
        ApiClient().dio.httpClientAdapter = original;
        ApiClient().setUserAgent(AppConstants.defaultUserAgent);
      });
      await tester.pumpWidget(const FlexbooruApp());
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      final context = tester.element(find.byType(HomeScreen));
      final booru = context.read<BooruProvider>();
      final posts = context.read<PostsProvider>();
      final favorites = context.read<FavoritesProvider>();
      final settings = context.read<SettingsProvider>();
      final fetching = posts.fetchPosts(
        site: site,
        query: 'keep_this_query',
        refresh: true,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await fetching;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        sitesPreference,
        jsonEncode([
          site
              .copyWith(token: 'remote-token', username: 'remote-user')
              .toJson(),
        ]),
      );
      await prefs.setString(
        favoritesPreference,
        jsonEncode([posts.posts.first.toJson()]),
      );
      await prefs.setString('flex_theme_mode', 'dark');
      await prefs.setBool('flex_safe_mode', false);
      SyncPreferences.remoteChanges.add({
        sitesPreference,
        favoritesPreference,
        'flex_theme_mode',
        'flex_safe_mode',
      });
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(booru.activeSite!.token, 'remote-token');
      expect(booru.activeSite!.username, 'remote-user');
      expect(favorites.favorites, hasLength(1));
      expect(settings.themeMode, ThemeMode.dark);
      expect(posts.safeMode, false);
      expect(posts.currentQuery, 'keep_this_query');
      expect(settings.downloadPath, 'D:/local-only');
      // Saving an old open form must preserve credentials received since it opened.
      await booru.updateSite(site.copyWith(name: 'Local name'), original: site);
      expect(booru.activeSite!.token, 'remote-token');
      expect(booru.activeSite!.name, 'Local name');
      await prefs.setString(sitesPreference, '[]');
      SyncPreferences.remoteChanges.add({sitesPreference});
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(booru.sites, isEmpty);
      expect(booru.activeSite, isNull);
      expect(posts.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
