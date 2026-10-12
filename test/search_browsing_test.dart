import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/core/sync/sync_preferences.dart';
import 'package:flexbooru/models/search_state.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/models/browse_session.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/providers/favorites_provider.dart';
import 'package:flexbooru/providers/posts_provider.dart';
import 'package:flexbooru/providers/settings_provider.dart';
import 'package:flexbooru/services/search_store.dart';
import 'package:flexbooru/services/tag_translation_service.dart';
import 'package:flexbooru/ui/screens/post_detail_screen.dart';
import 'package:flexbooru/ui/screens/search_screen.dart';
import 'package:flexbooru/ui/widgets/post_grid_item.dart';
import 'package:flexbooru/ui/widgets/post_image_viewer.dart';
import 'package:flexbooru/ui/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/mock_http_adapter.dart';

void main() {
  final site = BooruSite(
    id: 'test',
    name: 'Test',
    host: 'danbooru.donmai.us',
    type: BooruType.danbooru,
  );
  final other = BooruSite(
    id: 'other',
    name: 'Other',
    host: 'e621.net',
    type: BooruType.danbooru,
  );
  Post post(int id, String siteId) => Post(
    id: id,
    booruId: siteId,
    width: 100,
    height: 100,
    rating: 'g',
    tags: [],
    tagString: '',
    previewUrl: 'https://example.invalid/$id.jpg',
    sampleUrl: 'https://example.invalid/$id.jpg',
    originUrl: 'https://example.invalid/$id-original.jpg',
  );
  late HttpClientAdapter adapter;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = ApiClient().dio.httpClientAdapter;
  });
  tearDown(() => ApiClient().dio.httpClientAdapter = adapter);
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('restores draft without search; rapid filters debounce once', (
    tester,
  ) async {
    final store = SearchStore();
    await store.ready;
    await store.saveDraft(site.id, 'hero order:score');
    await store.setAutoSearch(true);
    final queries = <String>[];
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((request) {
      if (request.path.contains('posts')) {
        queries.add('${request.queryParameters['tags']}');
      }
      return jsonResponse([]);
    });
    await tester.pumpWidget(MaterialApp(home: SearchScreen(site: site)));
    await flush(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'hero order:score',
    );
    expect(queries, isEmpty);
    final filters = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .toList();
    filters[0].onSelected!(true);
    await tester.pump(const Duration(milliseconds: 150));
    tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .elementAt(3)
        .onSelected!(true);
    await tester.pump(const Duration(milliseconds: 299));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await flush(tester);
    expect(queries.length, 1);
    expect(queries.single, contains('order:id_desc'));
    expect(queries.single, isNot(contains('order:score')));
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    store.dispose();
  });

  testWidgets('e621 retains free query but hides Danbooru shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SearchScreen(site: other)));
    await flush(tester);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'remote draft is deferred until reopening and does not clobber editing',
    (tester) async {
      final store = SearchStore();
      await store.ready;
      await store.saveDraft(site.id, 'local');
      await tester.pumpWidget(MaterialApp(home: SearchScreen(site: site)));
      await flush(tester);
      await store.saveDraft(site.id, 'remote');
      SyncPreferences.remoteChanges.add({searchPreference});
      await flush(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'local',
      );
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
      await tester.pumpWidget(MaterialApp(home: SearchScreen(site: site)));
      await flush(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'remote',
      );
      await tester.enterText(find.byType(TextField), 'editing');
      await tester.pump(const Duration(milliseconds: 200));
      await flush(tester);
      final update = store.saveDraft(site.id, 'new remote');
      await flush(tester);
      await update;
      SyncPreferences.remoteChanges.add({searchPreference});
      await flush(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'editing',
      );
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
      await store.reload();
      expect(store.draft(site.id), 'new remote');
      store.dispose();
    },
  );

  test(
    'browse pagination deduplicates and stops after source query changes',
    () async {
      var calls = 0;
      ApiClient().dio.httpClientAdapter = MockHttpAdapter((_) {
        calls++;
        return jsonResponse(
          List.generate(20, (i) => postJson(calls == 1 ? i + 1 : i + 20)),
        );
      });
      final provider = PostsProvider();
      await provider.fetchPosts(site: site, query: 'original', refresh: true);
      final source = BrowseSource.posts(
        provider,
        site,
        () => provider.fetchPosts(site: site),
      );
      await Future.wait([source.loadNext(), source.loadNext()]);
      expect(calls, 2);
      expect(source.entries.length, 39);
      await provider.fetchPosts(site: site, query: 'changed', refresh: true);
      expect(source.entries.length, 39);
      expect(source.hasMore, isFalse);
      await source.loadNext();
      expect(calls, 3);
      source.dispose();
      provider.dispose();
    },
  );

  testWidgets(
    'gallery zoom, keys, fullscreen and cross-site download remain coherent',
    (tester) async {
      final settings = SettingsProvider();
      await settings.ready;
      final favorites = FavoritesProvider();
      TagTranslationService().setCustomDbPath(':memory:');
      await tester.runAsync(() => TagTranslationService().init());
      final pending = Completer<String?>();
      Post? captured;
      BooruSite? capturedSite;
      late void Function(int, int) progress;
      final source = BrowseSource.fixed([
        GalleryEntry(post(1, site.id), site),
        GalleryEntry(post(2, other.id), other),
        GalleryEntry(post(3, 'removed'), null),
      ]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: favorites),
          ],
          child: MaterialApp(
            home: PostDetailScreen(
              initialPost: post(1, site.id),
              site: site,
              source: source,
              downloader: (p, s, callback) {
                captured = p;
                capturedSite = s;
                progress = callback;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await flush(tester);
      tester
          .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
          .scaleStateChangedCallback!(PhotoViewScaleState.covering);
      await tester.pump();
      expect(
        tester
            .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
            .scrollPhysics,
        isA<NeverScrollableScrollPhysics>(),
      );
      tester
          .widget<PhotoViewGallery>(find.byType(PhotoViewGallery))
          .scaleStateChangedCallback!(PhotoViewScaleState.initial);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.download));
      expect(captured!.id, 1);
      expect(capturedSite!.id, site.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('#2 (Other)'), findsOneWidget);
      progress(50, 100);
      await tester.pump();
      expect(find.byType(DownloadProgressOverlay), findsNothing);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await flush(tester);
      expect(favorites.isFavorite(2, other.id), isTrue);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      tester.widget<PostGalleryViewer>(find.byType(PostGalleryViewer)).onTap();
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();
      expect(find.text('#2 (Other)'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('原站点已删除'), findsOneWidget);
      final comments = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.comment_outlined),
      );
      expect(comments.onPressed, isNull);
      pending.complete('saved.jpg');
      await flush(tester);
      expect(find.text('#3 (已删除的站点)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      favorites.dispose();
      TagTranslationService().setCustomDbPath(null);
    },
  );

  testWidgets(
    'tag search pushes a session; returning preserves original results and scroll',
    (tester) async {
      final settings = SettingsProvider();
      await settings.ready;
      final favorites = FavoritesProvider();
      final root = PostsProvider();
      ApiClient().dio.httpClientAdapter = MockHttpAdapter((request) {
        if (!request.path.contains('posts')) return jsonResponse([]);
        final query = '${request.queryParameters['tags']}';
        return jsonResponse(
          List.generate(
            20,
            (i) => {
              ...postJson(
                query.contains('hero_tag') ? 100 + i : i + 1,
                tag: 'hero_tag',
              ),
              'preview_file_url': 'https://example.invalid/image.jpg',
              'large_file_url': 'https://example.invalid/image.jpg',
            },
          ),
        );
      });
      await tester.runAsync(
        () => root.fetchPosts(site: site, query: 'root', refresh: true),
      );
      TagTranslationService().setCustomDbPath(':memory:');
      await tester.runAsync(() => TagTranslationService().init());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: favorites),
            ChangeNotifierProvider.value(value: root),
          ],
          child: MaterialApp(
            home: SearchScreen(
              site: site,
              initialQuery: 'original',
              executeInitially: true,
            ),
          ),
        ),
      );
      await flush(tester);
      final originalScreen = tester.state(find.byType(SearchScreen));
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
      await tester.pump();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      await tester.tap(find.byType(PostGridItem).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final chip = tester.widget<TagChip>(find.byType(TagChip).first);
      expect(chip.onLongPress, isNotNull);
      chip.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await flush(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'hero_tag',
      );
      expect(root.currentQuery, 'root');
      await tester.tap(find.byType(PostGridItem).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // The original details panel is still above its image route.
      expect(find.byType(TagChip), findsWidgets);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.state(find.byType(SearchScreen)), same(originalScreen));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'original',
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .pixels,
        scroll,
      );
      expect(root.currentQuery, 'root');
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
      root.dispose();
      settings.dispose();
      favorites.dispose();
      TagTranslationService().setCustomDbPath(null);
    },
  );
}
