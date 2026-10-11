import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/main.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/providers/blacklist_provider.dart';
import 'package:flexbooru/providers/posts_provider.dart';
import 'package:flexbooru/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/mock_http_adapter.dart';

void main() {
  testWidgets(
    'first request uses saved settings and blacklist; edits refilter immediately',
    (tester) async {
      final site = BooruSite(
        id: 'saved',
        name: 'Saved',
        host: 'danbooru.donmai.us',
        type: BooruType.danbooru,
      );
      SharedPreferences.setMockInitialValues({
        'flexbooru_sites': jsonEncode([site.toJson()]),
        'flexbooru_active_site_id': site.id,
        'flexbooru_global_blacklist': ['blocked'],
        'flex_safe_mode': false,
        'flex_user_agent': 'SavedClient/1.0',
        'flex_auto_check_update': false,
      });
      final original = ApiClient().dio.httpClientAdapter;
      final requests = <RequestOptions>[];
      ApiClient().dio.httpClientAdapter = MockHttpAdapter((request) {
        requests.add(request);
        return jsonResponse([
          postJson(1, tag: 'blocked'),
          ...List.generate(
            12,
            (i) => postJson(i + 2, rating: 'e', tag: 'visible'),
          ),
        ]);
      });
      try {
        await tester.pumpWidget(const FlexbooruApp());
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        final context = tester.element(find.byType(HomeScreen));
        final posts = context.read<PostsProvider>();
        expect(requests.length, 1);
        expect(requests.single.headers['User-Agent'], 'SavedClient/1.0');
        expect(requests.single.queryParameters['tags'], isNull);
        expect(posts.safeMode, isFalse);
        expect(posts.posts.length, 12);
        expect(posts.posts.any((post) => post.id == 1), isFalse);
        final blacklist = context.read<BlacklistProvider>();
        await blacklist.addTag('visible');
        expect(posts.posts, isEmpty);
        await blacklist.removeTag('visible');
        expect(posts.posts.length, 12);
        expect(requests.length, 1);
        await tester.pumpWidget(const SizedBox());
      } finally {
        ApiClient().dio.httpClientAdapter = original;
        ApiClient().setUserAgent(AppConstants.defaultUserAgent);
      }
    },
  );
}
