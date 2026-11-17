import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

web.Blob _blob(Uint8List bytes, String mimeType) =>
    web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));

bool get _isTouchDevice => web.window.navigator.maxTouchPoints > 0;

Future<void> saveOrShare(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  if (_isTouchDevice) {
    final file = web.File(
      [bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: mimeType),
    );
    final data = web.ShareData(files: [file].toJS);
    try {
      if (web.window.navigator.canShare(data)) {
        await web.window.navigator.share(data).toDart;
        return;
      }
    } catch (e) {
      // Partage annulé par l'utilisateur : rien à faire.
      if (e.toString().contains('AbortError')) return;
      // Sinon (partage non autorisé…) on se rabat sur le téléchargement.
    }
  }
  _download(bytes, filename, mimeType);
}

void _download(Uint8List bytes, String filename, String mimeType) {
  final url = web.URL.createObjectURL(_blob(bytes, mimeType));
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

void openInNewTab(Future<Uint8List> bytes, String mimeType) {
  // Ouverture synchrone pendant le clic, puis chargement du contenu.
  final tab = web.window.open('', '_blank');
  bytes.then((b) {
    final url = web.URL.createObjectURL(_blob(b, mimeType));
    if (tab != null) {
      tab.location.href = url;
    } else {
      web.window.location.href = url;
    }
  });
}

Future<String?> pickTextFile({String accept = '.json'}) {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      file.text().toDart.then(
        (text) {
          if (!completer.isCompleted) completer.complete(text.toDart);
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
  );
  input.click();
  return completer.future;
}
