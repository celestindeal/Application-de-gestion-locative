import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_queue.dart';

/// Problème de synchronisation à montrer à l'utilisateur.
class SyncException implements Exception {
  const SyncException(this.message, {this.offline = false});
  final String message;

  /// Pas de réseau ou serveur injoignable : on réessaiera plus tard.
  final bool offline;

  @override
  String toString() => message;
}

/// Un élément tel qu'enregistré sur le serveur.
class RemoteRecord {
  const RemoteRecord({
    required this.type,
    required this.id,
    required this.t,
    this.data,
    this.deleted = false,
    this.device,
  });

  final SyncType type;
  final String id;
  final int t;
  final Map<String, Object?>? data;
  final bool deleted;
  final String? device;
}

/// Ce que l'app attend du serveur (remplacé par un faux serveur en test).
abstract class SyncRemote {
  /// Vérifie que le serveur répond et accepte la clé.
  Future<void> checkAccess();

  /// Envoie un changement. Ne fait rien si le serveur a déjà plus récent.
  Future<void> push(PendingChange change);

  /// Éléments modifiés depuis [since] (curseur de l'appel précédent,
  /// null = tout).
  Future<({List<RemoteRecord> records, String? cursor})> pull(String? since);
}

/// Serveur PocketBase de la Raspberry Pi (table « donnees », créée par
/// serveur/pb_hooks/gestion_locative.pb.js).
class PocketBaseRemote implements SyncRemote {
  PocketBaseRemote({
    required String address,
    required this.key,
    required this.device,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : address = normalizeAddress(address),
       _client = client ?? http.Client();

  final String address;
  final String key;
  final String device;
  final Duration timeout;
  final http.Client _client;

  static const _collection = 'donnees';
  static const _perPage = 500;

  /// « serveur.ts.net/ » → « https://serveur.ts.net ».
  static String normalizeAddress(String address) {
    var a = address.trim();
    if (a.isEmpty) return a;
    if (!a.contains('://')) a = 'https://$a';
    while (a.endsWith('/')) {
      a = a.substring(0, a.length - 1);
    }
    return a;
  }

  Map<String, String> get _headers => {
    'X-Cle-Synchro': key,
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$address$path').replace(queryParameters: query);

  Future<http.Response> _call(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const SyncException('Le serveur ne répond pas.', offline: true);
    } on http.ClientException {
      throw const SyncException(
        'Pas de réseau, ou serveur injoignable.',
        offline: true,
      );
    }
  }

  Never _fail(String what, http.Response r) =>
      throw SyncException('$what : le serveur a répondu ${r.statusCode}.');

  @override
  Future<void> checkAccess() async {
    final r = await _call(
      () => _client.get(
        _uri('/api/collections/acces/records', {'perPage': '1'}),
        headers: _headers,
      ),
    );
    if (r.statusCode == 404) {
      throw const SyncException(
        "Ce serveur n'est pas celui de la gestion locative (adresse à vérifier).",
      );
    }
    if (r.statusCode != 200) _fail('Vérification', r);
    final items = (jsonDecode(r.body) as Map<String, Object?>)['items'];
    if (items is! List || items.isEmpty) {
      throw const SyncException('Clé refusée par le serveur.');
    }
  }

  @override
  Future<void> push(PendingChange c) async {
    final id = remoteId(c.type, c.id);
    final body = {
      'type': c.type.code,
      'uid': c.id,
      'data': c.data,
      'supprime': c.deleted,
      't': c.t,
      'appareil': device,
    };
    final path = '/api/collections/$_collection/records';
    final existing = await _call(
      () => _client.get(_uri('$path/$id'), headers: _headers),
    );
    if (existing.statusCode == 200) {
      final server = jsonDecode(existing.body) as Map<String, Object?>;
      // Le serveur a déjà plus récent : rien à faire, on le recevra.
      if (((server['t'] as num?)?.toInt() ?? 0) >= c.t) return;
      final r = await _call(
        () => _client.patch(
          _uri('$path/$id'),
          headers: _headers,
          body: jsonEncode(body),
        ),
      );
      // 404 : un autre appareil vient d'envoyer plus récent.
      if (r.statusCode != 200 && r.statusCode != 404) _fail('Envoi', r);
    } else if (existing.statusCode == 404) {
      final r = await _call(
        () => _client.post(
          _uri(path),
          headers: _headers,
          body: jsonEncode({...body, 'id': id}),
        ),
      );
      if (r.statusCode != 200) _fail('Envoi', r);
    } else {
      _fail('Envoi', existing);
    }
  }

  @override
  Future<({List<RemoteRecord> records, String? cursor})> pull(
    String? since,
  ) async {
    final records = <RemoteRecord>[];
    var cursor = since;
    for (var page = 1; ; page++) {
      final r = await _call(
        () => _client.get(
          _uri('/api/collections/$_collection/records', {
            if (since != null) 'filter': 'updated>="$since"',
            'sort': 'updated',
            'perPage': '$_perPage',
            'page': '$page',
            'skipTotal': '1',
          }),
          headers: _headers,
        ),
      );
      if (r.statusCode != 200) _fail('Réception', r);
      final items =
          ((jsonDecode(r.body) as Map<String, Object?>)['items'] as List?) ??
          const [];
      for (final item in items.cast<Map<String, Object?>>()) {
        if (item['updated'] case final String updated) cursor = updated;
        final type = SyncType.fromCode(item['type']);
        final uid = item['uid'];
        final t = (item['t'] as num?)?.toInt();
        if (type == null || uid is! String || t == null) continue;
        records.add(
          RemoteRecord(
            type: type,
            id: uid,
            t: t,
            data: (item['data'] as Map?)?.cast<String, Object?>(),
            deleted: item['supprime'] == true,
            device: item['appareil'] as String?,
          ),
        );
      }
      if (items.length < _perPage) break;
    }
    return (records: records, cursor: cursor);
  }
}
