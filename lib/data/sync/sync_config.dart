import 'dart:math';

import 'package:sembast/sembast.dart';

import '../../core/env.dart';

/// Réglages de synchronisation propres à CET appareil (jamais envoyés au
/// serveur ni exportés dans les sauvegardes).
class SyncConfig {
  const SyncConfig({
    required this.deviceId,
    this.serverUrl = AppEnv.defaultServerUrl,
    this.key = '',
    this.cursor,
    this.initialized = false,
  });

  /// Identifiant aléatoire de l'appareil (diagnostic, rien de personnel).
  final String deviceId;
  final String serverUrl;

  /// Clé de la base (prod ou test), saisie dans Paramètres.
  final String key;

  /// Date « updated » du dernier élément reçu du serveur.
  final String? cursor;

  /// Première fusion avec le serveur faite.
  final bool initialized;

  bool get isConfigured => serverUrl.trim().isNotEmpty && key.trim().isNotEmpty;

  SyncConfig copyWith({
    String? serverUrl,
    String? key,
    String? cursor,
    bool clearCursor = false,
    bool? initialized,
  }) => SyncConfig(
    deviceId: deviceId,
    serverUrl: serverUrl ?? this.serverUrl,
    key: key ?? this.key,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    initialized: initialized ?? this.initialized,
  );

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'serverUrl': serverUrl,
    'key': key,
    'cursor': cursor,
    'initialized': initialized,
  };

  factory SyncConfig.fromJson(Map<String, Object?> json) => SyncConfig(
    deviceId: json['deviceId'] as String,
    serverUrl: json['serverUrl'] as String? ?? AppEnv.defaultServerUrl,
    key: json['key'] as String? ?? '',
    cursor: json['cursor'] as String?,
    initialized: json['initialized'] as bool? ?? false,
  );
}

class SyncConfigRepository {
  SyncConfigRepository(this._db);

  final Database _db;
  final _record = StoreRef<String, Map<String, Object?>>('device')
      .record('sync');

  static String _newDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<SyncConfig> get() async {
    final value = await _record.get(_db);
    if (value != null) return SyncConfig.fromJson(value);
    final config = SyncConfig(deviceId: _newDeviceId());
    await save(config);
    return config;
  }

  Future<void> save(SyncConfig config) => _record.put(_db, config.toJson());

  Stream<SyncConfig?> watch() => _record
      .onSnapshot(_db)
      .map((s) => s == null ? null : SyncConfig.fromJson(s.value));
}
