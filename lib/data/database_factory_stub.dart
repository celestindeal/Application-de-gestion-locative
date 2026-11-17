import 'package:sembast/sembast_memory.dart';

Future<Database> openLocalDatabase() =>
    databaseFactoryMemory.openDatabase('gestion_locative');
