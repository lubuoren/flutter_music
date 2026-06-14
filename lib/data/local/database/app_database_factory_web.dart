import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openAppDatabase(
  OnDatabaseCreateFn onCreate, {
  required int version,
  OnDatabaseVersionChangeFn? onUpgrade,
}) {
  databaseFactory = databaseFactoryFfiWeb;
  return databaseFactory.openDatabase(
    'vutronmusic.db',
    options: OpenDatabaseOptions(
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}
