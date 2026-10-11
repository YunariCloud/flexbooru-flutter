import 'dart:io';
import 'package:flexbooru/core/constants/app_constants.dart';
import 'package:flexbooru/services/tag_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'support/tag_database_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SQLite fixture supports exact translations and category mapping',
    () async {
      final dir = await Directory.systemTemp.createTemp('flexbooru_tags_');
      final path = '${dir.path}/tags.sqlite';
      final service = TagTranslationService();
      try {
        createTagDatabase(path);
        service.setCustomDbPath(path);
        await service.init();
        expect(service.isDatabaseReady, isTrue);
        expect(service.getLoadedTagCount(), 2);
        expect(service.getTranslation('1girl')?.cnName, '单个女孩');
        expect(service.getTranslation('highres')?.category, TagCategory.meta);
        final aliases = service.getTranslationsBatch(['1girl', ' 1GIRL ']);
        expect(aliases['1girl']?.cnName, '单个女孩');
        expect(aliases[' 1GIRL ']?.cnName, '单个女孩');
      } finally {
        service.setCustomDbPath(null);
        await File(path).delete();
        await dir.delete();
      }
    },
  );

  test('batch translation handles more than 900 SQL parameters', () async {
    final dir = await Directory.systemTemp.createTemp('flexbooru_tag_batch_');
    final path = '${dir.path}/tags.sqlite';
    final service = TagTranslationService();
    try {
      createTagDatabase(path);
      final database = sqlite3.open(path);
      try {
        database.execute('BEGIN');
        for (var i = 0; i < 1100; i++) {
          database.execute('INSERT INTO tags VALUES (?, 0, ?, 1)', [
            'tag_$i',
            '翻译$i',
          ]);
        }
        database.execute('COMMIT');
      } finally {
        database.close();
      }
      service.setCustomDbPath(path);
      await service.init();
      final translated = service.getTranslationsBatch(
        List.generate(1100, (i) => 'tag_$i'),
      );
      expect(translated.length, 1100);
      expect(translated['tag_1099']?.cnName, '翻译1099');
    } finally {
      service.setCustomDbPath(null);
      await File(path).delete();
      await dir.delete();
    }
  });
}
