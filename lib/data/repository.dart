import '../models/entity.dart';

/// Contrat d'accès aux données, indépendant du stockage.
///
/// Aujourd'hui : implémentation locale ([SembastRepository], IndexedDB du
/// navigateur). Demain : une implémentation HTTP qui parlera à l'API hébergée
/// sur le Raspberry Pi, sans toucher aux écrans.
abstract class Repository<T extends Entity> {
  Stream<List<T>> watchAll();
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> save(T entity);
  Future<void> delete(String id);

  /// Remplace tout le contenu (utilisé par l'import de sauvegarde).
  Future<void> replaceAll(List<T> entities);
}
