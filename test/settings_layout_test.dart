import 'package:flexbooru/core/i18n/app_localizations.dart';
import 'package:flexbooru/ui/widgets/settings_control_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['zh', 'en']) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        '$language dictionary action leaves text readable at 320px, scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final strings = AppLocalizations(Locale(language));
          var pressed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SettingsControlTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(strings.tagDatabase, key: const Key('title')),
                    subtitle: Text(
                      strings.tagDbEmbedded,
                      key: const Key('subtitle'),
                    ),
                    control: OutlinedButton.icon(
                      onPressed: () => pressed = true,
                      icon: const Icon(Icons.sync, size: 16),
                      label: Text(strings.downloadTagDb),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const Key('title'))).width,
            greaterThan(200),
          );
          expect(
            tester.getTopLeft(find.byType(OutlinedButton)).dy,
            greaterThanOrEqualTo(
              tester.getBottomLeft(find.byKey(const Key('subtitle'))).dy,
            ),
          );
          await tester.tap(find.byType(OutlinedButton));
          expect(pressed, isTrue);
        },
      );
    }
  }
  testWidgets('desktop keeps the action alongside text', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsControlTile(
            leading: const Icon(Icons.translate),
            title: const Text('Tag language', key: Key('title')),
            subtitle: const Text('English'),
            controlWidth: 180,
            control: DropdownButton<String>(
              value: 'en',
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byType(DropdownButton<String>)).dx,
      greaterThan(tester.getBottomRight(find.byKey(const Key('title'))).dx),
    );
  });
}
