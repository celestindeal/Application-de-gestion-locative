import 'dart:async';

import 'package:sembast/sembast.dart';

/// Types d'éléments synchronisés avec le serveur.
enum SyncType {
  property('bien', 'b'),
  tenant('locataire', 'l'),
  lease('bail', 'c'),
  payment('paiement', 'p'),
  settings('parametres', 's');

  const SyncType(this.code, this.prefix);

  /// Valeur du champ « type » sur le serveur.
  final String code;

  /// Première lettre de l'identifiant serveur.
  final String prefix;

  static SyncType? fromCode(Object? code) =>
      values.where((t) => t.code == code).firstOrNull;
}

/// Identifiant de l'enregistrement sur le serveur : 15 caractères [a-z0-9]
/// (format imposé par PocketBase), toujours le même pour un élément :
/// la lettre du type + les 14 premiers caractères de l'UUID sans tirets.
String remoteId(SyncType type, String id) {
  final clean = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '${type.prefix}${clean.padRight(14, '0').substring(0, 14)}';
}

/// Un changement local pas encore envoyé au serveur.
class PendingChange {
  const PendingChange({
    required this.type,
    required this.id,
    required this.t,
    this.data,
    this.deleted = false,
  });

  final SyncType type;
  final String id;

  /// Heure de la modification (ms) : la plus récente gagne sur le serveur.
  final int t;
  final Map<String, Object?>? data;
  final bool deleted;

  String get key => '${type.code}:$id';

  Map<String, Object?> toJson() => {
    'type': type.code,
    'id': id,
    't': t,
    'data': data,
    'deleted': deleted,
  };

  static PendingChange? fromJson(Map<String, Object?> json) {
    final type = SyncType.fromCode(json['type']);
    if (type == null) return null;
    return PendingChange(
      type: type,
      id: json['id'] as String,
      t: (json['t'] as num).toInt(),
      data: (json['data'] as Map?)?.cast<String, Object?>(),
      deleted: json['deleted'] as bool? ?? false,
    );
  }
}

/// File d'attente des changements locaux (stockée sur l'appareil) : l'app
/// marche sans réseau, et tout part au serveur dès qu'il est joignable.
/// Un seul changement en attente par élément (le dernier).
class SyncQueue {
  SyncQueue(this._db);

  final Database _db;
  final _store = stringMapStoreFactory.store('sync_outbox');
  final _changes = StreamController<void>.broadcast();
  static int _lastT = 0;

  /// Prévient le service de synchronisation qu'il y a quelque chose à envoyer.
  Stream<void> get changes => _changes.stream;

  /// Horloge strictement croissante (deux changements dans la même
  /// milliseconde restent ordonnés).
  static int now() {
    final t = DateTime.now().millisecondsSinceEpoch;
    _lastT = t > _lastT ? t : _lastT + 1;
    return _lastT;
  }

  Future<void> enqueue(
    SyncType type,
    String id, {
    Map<String, Object?>? data,
    bool deleted = false,
  }) async {
    final change = PendingChange(
      type: type,
      id: id,
      t: now(),
      data: deleted ? null : data,
      deleted: deleted,
    );
    await _store.record(change.key).put(_db, change.toJson());
    _changes.add(null);
  }

  Future<List<PendingChange>> pending() async {
    final records = await _store.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('t')]),
    );
    return records
        .map((r) => PendingChange.fromJson(r.value))
        .whereType<PendingChange>()
        .toList();
  }

  Future<PendingChange?> get(SyncType type, String id) async {
    final value = await _store.record('${type.code}:$id').get(_db);
    return value == null ? null : PendingChange.fromJson(value);
  }

  /// Retire un changement envoyé, sauf s'il a été remplacé entre-temps.
  Future<void> remove(PendingChange change) => _db.transaction((txn) async {
    final current = await _store.record(change.key).get(txn);
    if (current != null && (current['t'] as num?)?.toInt() == change.t) {
      await _store.record(change.key).delete(txn);
    }
  });

  Stream<int> watchCount() => _store.query().onCount(_db);
}
