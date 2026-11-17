import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/leases/lease_form_page.dart';
import '../features/properties/property_detail_page.dart';
import '../features/properties/property_form_page.dart';
import '../features/properties/properties_page.dart';
import '../features/receipts/receipts_page.dart';
import '../features/settings/settings_page.dart';
import '../features/tenants/tenant_form_page.dart';
import '../features/tenants/tenants_page.dart';
import 'shell.dart';

/// Toutes les routes de l'application. Chaque nouveau module (chantiers,
/// études d'achat, comptabilité…) ajoutera ici sa branche.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/biens',
              builder: (_, _) => const PropertiesPage(),
              routes: [
                GoRoute(
                  path: 'nouveau',
                  builder: (_, _) => const PropertyFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      PropertyDetailPage(propertyId: s.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'modifier',
                      builder: (_, s) =>
                          PropertyFormPage(propertyId: s.pathParameters['id']),
                    ),
                    GoRoute(
                      path: 'bail/nouveau',
                      builder: (_, s) =>
                          LeaseFormPage(propertyId: s.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'bail/:leaseId',
                      builder: (_, s) => LeaseFormPage(
                        propertyId: s.pathParameters['id']!,
                        leaseId: s.pathParameters['leaseId'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/locataires',
              builder: (_, _) => const TenantsPage(),
              routes: [
                GoRoute(
                  path: 'nouveau',
                  builder: (_, _) => const TenantFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      TenantFormPage(tenantId: s.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quittances',
              builder: (_, _) => const ReceiptsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/parametres',
              builder: (_, _) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page introuvable')),
    body: Center(child: Text('${state.uri}')),
  ),
);
