import 'package:sembast_web/sembast_web.dart';

import '../core/env.dart';

Future<Database> openLocalDatabase() =>
    databaseFactoryWeb.openDatabase(AppEnv.databaseName);
