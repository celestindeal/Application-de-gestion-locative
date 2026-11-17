import 'dart:convert';

import '../models/landlord_settings.dart';
import '../models/lease.dart';
import '../models/property.dart';
import '../models/rent_payment.dart';
import '../models/tenant.dart';
import 'repository.dart';
import 'settings_repository.dart';

/// Export / import de toutes les données au format JSON.
///
/// Indispensable tant que les données sont uniquement locales : sauvegarde,
/// et transfert ordinateur <-> iPhone. Servira aussi à la migration vers le
/// serveur Raspberry Pi.
class BackupService {
  BackupService({
    required this.properties,
    required this.tenants,
    required this.leases,
    required this.payments,
    required this.settings,
  });

  static const formatVersion = 1;

  final Repository<Property> properties;
  final Repository<Tenant> tenants;
  final Repository<Lease> leases;
  final Repository<RentPayment> payments;
  final SettingsRepository settings;

  Future<String> exportJson() async {
    final data = {
      'app': 'gestion_locative',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': (await settings.get()).toJson(includeSecrets: false),
      'properties': (await properties.getAll()).map((e) => e.toJson()).toList(),
      'tenants': (await tenants.getAll()).map((e) => e.toJson()).toList(),
      'leases': (await leases.getAll()).map((e) => e.toJson()).toList(),
      'payments': (await payments.getAll()).map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Remplace toutes les données locales par celles du fichier.
  Future<void> importJson(String content) async {
    final data = jsonDecode(content);
    if (data is! Map<String, dynamic> || data['app'] != 'gestion_locative') {
      throw const FormatException(
        "Ce fichier n'est pas une sauvegarde de l'application.",
      );
    }
    List<Map<String, Object?>> list(String key) =>
        ((data[key] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => Map<String, Object?>.from(m))
            .toList();

    // On décode tout avant d'écrire quoi que ce soit.
    final p = list('properties').map(Property.fromJson).toList();
    final t = list('tenants').map(Tenant.fromJson).toList();
    final l = list('leases').map(Lease.fromJson).toList();
    final pay = list('payments').map(RentPayment.fromJson).toList();
    final current = await settings.get();
    final imported = LandlordSettings.fromJson(
      (data['settings'] as Map?)?.cast<String, Object?>(),
    );

    await properties.replaceAll(p);
    await tenants.replaceAll(t);
    await leases.replaceAll(l);
    await payments.replaceAll(pay);
    // On garde le jeton Gmail de cet appareil.
    await settings.save(
      imported.copyWith(
        gmailAccessToken: current.gmailAccessToken,
        gmailTokenExpiry: current.gmailTokenExpiry,
      ),
    );
  }
}
