import 'package:sembast/sembast.dart';

import 'database_factory_stub.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as impl;

/// Ouvre la base locale : IndexedDB dans le navigateur, mémoire ailleurs
/// (tests).
Future<Database> openLocalDatabase() => impl.openLocalDatabase();
