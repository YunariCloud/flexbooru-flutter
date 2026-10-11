import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/providers/posts_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final site = BooruSite(
    id: 'test',
    name: 'Test',
    host: 'danbooru.donmai.us',
    type: BooruType.danbooru,
  );
  late HttpClientAdapter original;
  late PostsProvider provider;

  setUp(() {
    original = ApiClient().dio.httpClientAdapter;
    provider = PostsProvider();
  });
  tearDown(() {
    provider.dispose();
    ApiClient().dio.httpClientAdapter = original;
  });

  test('viewport filling holds the load lock and never skips a page', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final pages = <int>[];
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) async {
      final page = options.queryParameters['page'] as int;
      pages.add(page);
      if (page == 1) return jsonResponse([postJson(1)]);
      if (page == 2) {
        started.complete();
        await release.future;
        return jsonResponse(List.generate(12, (i) => postJson(i + 2)));
      }
      return jsonResponse([]);
    });
    final initial = provider.fetchPosts(site: site, refresh: true);
    await started.future;
    expect(provider.isLoadingMore, isTrue);
    await provider.fetchPosts(site: site);
    expect(pages, [1, 2]);
    release.complete();
    await initial;
    expect(provider.currentPage, 3);
    await provider.fetchPosts(site: site);
    expect(pages, [1, 2, 3]);
    expect(provider.posts.length, 13);
    expect(provider.hasMore, isFalse);
  });

  test('a fully unsafe page does not hide later safe search results', () async {
    final pages = <int>[];
    provider.setSafeMode(true);
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) {
      expect(options.queryParameters['tags'], 'cat dog');
      final page = options.queryParameters['page'] as int;
      pages.add(page);
      return jsonResponse(
        List.generate(
          12,
          (i) => postJson(page * 20 + i, rating: page == 1 ? 'e' : 'g'),
        ),
      );
    });
    await provider.fetchPosts(site: site, query: 'cat dog', refresh: true);
    expect(pages, [1, 2]);
    expect(provider.posts.length, 12);
    expect(provider.posts.every((p) => p.isSafe), isTrue);
  });

  test('popular paging also survives fully filtered pages', () async {
    final pages = <int>[];
    provider.setSafeMode(true);
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) {
      final page = options.queryParameters['page'] as int;
      pages.add(page);
      return jsonResponse(
        List.generate(
          12,
          (i) => postJson(page * 20 + i, rating: page == 1 ? 'e' : 'g'),
        ),
      );
    });
    await provider.fetchPopular(site: site, refresh: true);
    expect(pages, [1, 2]);
    expect(provider.posts.length, 12);
  });

  test(
    'scanning is bounded and a later load continues after filtered pages',
    () async {
      final pages = <int>[];
      provider.setBlacklist(['blocked']);
      ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) {
        final page = options.queryParameters['page'] as int;
        pages.add(page);
        return jsonResponse(
          List.generate(
            12,
            (i) => postJson(page * 20 + i, tag: page <= 4 ? 'blocked' : 'solo'),
          ),
        );
      });
      await provider.fetchPosts(site: site, refresh: true);
      expect(pages, [1, 2, 3, 4]);
      expect(provider.posts, isEmpty);
      expect(provider.hasMore, isTrue);
      await provider.fetchPosts(site: site);
      expect(pages.last, 5);
      expect(provider.posts.length, 12);
    },
  );

  test(
    'blacklist changes immediately refilter and restore loaded posts',
    () async {
      ApiClient().dio.httpClientAdapter = MockHttpAdapter(
        (_) => jsonResponse(List.generate(12, (i) => postJson(i + 1))),
      );
      await provider.fetchPosts(site: site, refresh: true);
      final blacklist = [' SOLO '];
      provider.setBlacklist(blacklist);
      blacklist.clear();
      expect(provider.posts, isEmpty);
      provider.setBlacklist([]);
      expect(provider.posts.length, 12);
    },
  );

  test('a stale response cannot replace a newer search', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) async {
      if (options.queryParameters['tags'] == 'old') {
        started.complete();
        await release.future;
        return jsonResponse([postJson(1)]);
      }
      return jsonResponse(List.generate(12, (i) => postJson(i + 20)));
    });
    final old = provider.fetchPosts(site: site, query: 'old', refresh: true);
    await started.future;
    await provider.fetchPosts(site: site, query: 'new', refresh: true);
    release.complete();
    await old;
    expect(provider.currentQuery, 'new');
    expect(provider.posts.first.id, 20);
    expect(provider.currentPage, 2);
  });

  test('failed automatic page preserves posts and retries that page', () async {
    var failing = true;
    final pages = <int>[];
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((options) {
      final page = options.queryParameters['page'] as int;
      pages.add(page);
      if (page == 1) return jsonResponse([postJson(1)]);
      if (failing) return jsonResponse({'message': 'unavailable'}, status: 500);
      return jsonResponse(List.generate(12, (i) => postJson(i + 2)));
    });
    await provider.fetchPosts(site: site, refresh: true);
    expect(provider.posts.length, 1);
    expect(provider.failure, isNotNull);
    expect(provider.currentPage, 2);
    failing = false;
    await provider.fetchPosts(site: site);
    expect(pages, [1, 2, 2]);
    expect(provider.failure, isNull);
  });
}
