import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/core/i18n/app_localizations.dart';
import 'package:flexbooru/models/booru_credential_guide.dart';
import 'package:flexbooru/models/booru_site.dart';
import 'package:flexbooru/ui/widgets/booru_credential_guide_dialog.dart';

void main() {
  group('BooruCredentialGuide Unit Tests', () {
    test('presetGuides contains all 9 preset sites', () {
      final guides = BooruCredentialGuide.presetGuides;
      expect(guides.length, equals(9));

      final ids = guides.map((g) => g.id).toList();
      expect(ids, containsAll([
        'danbooru',
        'gelbooru',
        'e621',
        'rule34',
        'sankaku',
        'yandere',
        'konachan',
        'safebooru',
        'paheal',
      ]));
    });

    test('forSite matches each default preset accurately', () {
      for (final site in BooruSite.defaultPresets) {
        final guide = BooruCredentialGuide.forSite(site);
        expect(guide.id, equals(site.id));
        expect(guide.getSteps(true), isNotEmpty);
        expect(guide.getSteps(false), isNotEmpty);
        expect(guide.getUsernameLabel(true), isNotEmpty);
        expect(guide.getTokenLabel(true), isNotEmpty);
      }
    });

    test('Gelbooru guide warns about numeric User ID', () {
      final gel = BooruCredentialGuide.forHostOrType('gelbooru.com', BooruType.gelbooru);
      expect(gel.id, equals('gelbooru'));
      expect(gel.isAuthRequired, isTrue);
      expect(gel.getUsernameWarning(true), contains('纯数字 User ID'));
      expect(gel.getTokenWarning(true), contains('API Key'));
    });

    test('Safebooru and Paheal are flagged as not needing auth', () {
      final safe = BooruCredentialGuide.forHostOrType('safebooru.org', BooruType.gelbooru);
      expect(safe.isNoAuthNeeded, isTrue);

      final paheal = BooruCredentialGuide.forHostOrType('rule34.paheal.net', BooruType.shimmie);
      expect(paheal.isNoAuthNeeded, isTrue);
    });

    test('custom sites fall back to engine-specific guide', () {
      final customDan = BooruCredentialGuide.forHostOrType('custom.moe', BooruType.danbooru);
      expect(customDan.id, equals('custom_danbooru'));
      expect(customDan.getTokenLabel(true), equals('API Key'));

      final customGel = BooruCredentialGuide.forHostOrType('custom-gel.org', BooruType.gelbooru);
      expect(customGel.id, equals('custom_gelbooru'));
      expect(customGel.getUsernameWarning(true), contains('纯数字 User ID'));
    });
  });

  group('BooruCredentialGuideDialog Widget Tests', () {
    testWidgets('renders dialog and switches between sites properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const [
            Locale('zh'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    BooruCredentialGuideDialog.show(
                      context,
                      initialHost: 'danbooru.donmai.us',
                      initialType: BooruType.danbooru,
                    );
                  },
                  child: const Text('Open Guide'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Guide'));
      await tester.pumpAndSettle();

      // Check title and current site guide
      expect(find.text('站点登录与凭据指南'), findsOneWidget);
      expect(find.text('Danbooru'), findsWidgets);
      expect(find.text('API Key'), findsWidgets);

      // Switch site via dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Tap Gelbooru option
      final gelbooruItem = find.text('Gelbooru (gelbooru.com)').last;
      await tester.tap(gelbooruItem);
      await tester.pumpAndSettle();

      // Verify Gelbooru instructions are now shown
      expect(find.text('用户 ID (纯数字 User ID)'), findsOneWidget);
      expect(find.textContaining('务必填写纯数字 User ID'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('站点登录与凭据指南'), findsNothing);
    });
  });
}
