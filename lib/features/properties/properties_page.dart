import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/lease.dart';
import '../../models/property.dart';

IconData propertyIcon(PropertyType type) => switch (type) {
  PropertyType.maison => Icons.house_outlined,
  PropertyType.parking => Icons.local_parking,
  PropertyType.localCommercial => Icons.storefront_outlined,
  PropertyType.immeuble => Icons.domain,
  _ => Icons.apartment,
};

class PropertiesPage extends ConsumerWidget {
  const PropertiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    final leases = ref.watch(leasesProvider).value ?? const <Lease>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Mes biens')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/biens/nouveau'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un bien'),
      ),
      body: AsyncView(
        value: properties,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.home_work_outlined,
              title: 'Aucun bien pour le moment',
              message: 'Ajoutez votre premier bien pour commencer.',
              action: FilledButton.icon(
                onPressed: () => context.go('/biens/nouveau'),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un bien'),
              ),
            );
          }
          return PageBody(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                final active = leases
                    .where((l) => l.propertyId == p.id && l.isActive)
                    .firstOrNull;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(propertyIcon(p.type))),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        p.fullAddress,
                        [
                          p.type.label,
                          if (p.surface != null)
                            '${p.surface!.toStringAsFixed(p.surface! % 1 == 0 ? 0 : 1)} m²',
                        ].join(' · '),
                      ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                    isThreeLine: p.fullAddress.isNotEmpty,
                    trailing: active == null
                        ? const Chip(label: Text('Vacant'))
                        : Text(
                            '${Money.format(active.totalCents)}/mois',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                    onTap: () => context.go('/biens/${p.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
