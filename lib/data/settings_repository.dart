import 'package:sembast/sembast.dart';

import '../models/landlord_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;
  final _record = StoreRef<String, Map<String, Object?>>('settings')
      .record('landlord');

  Stream<LandlordSettings> watch() =>
      _record.onSnapshot(_db).map((s) => LandlordSettings.fromJson(s?.value));

  Future<LandlordSettings> get() async =>
      LandlordSettings.fromJson(await _record.get(_db));

  Future<void> save(LandlordSettings settings) =>
      _record.put(_db, settings.toJson());
}
