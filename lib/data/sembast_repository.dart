import 'package:sembast/sembast.dart';

import '../models/entity.dart';
import 'repository.dart';

/// Stockage local (IndexedDB sur le web) basé sur Sembast.
class SembastRepository<T extends Entity> implements Repository<T> {
  SembastRepository(this._db, String storeName, this._fromJson)
    : _store = stringMapStoreFactory.store(storeName);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store;
  final T Function(Map<String, Object?>) _fromJson;

  T _decode(RecordSnapshot<String, Map<String, Object?>> s) =>
      _fromJson({...s.value, 'id': s.key});

  @override
  Stream<List<T>> watchAll() =>
      _store.query().onSnapshots(_db).map((list) => list.map(_decode).toList());

  @override
  Future<List<T>> getAll() async =>
      (await _store.find(_db)).map(_decode).toList();

  @override
  Future<T?> getById(String id) async {
    final value = await _store.record(id).get(_db);
    return value == null ? null : _fromJson({...value, 'id': id});
  }

  @override
  Future<void> save(T entity) =>
      _store.record(entity.id).put(_db, entity.toJson());

  @override
  Future<void> delete(String id) => _store.record(id).delete(_db);

  @override
  Future<void> replaceAll(List<T> entities) => _db.transaction((txn) async {
    await _store.delete(txn);
    for (final e in entities) {
      await _store.record(e.id).put(txn, e.toJson());
    }
  });
}
