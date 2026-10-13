import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:flexbooru/services/google_drive_sync_service.dart';
import 'package:flexbooru/services/lan_sync_service.dart';
import 'package:flexbooru/ui/screens/google_drive_sync_screen.dart';
import 'google_drive_sync_test.dart' show FakeAuth, MemoryDrive;
import 'lan_sync_test.dart' show MemoryPersistence, preferences;

void main() {
  testWidgets(
    'Drive configuration includes setup guide and fits narrow screens',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final local = LanSyncService(
        preferences: await preferences({}),
        persistence: MemoryPersistence(),
        attachToApp: false,
      );
      final service = GoogleDriveSyncService(
        local,
        auth: FakeAuth(),
        transport: MemoryDrive(),
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: GoogleDriveSyncScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('首次配置说明'), findsOneWidget);
      await tester.tap(find.text('首次配置说明'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('com.flexbooru.app.flexbooru'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      await local.shutdown();
    },
  );
}
