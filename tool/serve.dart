// Petit serveur statique pour tester la version compilée (build/web).
//
//   flutter build web
//   dart run tool/serve.dart            -> http://localhost:8080
//   dart run tool/serve.dart 9000       -> autre port
import 'dart:io';

const _types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8080;
  final root = Directory('build/web');
  if (!root.existsSync()) {
    stderr.writeln(
      'build/web introuvable : lancez d\'abord "flutter build web".',
    );
    exit(1);
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Application servie sur http://localhost:$port');
  await for (final req in server) {
    var path = Uri.decodeComponent(req.uri.path);
    if (path.endsWith('/')) path += 'index.html';
    final file = File('${root.path}$path');
    final safe = file.absolute.path.startsWith(root.absolute.path);
    final target = safe && file.existsSync()
        ? file
        : File('${root.path}/index.html');
    final ext = target.path.substring(target.path.lastIndexOf('.'));
    req.response.headers
      ..set('Content-Type', _types[ext] ?? 'application/octet-stream')
      ..set('Cache-Control', 'no-cache');
    await req.response.addStream(target.openRead());
    await req.response.close();
  }
}
