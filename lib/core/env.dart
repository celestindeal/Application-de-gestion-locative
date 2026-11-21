/// Environnement de l'application, fixé à la compilation :
///   flutter build web --dart-define=APP_ENV=test
///
/// - prod : utilisation au quotidien (données réelles)
/// - test : validation des nouveautés avant mise en prod. Base de données
///   séparée et bandeau « TEST » pour ne jamais confondre les deux.
abstract final class AppEnv {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  static const isTest = name == 'test';

  /// Nom de la base locale (IndexedDB). Les deux environnements sont servis
  /// depuis le même domaine : des noms distincts évitent tout mélange.
  static const databaseName = isTest
      ? 'gestion_locative_test'
      : 'gestion_locative';

  /// Adresse proposée par défaut pour le serveur de données (Raspberry Pi,
  /// module Home Assistant « Gestion locative », voir docs/SERVEUR.md).
  /// Deux bases séparées : prod sur le port 443, test sur le port 8443.
  /// Modifiable dans Paramètres › Synchronisation.
  static const defaultServerUrl = isTest
      ? 'https://gestion-locative.taile55644.ts.net:8443'
      : 'https://gestion-locative.taile55644.ts.net';
}
