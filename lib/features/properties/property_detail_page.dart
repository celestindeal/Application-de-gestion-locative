import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/lease.dart';
import '../../models/property.dart';
import '../../models/rent_payment.dart';
import '../../models/tenant.dart';
import '../receipts/payment_tile.dart';

class PropertyDetailPage extends ConsumerWidget {
  const PropertyDetailPage({super.key, required this.propertyId});
  final String propertyId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Property p,
    List<Lease> leases,
    List<RentPayment> payments,
  ) async {
    if (leases.isNotEmpty || payments.isNotEmpty) {
      showMessage(
        context,
        'Ce bien a des baux ou des quittances : supprimez-les d\'abord '
        'pour conserver un historique cohérent.',
        error: true,
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Supprimer « ${p.name} » ?',
      message: 'Cette action est définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(propertyRepositoryProvider).delete(p.id);
    if (context.mounted) context.go('/biens');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    final allLeases = ref.watch(leasesProvider).value ?? const <Lease>[];
    final tenants = ref.watch(tenantsProvider).value ?? const <Tenant>[];
    final allPayments =
        ref.watch(paymentsProvider).value ?? const <RentPayment>[];

    return AsyncView(
      value: properties,
      builder: (list) {
        final p = list.where((e) => e.id == propertyId).firstOrNull;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Bien introuvable',
            ),
          );
        }
        final leases = allLeases.where((l) => l.propertyId == p.id).toList();
        final payments = allPayments
            .where((x) => x.propertyId == p.id)
            .toList();
        String names(Lease l) => l.tenantIds
            .map(
              (id) =>
                  tenants.where((t) => t.id == id).firstOrNull?.displayName ??
                  '?',
            )
            .join(', ');

        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.go('/biens/${p.id}/modifier'),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') {
                    _delete(context, ref, p, leases, payments);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          body: PageBody(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                const SectionTitle('Informations'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        InfoRow('Type', p.type.label),
                        InfoRow('Adresse', p.fullAddress),
                        InfoRow(
                          'Surface',
                          p.surface == null
                              ? ''
                              : '${p.surface.toString().replaceAll('.', ',')} m²',
                        ),
                        InfoRow('Pièces', p.rooms?.toString() ?? ''),
                        InfoRow('Étage', p.floor),
                        InfoRow('Meublé', p.furnished ? 'Oui' : 'Non'),
                        InfoRow(
                          "Date d'achat",
                          p.purchaseDate == null
                              ? ''
                              : Dates.day(p.purchaseDate!),
                        ),
                        InfoRow(
                          "Prix d'achat",
                          p.purchasePriceCents == null
                              ? ''
                              : Money.format(p.purchasePriceCents!),
                        ),
                        InfoRow('Notes', p.notes),
                      ],
                    ),
                  ),
                ),
                SectionTitle(
                  'Baux',
                  trailing: TextButton.icon(
                    onPressed: () => context.go('/biens/${p.id}/bail/nouveau'),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau bail'),
                  ),
                ),
                if (leases.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Aucun bail. Créez-en un pour suivre les loyers et '
                      'envoyer les quittances.',
                    ),
                  ),
                for (final l in leases)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        l.isActive ? Icons.key : Icons.history,
                        color: l.isActive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        names(l).isEmpty ? 'Sans locataire' : names(l),
                      ),
                      subtitle: Text(
                        '${Money.format(l.rentCents)} + ${Money.format(l.chargesCents)} de charges\n'
                        'Depuis le ${Dates.day(l.startDate)}'
                        '${l.endDate != null ? ' jusqu\'au ${Dates.day(l.endDate!)}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/biens/${p.id}/bail/${l.id}'),
                    ),
                  ),
                if (payments.isNotEmpty) ...[
                  const SectionTitle('Quittances'),
                  for (final pay in payments) PaymentTile(payment: pay),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
