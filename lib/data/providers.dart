import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../models/entity.dart';
import '../models/landlord_settings.dart';
import '../models/lease.dart';
import '../models/property.dart';
import '../models/rent_payment.dart';
import '../models/tenant.dart';
import 'sembast_repository.dart';
import 'settings_repository.dart';
import 'sync/sync_config.dart';
import 'sync/sync_queue.dart';
import 'sync/sync_remote.dart';
import 'sync/sync_service.dart';
import 'sync/synced_repository.dart';

/// Fourni dans main() via `overrideWithValue`.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider non initialisé'),
);

// ---- Repositories ---------------------------------------------------------
// Base locale (IndexedDB) + file d'attente de synchronisation avec le serveur
// de la Raspberry Pi (voir docs/SERVEUR.md). Les écrans ne voient que
// l'interface Repository.

final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(ref.watch(databaseProvider)),
);

SyncedRepository<T> _synced<T extends Entity>(
  Ref ref,
  String store,
  T Function(Map<String, Object?>) fromJson,
  SyncType type,
) => SyncedRepository(
  SembastRepository(ref.watch(databaseProvider), store, fromJson),
  ref.watch(syncQueueProvider),
  type,
);

final propertyRepositoryProvider = Provider<SyncedRepository<Property>>(
  (ref) => _synced(ref, 'properties', Property.fromJson, SyncType.property),
);

final tenantRepositoryProvider = Provider<SyncedRepository<Tenant>>(
  (ref) => _synced(ref, 'tenants', Tenant.fromJson, SyncType.tenant),
);

final leaseRepositoryProvider = Provider<SyncedRepository<Lease>>(
  (ref) => _synced(ref, 'leases', Lease.fromJson, SyncType.lease),
);

final paymentRepositoryProvider = Provider<SyncedRepository<RentPayment>>(
  (ref) => _synced(ref, 'payments', RentPayment.fromJson, SyncType.payment),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncQueueProvider),
  ),
);

// ---- Synchronisation ------------------------------------------------------

final syncConfigRepositoryProvider = Provider<SyncConfigRepository>(
  (ref) => SyncConfigRepository(ref.watch(databaseProvider)),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    config: ref.watch(syncConfigRepositoryProvider),
    queue: ref.watch(syncQueueProvider),
    repositories: {
      SyncType.property: ref.watch(propertyRepositoryProvider),
      SyncType.tenant: ref.watch(tenantRepositoryProvider),
      SyncType.lease: ref.watch(leaseRepositoryProvider),
      SyncType.payment: ref.watch(paymentRepositoryProvider),
    },
    settings: ref.watch(settingsRepositoryProvider),
    remoteFactory: (c) =>
        PocketBaseRemote(address: c.serverUrl, key: c.key, device: c.deviceId),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return Stream.multi((c) {
    c.add(service.current);
    final sub = service.status.listen(c.add);
    c.onCancel = sub.cancel;
  });
});

final syncPendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(syncQueueProvider).watchCount(),
);

final syncConfigProvider = StreamProvider<SyncConfig?>(
  (ref) => ref.watch(syncConfigRepositoryProvider).watch(),
);

// ---- Flux de données ------------------------------------------------------

final propertiesProvider = StreamProvider<List<Property>>(
  (ref) => ref
      .watch(propertyRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      ),
);

final tenantsProvider = StreamProvider<List<Tenant>>(
  (ref) => ref
      .watch(tenantRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          ),
      ),
);

final leasesProvider = StreamProvider<List<Lease>>(
  (ref) => ref
      .watch(leaseRepositoryProvider)
      .watchAll()
      .map((l) => l..sort((a, b) => b.startDate.compareTo(a.startDate))),
);

final paymentsProvider = StreamProvider<List<RentPayment>>(
  (ref) => ref
      .watch(paymentRepositoryProvider)
      .watchAll()
      .map(
        (l) => l
          ..sort((a, b) {
            final c = (b.year * 100 + b.month).compareTo(
              a.year * 100 + a.month,
            );
            return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
          }),
      ),
);

final settingsProvider = StreamProvider<LandlordSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
