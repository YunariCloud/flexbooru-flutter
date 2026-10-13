import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/network/api_client.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/ui/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/mock_http_adapter.dart';

void main() {
  final site = BooruSite(
    id: 'test',
    name: 'Test',
    host: 'danbooru.donmai.us',
    type: BooruType.danbooru,
  );
  late HttpClientAdapter original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = ApiClient().dio.httpClientAdapter;
  });
  tearDown(() => ApiClient().dio.httpClientAdapter = original);
  testWidgets('search conditions fit a narrow screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(home: SearchScreen(site: site)));
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> openSearch(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SearchScreen(site: site)));
    await tester.pump();
  }

  Future<void> flushResponses(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('clearing input cancels a pending debounce request', (
    tester,
  ) async {
    var requests = 0;
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((_) {
      requests++;
      return jsonResponse([]);
    });
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('older tag response cannot replace newer suggestions', (
    tester,
  ) async {
    final old = Completer<ResponseBody>();
    var requests = 0;
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((_) {
      requests++;
      if (requests == 1) return old.future;
      return jsonResponse([
        {'name': 'new_result', 'category': 0, 'post_count': 1},
      ]);
    });
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(requests, 1);
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 300));
    await flushResponses(tester);
    expect(find.text('new_result'), findsOneWidget);
    old.complete(
      jsonResponse([
        {'name': 'old_result', 'category': 0, 'post_count': 1},
      ]),
    );
    await flushResponses(tester);
    expect(find.text('new_result'), findsOneWidget);
    expect(find.text('old_result'), findsNothing);
  });

  testWidgets('clearing input invalidates an in-flight suggestion response', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((_) => response.future);
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    response.complete(
      jsonResponse([
        {'name': 'stale_result', 'category': 0, 'post_count': 1},
      ]),
    );
    await flushResponses(tester);
    expect(find.text('stale_result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('closing search while a request is pending is safe', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    ApiClient().dio.httpClientAdapter = MockHttpAdapter((_) => response.future);
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    response.complete(jsonResponse([]));
    await flushResponses(tester);
    expect(tester.takeException(), isNull);
  });
}
