import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3 can open and query downloaded tag.sqlite', () {
    const path = r'C:\Users\cst\.gemini\antigravity\brain\30b882cd-500a-4978-b35b-f89f5d0a20e0\scratch\tag.sqlite';
    if (!File(path).existsSync()) return;

    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    final stmt = db.prepare('SELECT cn_name, category FROM tags WHERE name = ?');
    final rows = stmt.select(['1girl']);
    expect(rows.length, 1);
    expect(rows.first['cn_name'], '单个女孩');
    expect(rows.first['category'], 0);

    final stmtHighres = stmt.select(['highres']);
    expect(stmtHighres.first['cn_name'], '高分辨率');
    expect(stmtHighres.first['category'], 5);

    stmt.close();
    db.close();
  });
}
