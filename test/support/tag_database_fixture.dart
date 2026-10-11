import 'package:sqlite3/sqlite3.dart';

void createTagDatabase(String path, {String translation = '单个女孩'}) {
  final database = sqlite3.open(path);
  try {
    database.execute(
      'CREATE TABLE tags (name TEXT PRIMARY KEY, category INTEGER, cn_name TEXT, post_count INTEGER)',
    );
    database.execute('INSERT INTO tags VALUES (?, ?, ?, ?)', [
      '1girl',
      0,
      translation,
      100,
    ]);
    database.execute('INSERT INTO tags VALUES (?, ?, ?, ?)', [
      'highres',
      5,
      '高分辨率',
      200,
    ]);
  } finally {
    database.close();
  }
}
