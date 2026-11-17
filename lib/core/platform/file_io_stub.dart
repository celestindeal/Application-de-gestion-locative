import 'dart:typed_data';

Future<void> saveOrShare(Uint8List bytes, String filename, String mimeType) =>
    throw UnsupportedError('Disponible uniquement dans le navigateur');

void openInNewTab(Future<Uint8List> bytes, String mimeType) =>
    throw UnsupportedError('Disponible uniquement dans le navigateur');

Future<String?> pickTextFile({String accept = '.json'}) =>
    throw UnsupportedError('Disponible uniquement dans le navigateur');
