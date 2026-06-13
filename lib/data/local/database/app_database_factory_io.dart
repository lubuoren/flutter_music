import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openAppDatabase(OnDatabaseCreateFn onCreate) async {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final appDir = await getApplicationSupportDirectory();
  final dbDir = Directory(p.join(appDir.path, 'vutronmusic'));
  await dbDir.create(recursive: true);
  final dbPath = p.join(dbDir.path, 'vutronmusic.db');

  return openDatabase(dbPath, version: 1, onCreate: onCreate);
}
