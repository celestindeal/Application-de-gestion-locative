import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_locative/data/sembast_repository.dart';
import 'package:gestion_locative/data/settings_repository.dart';
import 'package:gestion_locative/data/sync/sync_config.dart';
import 'package:gestion_locative/data/sync/sync_queue.dart';
import 'package:gestion_locative/data/sync/sync_remote.dart';
import 'package:gestion_locative/data/sync/sync_service.dart';
import 'package:gestion_locative/data/sync/synced_repository.dart';
import 'package:gestion_locative/models/landlord_settings.dart';
import 'package:gestion_locative/models/property.dart';
import 'package:sembast/sembast_memory.dart';

/// Faux serveur reproduisant les règles PocketBase de
/// serveur/pb_hooks/gestion_locative.pb.js (la plus récente gagne).
class FakeServer {
  final records = <String, Map<String, Object?>>{};
  int _clock = 0;
  bool online = true;
  String key = 'cle-de-test-0123456789';

  String _updated() => (++_clock).toString().padLeft(10, '0');
}

class FakeRemote implements SyncRemote {
  FakeRemote(this.server, this.key, this.device);
  final FakeServer server;
  final String key;
  final String device;

  void _check() {
    if (!server.online) throw const SyncException('hors ligne', offline: true);
    if (key != server.key) throw const SyncException('Clé refusée');
  }

  @override
  Future<void> checkAccess() async => _check();

  @override
  Future<void> push(PendingChange c) async {
    _check();
    final id = remoteId(c.type, c.id);
    final existing = server.records[id];
    if (existing != null && (existing['t'] as int) >= c.t) return;
    server.records[id] = {
      'type': c.type.code,
      'uid': c.id,
      'data': c.data,
      'supprime': c.deleted,
      't': c.t,
      'appareil': device,
      'updated': server._updated(),
    };
  }

  @override
  Future<({List<RemoteRecord> records, String? cursor})> pull(
    String? since,
  ) async {
    _check();
    final items =
        server.records.values
            .where(
              (r) =>
                  since == null ||
                  (r['updated'] as String).compareTo(since) >= 0,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['updated'] as String).compareTo(b['updated'] as String),
          );
    return (
      records: [
        for (final r in items)
          RemoteRecord(
            type: SyncType.fromCode(r['type'])!,
            id: r['uid'] as String,
            t: r['t'] as int,
            data: r['data'] as Map<String, Object?>?,
            deleted: r['supprime'] as bool,
            device: r['appareil'] as String,
          ),
      ],
      cursor: items.isEmpty ? since : items.last['updated'] as String,
    );
  }
}

/// Un appareil : sa base locale, ses repositories et son service.
class Device {
  Device._(this.properties, this.settings, this.config, this.service);

  final SyncedRepository<Property> properties;
  final SettingsRepository settings;
  final SyncConfigRepository config;
  final SyncService service;

  static Future<Device> create(
    FakeServer server,
    String name, {
    bool connect = true,
  }) async {
    final db = await newDatabaseFactoryMemory().openDatabase(name);
    final queue = SyncQueue(db);
    final properties = SyncedRepository(
      SembastRepository(db, 'properties', Property.fromJson),
      queue,
      SyncType.property,
    );
    final settings = SettingsRepository(db, queue);
    final config = SyncConfigRepository(db);
    final service = SyncService(
      config: config,
      queue: queue,
      repositories: {SyncType.property: properties},
      settings: settings,
      remoteFactory: (c) => FakeRemote(server, c.key, c.deviceId),
    );
    final device = Device._(properties, settings, config, service);
    if (connect) await device.connect(server);
    return device;
  }

  Future<void> connect(FakeServer server) =>
      service.connect('https://serveur.example', server.key);
}

Property _property(String id, String name) => Property(id: id, name: name);

