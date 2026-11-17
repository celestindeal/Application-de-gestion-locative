import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/lease.dart';
import '../../models/property.dart';

class TenantsPage extends ConsumerWidget {
  const TenantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantsProvider);
    final leases = ref.watch(leasesProvider).value ?? const <Lease>[];
    final properties =
        ref.watch(propertiesProvider).value ?? const <Property>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Locataires')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/locataires/nouveau'),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Ajouter'),
      ),
      body: AsyncView(
        value: tenants,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'Aucun locataire',
              message:
                  'Ajoutez vos locataires, puis rattachez-les à un bien '
                  'via un bail.',
              action: FilledButton.icon(
                onPressed: () => context.go('/locataires/nouveau'),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Ajouter un locataire'),
              ),
            );
          }
          return PageBody(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final active = leases
                    .where((l) => l.tenantIds.contains(t.id) && l.isActive)
                    .firstOrNull;
                final property = active == null
                    ? null
                    : properties
                          .where((p) => p.id == active.propertyId)
                          .firstOrNull;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        t.lastName.isEmpty ? '?' : t.lastName[0].toUpperCase(),
                      ),
                    ),
                    title: Text(t.formalName),
                    subtitle: Text(
                      [
                        if (t.email.isNotEmpty) t.email else '⚠ Pas d\'e-mail',
                        if (property != null) property.name,
                      ].join('\n'),
                    ),
                    isThreeLine: property != null,
                    onTap: () => context.go('/locataires/${t.id}'),
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
