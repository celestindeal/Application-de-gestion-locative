import '../../models/entity.dart';
import '../repository.dart';
import '../sembast_repository.dart';
import 'sync_queue.dart';

/// Repository local qui note chaque modification dans la file d'attente de
/// synchronisation. Les écrans l'utilisent comme n'importe quel Repository.
class SyncedRepository<T extends Entity> implements Repository<T> {
  SyncedRepository(this._local, this._queue, this.type);

  final SembastRepository<T> _local;
  final SyncQueue _queue;
  final SyncType type;

  @override
  Stream<List<T>> watchAll() => _local.watchAll();

  @override
  Future<List<T>> getAll() => _local.getAll();

  @override
  Future<T?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(T entity) async {
    await _local.save(entity);
    await _queue.enqueue(type, entity.id, data: entity.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _local.delete(id);
    await _queue.enqueue(type, id, deleted: true);
  }

  @override
  Future<void> replaceAll(List<T> entities) async {
    final before = (await _local.ids()).toSet();
    await _local.replaceAll(entities);
    final after = entities.map((e) => e.id).toSet();
    for (final id in before.difference(after)) {
      await _queue.enqueue(type, id, deleted: true);
    }
    for (final e in entities) {
      await _queue.enqueue(type, e.id, data: e.toJson());
    }
  }

  // ---- Utilisé par le service de synchronisation (pas de mise en file) ----

  Future<List<T>> localItems() => _local.getAll();

  /// Applique un élément reçu du serveur ([data] null = supprimé).
  Future<void> applyRemote(String id, Map<String, Object?>? data) async {
    if (data == null) {
      await _local.delete(id);
    } else {
      await _local.save(_local.decode(id, data));
    }
  }
}
