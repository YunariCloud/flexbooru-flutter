import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/models/browse_session.dart';
import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/ui/widgets/post_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

void main() {
  testWidgets('long galleries release old zoom controllers', (tester) async {
    final site = BooruSite(
      id: 'site',
      name: 'Site',
      host: 'example.invalid',
      type: BooruType.danbooru,
    );
    final source = BrowseSource.fixed(
      List.generate(
        35,
        (index) => GalleryEntry(
          Post(
            id: index + 1,
            booruId: 'site',
            width: 100,
            height: 100,
            rating: 'g',
            tags: [],
            tagString: '',
            previewUrl: 'https://example.invalid/$index.jpg',
            sampleUrl: 'https://example.invalid/$index.jpg',
            originUrl: 'https://example.invalid/$index.jpg',
          ),
          site,
        ),
      ),
    );
    final pages = PageController();
    var index = 0, disposed = 0;
    final observed = <PhotoViewScaleStateController>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => PostGalleryViewer(
              source: source,
              controller: pages,
              index: index,
              quality: 'sample',
              onChanged: (value) => set(() => index = value),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      pages.jumpToPage(i);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      final controller = gallery
          .builder!(tester.element(find.byType(PhotoViewGallery)), i)
          .scaleStateController!;
      if (observed.add(controller)) {
        controller.outputScaleStateStream.listen(
          (_) {},
          onDone: () => disposed++,
        );
      }
    }
    expect(observed.length - disposed, lessThanOrEqualTo(5));
    await tester.pumpWidget(const SizedBox());
    pages.dispose();
    source.dispose();
  });
  testWidgets(
    'retry reloads the current image without returning to the first page',
    (tester) async {
      final site = BooruSite(
        id: 'site',
        name: 'Site',
        host: 'example.invalid',
        type: 0,
      );
      final source = BrowseSource.fixed(
        List.generate(
          15,
          (i) => GalleryEntry(
            Post(
              id: i,
              booruId: 'site',
              width: 100,
              height: 100,
              rating: 'g',
              tags: [],
              tagString: '',
              previewUrl: 'https://example.invalid/$i.jpg',
              sampleUrl: 'https://example.invalid/$i.jpg',
              originUrl: '',
            ),
            site,
          ),
        ),
      );
      final pages = PageController();
      var index = 0, evictions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => PostGalleryViewer(
                source: source,
                controller: pages,
                index: index,
                quality: 'sample',
                onChanged: (value) => set(() => index = value),
                onTap: () {},
                evictImage: (url, key) async {
                  expect(url, 'https://example.invalid/12.jpg');
                  evictions++;
                },
              ),
            ),
          ),
        ),
      );
      pages.jumpToPage(12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      final error =
          gallery
                  .builder!(tester.element(find.byType(PhotoViewGallery)), 12)
                  .errorBuilder!(
                tester.element(find.byType(PhotoViewGallery)),
                StateError('load failed'),
                StackTrace.current,
              )
              as Center;
      (error.child as Column).children
          .whereType<TextButton>()
          .single
          .onPressed!();
      await tester.pump();
      await tester.pump();
      expect(evictions, 1);
      expect(pages.page, 12);
      expect(index, 12);
      await tester.pumpWidget(const SizedBox());
      pages.dispose();
      source.dispose();
    },
  );
}