void main() {
  test("identifiant serveur : 15 caractères a-z0-9, stable", () {
    const uuid = '0E302948-9fb5-4ae6-b930-a096a99e52ad';
    final id = remoteId(SyncType.property, uuid);
    expect(id, 'b0e3029489fb54a');
    expect(id.length, 15);
    expect(remoteId(SyncType.settings, 'landlord'), 'slandlord000000');
  });

  test(
    'création, modification et suppression passent d\'un appareil à l\'autre',
    () async {
      final server = FakeServer();
      final a = await Device.create(server, 'a');
      final b = await Device.create(server, 'b');

      await a.properties.save(_property('11111111-aaaa', 'T2 Centre'));
      await a.service.syncNow();
      await b.service.syncNow();
      expect((await b.properties.getById('11111111-aaaa'))?.name, 'T2 Centre');

      await b.properties.save(_property('11111111-aaaa', 'T2 Centre rénové'));
      await b.service.syncNow();
      await a.service.syncNow();
      expect(
        (await a.properties.getById('11111111-aaaa'))?.name,
        'T2 Centre rénové',
      );

      await a.properties.delete('11111111-aaaa');
      await a.service.syncNow();
      await b.service.syncNow();
      expect(await b.properties.getById('11111111-aaaa'), isNull);
    },
  );

  test('hors ligne : les changements attendent puis partent', () async {
    final server = FakeServer();
    final a = await Device.create(server, 'a');
    server.online = false;
    await a.properties.save(_property('22222222-bbbb', 'Studio'));
    await a.service.syncNow();
    expect(a.service.current.state, SyncState.offline);
    expect(server.records, isEmpty);

    server.online = true;
    await a.service.syncNow();
    expect(a.service.current.state, SyncState.ok);
    expect(server.records.length, 1);
  });

  test('la modification la plus récente gagne', () async {
    final server = FakeServer();
    final a = await Device.create(server, 'a');
    final b = await Device.create(server, 'b');
    await a.properties.save(_property('33333333-cccc', 'Version A'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.properties.save(
      _property('33333333-cccc', 'Version B (plus récente)'),
    );
    // A envoie en premier, puis B : B est plus récent et gagne partout.
    await a.service.syncNow();
    await b.service.syncNow();
    await a.service.syncNow();
    expect(
      (await a.properties.getById('33333333-cccc'))?.name,
      'Version B (plus récente)',
    );
    expect(
      (await b.properties.getById('33333333-cccc'))?.name,
      'Version B (plus récente)',
    );
  });

  test('première connexion : les données déjà saisies sont envoyées, rien n\'est perdu', () async {
    final server = FakeServer();
    final a = await Device.create(server, 'a');
    await a.properties.save(_property('44444444-dddd', 'Bien du serveur'));
    await a.service.syncNow();

    // Appareil utilisé avant la synchronisation (données sans file d'attente).
    final b = await Device.create(server, 'b', connect: false);
    await b.properties.applyRemote(
      '55555555-eeee',
      _property('55555555-eeee', 'Bien local ancien').toJson(),
    );
    await b.connect(server);

    expect((await b.properties.getAll()).length, 2);
    await a.service.syncNow();
    expect(
      (await a.properties.getById('55555555-eeee'))?.name,
      'Bien local ancien',
    );
  });

  test('paramètres du bailleur partagés, jeton Gmail jamais envoyé', () async {
    final server = FakeServer();
    final a = await Device.create(server, 'a');
    final b = await Device.create(server, 'b');
    await a.settings.save(
      LandlordSettings(
        name: 'Jean Bailleur',
        address: '1 rue du Port',
        gmailAccessToken: 'jeton-secret-a',
        gmailTokenExpiry: DateTime(2030),
      ),
    );
    await a.service.syncNow();
    expect(server.records.toString(), isNot(contains('jeton-secret-a')));

    await b.service.syncNow();
    final s = await b.settings.get();
    expect(s.name, 'Jean Bailleur');
    expect(s.gmailAccessToken, isNull);
  });

  test('mauvaise clé : refusée à la connexion', () async {
    final server = FakeServer();
    final a = await Device.create(server, 'a', connect: false);
    expect(
      () => a.service.connect(
        'https://serveur.example',
        'mauvaise-cle-123456789',
      ),
      throwsA(isA<SyncException>()),
    );
    expect((await a.config.get()).isConfigured, isFalse);
  });
}
