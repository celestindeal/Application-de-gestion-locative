import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../models/landlord_settings.dart';
import 'sync/sync_queue.dart';

class SettingsRepository {
  SettingsRepository(this._db, [this._queue]);

  /// Identifiant fixe des paramètres du bailleur (un seul enregistrement).
  static const syncId = 'landlord';

  final Database _db;
  final SyncQueue? _queue;
  final _record = StoreRef<String, Map<String, Object?>>('settings')
      .record('landlord');

  Stream<LandlordSettings> watch() =>
      _record.onSnapshot(_db).map((s) => LandlordSettings.fromJson(s?.value));

  Future<LandlordSettings> get() async =>
      LandlordSettings.fromJson(await _record.get(_db));

  /// Enregistre. Seule la partie partagée (sans le jeton Gmail de cet
  /// appareil) est envoyée au serveur, et seulement si elle a changé.
  Future<void> save(LandlordSettings settings) async {
    final before = await get();
    await _record.put(_db, settings.toJson());
    final shared = settings.toJson(includeSecrets: false);
    if (_queue != null &&
        jsonEncode(shared) !=
            jsonEncode(before.toJson(includeSecrets: false))) {
      await _queue.enqueue(SyncType.settings, syncId, data: shared);
    }
  }

  /// Paramètres reçus du serveur : on garde le jeton Gmail de cet appareil.
  Future<void> applyRemote(Map<String, Object?> data) async {
    final local = await get();
    final merged = LandlordSettings.fromJson(data).copyWith(
      gmailAccessToken: local.gmailAccessToken,
      gmailTokenExpiry: local.gmailTokenExpiry,
    );
    await _record.put(_db, merged.toJson());
  }
}
