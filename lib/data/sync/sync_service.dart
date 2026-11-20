import 'dart:async';

import '../settings_repository.dart';
import 'sync_config.dart';
import 'sync_queue.dart';
import 'sync_remote.dart';
import 'synced_repository.dart';

enum SyncState { disabled, syncing, ok, offline, error }

class SyncStatus {
  const SyncStatus(this.state, {this.lastSync, this.message});
  final SyncState state;
  final DateTime? lastSync;
  final String? message;
}

typedef RemoteFactory = SyncRemote Function(SyncConfig config);

/// Synchronise la base locale de l'appareil avec le serveur :
/// 1. envoie la file d'attente des changements locaux ;
/// 2. reçoit ce qui a changé sur le serveur depuis le dernier passage.
/// Toutes les 30 s, peu après chaque modification, et au retour dans l'app.
/// Pour un même élément, la modification la plus récente gagne.
class SyncService {
  SyncService({
    required this.config,
    required this.queue,
    required this.repositories,
    required this.settings,
    required this.remoteFactory,
  });

  final SyncConfigRepository config;
  final SyncQueue queue;
  final Map<SyncType, SyncedRepository> repositories;
  final SettingsRepository settings;
  final RemoteFactory remoteFactory;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus(SyncState.disabled);
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<void>? _changesSub;
  bool _running = false;
  bool _again = false;

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get current => _current;

  void _emit(SyncStatus s) {
    _current = s;
    _status.add(s);
  }

  void start({Duration every = const Duration(seconds: 30)}) {
    _changesSub ??= queue.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), syncNow);
    });
    _timer ??= Timer.periodic(every, (_) => syncNow());
    unawaited(syncNow());
  }

  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _changesSub?.cancel();
    _status.close();
  }

  /// Vérifie l'adresse et la clé, puis active la synchronisation sur cet
  /// appareil. Lève [SyncException] si le serveur refuse.
  Future<void> connect(String serverUrl, String key) async {
    final current = await config.get();
    final candidate = current.copyWith(
      serverUrl: PocketBaseRemote.normalizeAddress(serverUrl),
      key: key.trim(),
    );
    await remoteFactory(candidate).checkAccess();
    final changedServer =
        candidate.serverUrl != current.serverUrl ||
        candidate.key != current.key;
    await config.save(
      changedServer
          ? candidate.copyWith(clearCursor: true, initialized: false)
          : candidate,
    );
    await syncNow();
  }

  Future<void> disconnect() async {
    final current = await config.get();
    await config.save(
      current.copyWith(key: '', clearCursor: true, initialized: false),
    );
    _emit(const SyncStatus(SyncState.disabled));
  }

  Future<void> syncNow() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final cfg = await config.get();
      if (!cfg.isConfigured) {
        _emit(const SyncStatus(SyncState.disabled));
        return;
      }
      _emit(SyncStatus(SyncState.syncing, lastSync: _current.lastSync));
      final remote = remoteFactory(cfg);
      if (!cfg.initialized) {
        await _initialMerge(remote, cfg);
      } else {
        await _push(remote);
        await _pull(remote, cfg);
      }
      _emit(SyncStatus(SyncState.ok, lastSync: DateTime.now()));
    } on SyncException catch (e) {
      _emit(
        SyncStatus(
          e.offline ? SyncState.offline : SyncState.error,
          lastSync: _current.lastSync,
          message: e.message,
        ),
      );
    } catch (e) {
      _emit(
        SyncStatus(
          SyncState.error,
          lastSync: _current.lastSync,
          message: 'Erreur de synchronisation : $e',
        ),
      );
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  Future<void> _push(SyncRemote remote) async {
    for (final change in await queue.pending()) {
      await remote.push(change);
      await queue.remove(change);
    }
  }

  Future<void> _pull(SyncRemote remote, SyncConfig cfg) async {
    final result = await remote.pull(cfg.cursor);
    for (final r in result.records) {
      if (r.device == cfg.deviceId) continue; // déjà présent ici
      await _apply(r);
    }
    final latest = await config.get();
    await config.save(latest.copyWith(cursor: result.cursor));
  }

  Future<void> _apply(RemoteRecord r) async {
    final pending = await queue.get(r.type, r.id);
    if (pending != null) {
      // Changement local plus récent : il sera envoyé et gagnera.
      if (pending.t > r.t) return;
      await queue.remove(pending);
    }
    if (r.type == SyncType.settings) {
      if (!r.deleted && r.data != null) await settings.applyRemote(r.data!);
      return;
    }
    await repositories[r.type]?.applyRemote(r.id, r.deleted ? null : r.data);
  }

  /// Première connexion de cet appareil au serveur : on récupère tout ce
  /// que le serveur a, puis on lui envoie ce que l'appareil a en plus
  /// (données saisies avant la synchronisation). Rien n'est perdu.
  Future<void> _initialMerge(SyncRemote remote, SyncConfig cfg) async {
    final result = await remote.pull(null);
    final onServer = <String>{};
    for (final r in result.records) {
      onServer.add('${r.type.code}:${r.id}');
      await _apply(r);
    }
    for (final entry in repositories.entries) {
      for (final item in await entry.value.localItems()) {
        final key = '${entry.key.code}:${item.id}';
        if (!onServer.contains(key) &&
            await queue.get(entry.key, item.id) == null) {
          await queue.enqueue(entry.key, item.id, data: item.toJson());
        }
      }
    }
    final localSettings = await settings.get();
    if (!onServer.contains(
          '${SyncType.settings.code}:${SettingsRepository.syncId}',
        ) &&
        localSettings.isLandlordComplete) {
      await queue.enqueue(
        SyncType.settings,
        SettingsRepository.syncId,
        data: localSettings.toJson(includeSecrets: false),
      );
    }
    await _push(remote);
    final latest = await config.get();
    await config.save(
      latest.copyWith(cursor: result.cursor, initialized: true),
    );
  }
}
