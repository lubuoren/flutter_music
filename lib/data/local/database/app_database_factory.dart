import 'package:sqflite/sqflite.dart';

import 'app_database_factory_stub.dart'
    if (dart.library.io) 'app_database_factory_io.dart'
    if (dart.library.js_interop) 'app_database_factory_web.dart'
    as impl;

Future<Database> openAppDatabase(OnDatabaseCreateFn onCreate) {
  return impl.openAppDatabase(onCreate);
}
