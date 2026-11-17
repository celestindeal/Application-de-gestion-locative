import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/landlord_settings.dart';
import '../../models/lease.dart';
import '../../models/property.dart';
import '../../models/rent_payment.dart';
import '../../models/tenant.dart';
import '../receipts/payment_actions.dart';
import '../receipts/payment_tile.dart';

/// Accueil : les loyers du mois, et le bouton "paiement reçu" en un clic.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  final Set<String> _busy = {};

  // Date de paiement choisie avant de cliquer sur "Paiement reçu".
  final Map<String, DateTime> _chosenDates = {};
  String _dateKey(Lease l) => "${l.id}|$_year|$_month";
  DateTime _dateFor(Lease l) =>
      _chosenDates[_dateKey(l)] ?? l.defaultPaymentDate(_year, _month);

  Future<void> _pickDate(Lease lease) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: "Date du paiement",
      initialDate: _dateFor(lease),
      firstDate: DateTime(_year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _chosenDates[_dateKey(lease)] = picked);
  }

  void _shiftMonth(int delta) {
    final d = DateTime(_year, _month + delta);
    setState(() {
      _year = d.year;
      _month = d.month;
    });
  }

  Future<void> _run(String leaseId, Future<void> Function() action) async {
    if (_busy.contains(leaseId)) return;
    setState(() => _busy.add(leaseId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(leaseId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).value ?? const LandlordSettings();
    final properties =
        ref.watch(propertiesProvider).value ?? const <Property>[];
    final tenants = ref.watch(tenantsProvider).value ?? const <Tenant>[];
    final payments = ref.watch(paymentsProvider).value ?? const <RentPayment>[];
    final leasesAsync = ref.watch(leasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion locative')),
      body: AsyncView(
        value: leasesAsync,
        builder: (allLeases) {
          final leases =
              allLeases.where((l) => l.coversMonth(_year, _month)).toList()
                ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
          RentPayment? paymentFor(Lease l) => payments
              .where(
                (p) =>
                    p.leaseId == l.id && p.year == _year && p.month == _month,
              )
              .firstOrNull;

          final expected = leases.fold(
            0,
            (s, l) => s + l.totalForMonth(_year, _month),
          );
          final received = leases.fold(
            0,
            (s, l) => s + (paymentFor(l)?.paidCents ?? 0),
          );

          return PageBody(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                _SetupChecklist(
                  settings: settings,
                  hasProperties: properties.isNotEmpty,
                  hasLeases: allLeases.isNotEmpty,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mois précédent',
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          'Loyers de ${Dates.monthYear(_year, _month)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mois suivant',
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                if (leases.isNotEmpty)
                  _Summary(expected: expected, received: received),
                if (leases.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun bail en cours sur ce mois.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final lease in leases)
                  _LeaseRentCard(
                    lease: lease,
                    property: properties
                        .where((p) => p.id == lease.propertyId)
                        .firstOrNull,
                    tenants: tenants
                        .where((t) => lease.tenantIds.contains(t.id))
                        .toList(),
                    payment: paymentFor(lease),
                    busy: _busy.contains(lease.id),
                    year: _year,
                    month: _month,
                    paymentDate: _dateFor(lease),
                    onPickDate: () => _pickDate(lease),
                    onValidate: () => _run(
                      lease.id,
                      () => PaymentActions.validate(
                        context,
                        ref,
                        lease: lease,
                        year: _year,
                        month: _month,
                        paymentDate: _dateFor(lease),
                      ),
                    ),
                    onValidateWithDetails: () => _run(
                      lease.id,
                      () => PaymentActions.validateWithDetails(
                        context,
                        ref,
                        lease: lease,
                        year: _year,
                        month: _month,
                        initialDate: _dateFor(lease),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.expected, required this.received});
  final int expected;
  final int received;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = expected == 0
        ? 0.0
        : (received / expected).clamp(0.0, 1.0);
    Widget stat(String label, int cents) => Expanded(
      child: Column(
        children: [
          Text(
            Money.format(cents),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                stat('Attendu', expected),
                stat('Encaissé', received),
                stat('Reste', (expected - received).clamp(0, expected)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaseRentCard extends ConsumerWidget {
  const _LeaseRentCard({
    required this.lease,
    required this.property,
    required this.tenants,
    required this.payment,
    required this.busy,
    required this.year,
    required this.month,
    required this.paymentDate,
    required this.onPickDate,
    required this.onValidate,
    required this.onValidateWithDetails,
  });

  final Lease lease;
  final Property? property;
  final List<Tenant> tenants;
  final RentPayment? payment;
  final bool busy;
  final int year;
  final int month;
  final DateTime paymentDate;
  final VoidCallback onPickDate;
  final VoidCallback onValidate;
  final VoidCallback onValidateWithDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = payment;
    final missingEmail =
        lease.sendReceipts && tenants.every((t) => t.email.trim().isEmpty);

    Widget action;
    if (busy) {
      action = const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(),
        ),
      );
    } else if (p == null) {
      action = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(
            message: 'Changer la date du paiement',
            child: TextButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.event, size: 18),
              label: Text('le ${DateFormat('dd/MM').format(paymentDate)}'),
            ),
          ),
          FilledButton.icon(
            onPressed: onValidate,
            icon: Icon(lease.sendReceipts ? Icons.send : Icons.check),
            label: Text(
              lease.sendReceipts ? 'Paiement reçu + envoi' : 'Paiement reçu',
            ),
          ),
          IconButton(
            tooltip: 'Autre montant (paiement partiel…)',
            onPressed: onValidateWithDetails,
            icon: const Icon(Icons.tune),
          ),
        ],
      );
    } else {
      action = PaymentMenu(payment: p);
    }

    String status;
    Color statusColor;
    if (p == null) {
      status = 'En attente · échéance le ${lease.dueDay}';
      statusColor = scheme.onSurfaceVariant;
    } else if (p.isPartial) {
      status =
          'Partiel : ${Money.format(p.paidCents)} reçus, '
          'reste ${Money.format(p.remainingCents)}';
      statusColor = scheme.error;
    } else if (p.sentAt == null) {
      status = lease.sendReceipts
          ? 'Payé le ${Dates.day(p.paymentDate)} · quittance non envoyée'
          : 'Payé le ${Dates.day(p.paymentDate)} · sans envoi de quittance';
      statusColor = lease.sendReceipts ? scheme.error : Colors.green.shade700;
    } else {
      status = 'Payé le ${Dates.day(p.paymentDate)} · quittance envoyée';
      statusColor = Colors.green.shade700;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
              child: InkWell(
                onTap: property == null
                    ? null
                    : () => context.go('/biens/${property!.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property?.name ?? 'Bien supprimé',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${tenants.map((t) => t.displayName).join(', ')} · '
                      '${Money.format(lease.totalForMonth(year, month))}'
                      '${lease.isProrated(year, month) ? ' (prorata ${lease.occupiedDays(year, month)} j)' : ''}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p == null
                              ? Icons.schedule
                              : ((p.sentAt != null || !lease.sendReceipts) &&
                                        !p.isPartial
                                    ? Icons.check_circle
                                    : Icons.warning_amber),
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (p == null && !missingEmail)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              lease.sendReceipts
                                  ? Icons.mail_outline
                                  : Icons.unsubscribe_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                lease.sendReceipts
                                    ? 'Quittance envoyée au clic à '
                                          '${tenants.map((t) => t.email).where((e) => e.isNotEmpty).join(', ')}'
                                    : 'Pas d\'envoi de quittance (réglé dans le bail)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (p == null && missingEmail)
                      Text(
                        '⚠ Aucun e-mail locataire : la quittance ne pourra '
                        'pas être envoyée',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }
}

/// Guide de démarrage tant que la configuration n'est pas complète.
class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({
    required this.settings,
    required this.hasProperties,
    required this.hasLeases,
  });

  final LandlordSettings settings;
  final bool hasProperties;
  final bool hasLeases;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        'Renseigner vos coordonnées de bailleur',
        settings.isLandlordComplete,
        '/parametres',
      ),
      (
        'Connecter Gmail pour l\'envoi des quittances',
        settings.isGmailConfigured,
        '/parametres',
      ),
      ('Ajouter un bien', hasProperties, '/biens'),
      ('Créer un bail (bien + locataire + loyer)', hasLeases, '/biens'),
    ];
    if (steps.every((s) => s.$2)) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Pour bien démarrer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (label, done, route) in steps)
              ListTile(
                dense: true,
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                title: Text(
                  label,
                  style: done
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                onTap: done ? null : () => context.go(route),
              ),
          ],
        ),
      ),
    );
  }
}
