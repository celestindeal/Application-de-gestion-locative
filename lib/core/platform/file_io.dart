import 'dart:typed_data';

import 'file_io_stub.dart'
    if (dart.library.js_interop) 'file_io_web.dart'
    as impl;

/// Opérations fichiers côté navigateur (téléchargement, partage, ouverture).
abstract final class FileIO {
  /// Enregistre un fichier. Sur iPhone/Android, ouvre la feuille de partage
  /// (Enregistrer dans Fichiers, Mail, WhatsApp…) quand c'est possible.
  static Future<void> saveOrShare(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) => impl.saveOrShare(bytes, filename, mimeType);

  /// Ouvre un document dans un nouvel onglet. À appeler directement depuis
  /// le gestionnaire de clic (avant tout `await`) pour éviter le bloqueur de
  /// popups : l'onglet est ouvert tout de suite puis rempli quand [bytes]
  /// est prêt.
  static void openInNewTab(Future<Uint8List> bytes, String mimeType) =>
      impl.openInNewTab(bytes, mimeType);

  /// Laisse l'utilisateur choisir un fichier texte (ex. sauvegarde JSON).
  static Future<String?> pickTextFile({String accept = '.json'}) =>
      impl.pickTextFile(accept: accept);
}
