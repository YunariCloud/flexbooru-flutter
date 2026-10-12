import 'package:flexbooru/models/post.dart';
import 'package:flexbooru/services/search_store.dart';
import 'package:flexbooru/ui/screens/reverse_search_settings_screen.dart';
import 'package:flexbooru/ui/widgets/reverse_image_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('engine settings retain one engine and persist disabled order', (
    tester,
  ) async {
    final store = SearchStore();
    await store.ready;
    await store.setEngines(['google']);
    await tester.pumpWidget(
      const MaterialApp(home: ReverseSearchSettingsScreen()),
    );
    await flush(tester);
    tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).onChanged!(
      false,
    );
    await tester.pump();
    expect(find.text('至少启用一个引擎'), findsOneWidget);
    final reorder = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorder.onReorder(5, 0);
    await flush(tester);
    await store.reload();
    expect(store.engineIds, ['google']);
    expect(store.engineOrder.first, 'iqdb');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'batch opens in order, failures provide a copyable URL without credentials',
    (tester) async {
      final store = SearchStore();
      await store.ready;
      await store.setEngines(['iqdb', 'google']);
      final calls = <Map<dynamic, dynamic>>[];
      var succeeds = true;
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          if (call.method == 'launch') calls.add(call.arguments as Map);
          return succeeds;
        },
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final post = Post(
        id: 1,
        booruId: 'site',
        width: 100,
        height: 100,
        rating: 'g',
        tags: [],
        tagString: '',
        originUrl: '',
        previewUrl: '',
        sampleUrl: 'https://example.invalid/a b.jpg?x=1&y=中文',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showReverseImageSearch(context, post),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await flush(tester);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('使用全部已启用引擎'));
      await flush(tester);
      expect(calls.length, 2);
      expect(Uri.parse(calls[0]['url'] as String).host, 'iqdb.org');
      expect(Uri.parse(calls[1]['url'] as String).host, 'lens.google.com');
      expect(
        Uri.parse(calls[0]['url'] as String).queryParameters['url'],
        post.sampleUrl,
      );
      expect(
        calls.every(
          (c) => (c['headers'] as Map).isEmpty && c['useWebView'] == false,
        ),
        isTrue,
      );
      succeeds = false;
      await tester.tap(find.text('IQDB'));
      await flush(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('无法打开 IQDB'), findsOneWidget);
      await tester.tap(find.text('复制链接'));
      await flush(tester);
      expect(copied, calls.last['url']);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
