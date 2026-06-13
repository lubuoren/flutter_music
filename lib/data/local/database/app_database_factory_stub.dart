import 'package:sqflite/sqflite.dart';

Future<Database> openAppDatabase(OnDatabaseCreateFn onCreate) {
  throw UnsupportedError('当前平台暂不支持本地数据库');
}
