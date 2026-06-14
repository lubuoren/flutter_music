import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/local/database/app_database.dart';

void main() {
  group('AppDatabase.migrationScriptsFor', () {
    test('版本相同时无迁移脚本', () {
      expect(AppDatabase.migrationScriptsFor(1, 1), isEmpty);
    });

    test('当前版本尚未登记 v2+ 迁移，返回空', () {
      expect(
        AppDatabase.migrationScriptsFor(1, AppDatabase.databaseVersion),
        isEmpty,
      );
    });

    test('按版本升序返回登记的迁移脚本', () {
      const migrations = {3: 'C', 2: 'B', 4: 'D'};
      expect(
        AppDatabase.migrationScriptsFor(1, 4, migrations: migrations),
        ['B', 'C', 'D'],
      );
    });

    test('仅执行 (oldVersion, newVersion] 区间内的脚本', () {
      const migrations = {2: 'B', 3: 'C', 4: 'D'};
      expect(
        AppDatabase.migrationScriptsFor(2, 3, migrations: migrations),
        ['C'],
      );
    });
  });
}
