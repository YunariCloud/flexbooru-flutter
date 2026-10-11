import 'package:cached_network_image/cached_network_image.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/providers/favorites_provider.dart';
import 'package:flexbooru/providers/settings_provider.dart';
import 'package:flexbooru/services/tag_translation_service.dart';
import 'package:flexbooru/ui/screens/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final site = BooruSite(
    id: 'test',
    name: 'Test',
    host: 'danbooru.donmai.us',
    type: BooruType.danbooru,
  );
  Post post({
    String original = 'https://example.invalid/original.jpg',
    String preview = 'https://example.invalid/preview.jpg',
  }) => Post(
    id: 1,
    booruId: 'test',
    width: 100,
    height: 100,
    rating: 'g',
    tags: [],
    tagString: '',
    previewUrl: preview,
    sampleUrl: 'https://example.invalid/sample.jpg',
    originUrl: original,
  );

  String imageUrl(WidgetTester tester) =>
      (tester.widget<PhotoView>(find.byType(PhotoView)).imageProvider
              as CachedNetworkImageProvider)
          .url;

  for (final quality in ['preview', 'sample', 'original']) {
    testWidgets(
      'detail starts with saved $quality quality and permits manual switching',
      (tester) async {
        SharedPreferences.setMockInitialValues({'flex_image_quality': quality});
        final settings = SettingsProvider();
        await settings.ready;
        TagTranslationService().setCustomDbPath(':memory:');
        await tester.runAsync(() => TagTranslationService().init());
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ],
            child: MaterialApp(
              home: PostDetailScreen(initialPost: post(), site: site),
            ),
          ),
        );
        expect(imageUrl(tester), 'https://example.invalid/$quality.jpg');
        await tester.tap(find.byType(TextButton));
        await tester.pump();
        expect(
          imageUrl(tester),
          quality == 'original'
              ? 'https://example.invalid/sample.jpg'
              : 'https://example.invalid/original.jpg',
        );
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
        TagTranslationService().setCustomDbPath(null);
      },
    );
  }

  testWidgets('missing preferred original falls back to a sample image', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'flex_image_quality': 'original'});
    final settings = SettingsProvider();
    await settings.ready;
    TagTranslationService().setCustomDbPath(':memory:');
    await tester.runAsync(() => TagTranslationService().init());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ],
        child: MaterialApp(
          home: PostDetailScreen(
            initialPost: post(original: ''),
            site: site,
          ),
        ),
      ),
    );
    expect(imageUrl(tester), 'https://example.invalid/sample.jpg');
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    TagTranslationService().setCustomDbPath(null);
  });
}
