import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/property.dart';
import 'payment_tile.dart';

/// Historique de toutes les quittances, groupées par année.
class ReceiptsPage extends ConsumerWidget {
  const ReceiptsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider);
    final properties =
        ref.watch(propertiesProvider).value ?? const <Property>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Quittances')),
      body: AsyncView(
        value: payments,
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucune quittance',
              message:
                  'Les quittances apparaissent ici dès que vous validez '
                  'un paiement depuis l\'accueil.',
            );
          }
          final years = list.map((p) => p.year).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          return PageBody(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                for (final y in years) ...[
                  SectionTitle(
                    '$y',
                    trailing: Text(
                      'Encaissé : ${Money.format(list.where((p) => p.year == y).fold(0, (s, p) => s + p.paidCents))}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  for (final p in list.where((p) => p.year == y))
                    PaymentTile(
                      payment: p,
                      subtitlePrefix: properties
                          .where((x) => x.id == p.propertyId)
                          .firstOrNull
                          ?.name,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
