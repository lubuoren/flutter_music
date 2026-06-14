import 'package:sqflite/sqflite.dart';

Future<Database> openAppDatabase(
  OnDatabaseCreateFn onCreate, {
  required int version,
  OnDatabaseVersionChangeFn? onUpgrade,
}) {
  throw UnsupportedError('当前平台暂不支持本地数据库');
}
