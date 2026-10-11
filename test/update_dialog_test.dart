import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flexbooru/services/app_update_manager.dart';
import 'package:flexbooru/ui/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_http_adapter.dart';
import 'app_update_manager_test.dart' show packageResponse, updateInfo;

void main() {
  testWidgets(
    'download becomes install action and explains Android permission',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'flexbooru-update-widget-',
      );
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((_) => packageResponse());
      var opened = 0;
      final info = updateInfo(name: 'flexbooru-android-universal.apk');
      final manager = AppUpdateManager(
        dio: dio,
        directory: () async => directory,
        platform: 'android',
        openPackage: (path) async {
          expect(path.endsWith('.apk'), isTrue);
          opened++;
          return 'permission';
        },
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdateDialog(updateInfo: info, manager: manager),
            ),
          ),
        );
        expect(find.text('下载更新'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('下载更新'));
          await manager.download(info);
        });
        await tester.pumpAndSettle();
        expect(find.text('更新包已下载'), findsOneWidget);
        expect(find.text('安装更新'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('安装更新'));
          // The event handler awaits an asynchronous file verification.
          for (var attempt = 0; opened == 0 && attempt < 50; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('请允许 Flexbooru 安装应用'), findsOneWidget);
        expect(opened, 1);
        await tester.pumpWidget(const SizedBox());
      } finally {
        manager.dispose();
        dio.close(force: true);
        final root = Directory.systemTemp.absolute.path;
        expect(
          directory.absolute.path.startsWith(
            '$root${Platform.pathSeparator}flexbooru-update-widget-',
          ),
          isTrue,
        );
        directory.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Windows ready package shows extraction instructions and open action',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'flexbooru-update-widget-',
      );
      final dio = Dio()
        ..httpClientAdapter = MockHttpAdapter((_) => packageResponse());
      final manager = AppUpdateManager(
        dio: dio,
        directory: () async => directory,
        platform: 'windows',
      );
      final info = updateInfo();
      try {
        await tester.runAsync(() => manager.download(info));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdateDialog(updateInfo: info, manager: manager),
            ),
          ),
        );
        expect(find.text('打开更新包'), findsOneWidget);
        expect(find.textContaining('退出 Flexbooru'), findsOneWidget);
        expect(find.text('安装更新'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      } finally {
        manager.dispose();
        dio.close(force: true);
        final root = Directory.systemTemp.absolute.path;
        expect(
          directory.absolute.path.startsWith(
            '$root${Platform.pathSeparator}flexbooru-update-widget-',
          ),
          isTrue,
        );
        directory.deleteSync(recursive: true);
      }
    },
  );
}
