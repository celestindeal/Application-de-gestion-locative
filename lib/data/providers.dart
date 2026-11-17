import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../models/landlord_settings.dart';
import '../models/lease.dart';
import '../models/property.dart';
import '../models/rent_payment.dart';
import '../models/tenant.dart';
import 'repository.dart';
import 'sembast_repository.dart';
import 'settings_repository.dart';

/// Fourni dans main() via `overrideWithValue`.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider non initialisé'),
);

// ---- Repositories ---------------------------------------------------------
// Pour passer au serveur Raspberry Pi : remplacer SembastRepository par une
// implémentation HTTP ici, et uniquement ici.

final propertyRepositoryProvider = Provider<Repository<Property>>(
  (ref) => SembastRepository(
    ref.watch(databaseProvider),
    'properties',
    Property.fromJson,
  ),
);

final tenantRepositoryProvider = Provider<Repository<Tenant>>(
  (ref) => SembastRepository(
    ref.watch(databaseProvider),
    'tenants',
    Tenant.fromJson,
  ),
);

final leaseRepositoryProvider = Provider<Repository<Lease>>(
  (ref) =>
      SembastRepository(ref.watch(databaseProvider), 'leases', Lease.fromJson),
);

final paymentRepositoryProvider = Provider<Repository<RentPayment>>(
  (ref) => SembastRepository(
    ref.watch(databaseProvider),
    'payments',
    RentPayment.fromJson,
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
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
