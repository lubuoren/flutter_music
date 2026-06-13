import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openAppDatabase(OnDatabaseCreateFn onCreate) {
  databaseFactory = databaseFactoryFfiWeb;
  return databaseFactory.openDatabase(
    'vutronmusic.db',
    options: OpenDatabaseOptions(version: 1, onCreate: onCreate),
  );
}
