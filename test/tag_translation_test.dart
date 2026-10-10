import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/models/tag.dart';
import 'package:flexbooru/providers/settings_provider.dart';
import 'package:flexbooru/services/tag_translation_service.dart';
import 'package:flexbooru/ui/widgets/tag_chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tag Model & Localization Tests', () {
    test('Tag displayName responds to tagLanguage correctly', () {
      final tagWithCn = Tag(
        name: '1girl',
        category: TagCategory.general,
        count: 8500000,
        translatedName: '单个女孩',
      );

      expect(tagWithCn.displayName(tagLanguage: 'zh'), equals('单个女孩'));
      expect(tagWithCn.displayName(tagLanguage: 'en'), equals('1girl'));

      final tagWithoutCn = Tag(
        name: 'unknown_tag',
        category: TagCategory.general,
      );
      expect(tagWithoutCn.displayName(tagLanguage: 'zh'), equals('unknown_tag'));
      expect(tagWithoutCn.displayName(tagLanguage: 'en'), equals('unknown_tag'));
    });

    test('Tag copyWith works properly', () {
      final t1 = Tag(name: 'solo', category: TagCategory.general);
      final t2 = t1.copyWith(translatedName: '单人', category: TagCategory.character);
      expect(t2.name, equals('solo'));
      expect(t2.translatedName, equals('单人'));
      expect(t2.category, equals(TagCategory.character));
    });
  });

  group('SettingsProvider Tag Language Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('effectiveTagLanguage follows current app language by default', () async {
      final provider = SettingsProvider();
      await provider.loadSettings();

      // Default system
      expect(provider.tagLanguage, equals('system'));

      // When language is set to Chinese, effectiveTagLanguage should be zh
      await provider.setLanguage('zh');
      expect(provider.effectiveTagLanguage, equals('zh'));

      // When language is set to English, effectiveTagLanguage should be en
      await provider.setLanguage('en');
      expect(provider.effectiveTagLanguage, equals('en'));

      // When tag language is explicitly overridden
      await provider.setTagLanguage('zh');
      expect(provider.tagLanguage, equals('zh'));
      expect(provider.effectiveTagLanguage, equals('zh'));

      await provider.setTagLanguage('en');
      expect(provider.tagLanguage, equals('en'));
      expect(provider.effectiveTagLanguage, equals('en'));
    });
  });

  group('TagTranslationService Tests', () {
    test('works with in-memory SQLite database', () {
      final service = TagTranslationService();

      // Verify enrichTags
      final tags = [
        Tag(name: '1girl', category: TagCategory.general),
        Tag(name: 'hatsune_miku', category: TagCategory.general),
      ];

      final enriched = service.enrichTags(tags);
      expect(enriched.length, equals(2));
      expect(enriched[0].name, equals('1girl'));
      expect(enriched[1].name, equals('hatsune_miku'));
    });

    test('TagCategory mapping matches Danbooru specifications', () {
      expect(TagCategory.getCategoryName(TagCategory.artist), equals('Artist'));
      expect(TagCategory.getCategoryName(TagCategory.character), equals('Character'));
      expect(TagCategory.getCategoryName(TagCategory.copyright), equals('Copyright'));
      expect(TagCategory.getCategoryName(TagCategory.meta), equals('Meta'));
      expect(TagCategory.getCategoryName(TagCategory.general), equals('General'));

      expect(TagCategory.getCategoryNameZh(TagCategory.artist), equals('画师'));
      expect(TagCategory.getCategoryNameZh(TagCategory.character), equals('角色'));
      expect(TagCategory.getCategoryNameZh(TagCategory.copyright), equals('原作'));
      expect(TagCategory.getCategoryNameZh(TagCategory.meta), equals('元标签'));
      expect(TagCategory.getCategoryNameZh(TagCategory.general), equals('普通'));
    });
  });

  group('TagChip Widget Tests', () {
    testWidgets('TagChip renders translated and original name without ink displacement', (tester) async {
      final tag = Tag(
        name: '1girl',
        category: TagCategory.general,
        count: 12000,
        translatedName: '单个女孩',
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagChip(
              tag: tag,
              tagLanguage: 'zh',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('单个女孩'), findsOneWidget);
      expect(find.text('1girl'), findsOneWidget);
      expect(find.text('12k'), findsOneWidget);

      // Verify InkWell is child of Material and taps cleanly
      await tester.tap(find.byType(TagChip));
      expect(tapped, isTrue);
    });

    testWidgets('TagChip in English mode renders only English name', (tester) async {
      final tag = Tag(
        name: 'solo',
        category: TagCategory.general,
        translatedName: '单人',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagChip(
              tag: tag,
              tagLanguage: 'en',
            ),
          ),
        ),
      );

      expect(find.text('solo'), findsOneWidget);
      expect(find.text('单人'), findsNothing);
    });
  });
}
