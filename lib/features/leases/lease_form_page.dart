import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_fields.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/lease.dart';
import '../../models/tenant.dart';
import '../tenants/tenant_form_page.dart';

class LeaseFormPage extends ConsumerStatefulWidget {
  const LeaseFormPage({super.key, required this.propertyId, this.leaseId});
  final String propertyId;
  final String? leaseId;

  @override
  ConsumerState<LeaseFormPage> createState() => _LeaseFormPageState();
}

class _LeaseFormPageState extends ConsumerState<LeaseFormPage> {
  final _form = GlobalKey<FormState>();
  final _rent = TextEditingController();
  final _charges = TextEditingController();
  final _deposit = TextEditingController();
  final _dueDay = TextEditingController(text: '1');
  final _paymentDay = TextEditingController(text: '5');
  final _notes = TextEditingController();
  DateTime? _start = DateTime.now();
  DateTime? _end;
  final Set<String> _tenantIds = {};
  Lease? _existing;
  bool _loading = true;

  bool get _isEdit => widget.leaseId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final l = await ref
          .read(leaseRepositoryProvider)
          .getById(widget.leaseId!);
      if (l != null) {
        _existing = l;
        _rent.text = Money.toInput(l.rentCents);
        _charges.text = Money.toInput(l.chargesCents);
        _deposit.text = Money.toInput(l.depositCents);
        _dueDay.text = '${l.dueDay}';
        _paymentDay.text = '${l.paymentDay}';
        _notes.text = l.notes;
        _start = l.startDate;
        _end = l.endDate;
        _tenantIds.addAll(l.tenantIds);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_rent, _charges, _deposit, _dueDay, _paymentDay, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_tenantIds.isEmpty) {
      showMessage(context, 'Sélectionnez au moins un locataire.', error: true);
      return;
    }
    if (_start == null) {
      showMessage(context, 'Indiquez la date de début du bail.', error: true);
      return;
    }
    final lease = Lease(
      id: _existing?.id ?? const Uuid().v4(),
      propertyId: widget.propertyId,
      tenantIds: _tenantIds.toList(),
      startDate: _start!,
      endDate: _end,
      rentCents: Money.parse(_rent.text) ?? 0,
      chargesCents: Money.parse(_charges.text) ?? 0,
      depositCents: Money.parse(_deposit.text) ?? 0,
      dueDay: (int.tryParse(_dueDay.text) ?? 1).clamp(1, 31),
      paymentDay: (int.tryParse(_paymentDay.text) ?? 5).clamp(1, 31),
      notes: _notes.text.trim(),
      createdAt: _existing?.createdAt,
    );
    await ref.read(leaseRepositoryProvider).save(lease);
    if (!mounted) return;
    showMessage(context, _isEdit ? 'Bail mis à jour' : 'Bail créé');
    context.go('/biens/${widget.propertyId}');
  }

  Future<void> _delete() async {
    final payments = await ref.read(paymentRepositoryProvider).getAll();
    if (!mounted) return;
    if (payments.any((p) => p.leaseId == widget.leaseId)) {
      showMessage(
        context,
        'Des quittances existent pour ce bail. Pour le clôturer, indiquez '
        'plutôt une date de fin.',
        error: true,
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce bail ?',
      message: 'Cette action est définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(leaseRepositoryProvider).delete(widget.leaseId!);
    if (mounted) context.go('/biens/${widget.propertyId}');
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(tenantsProvider).value ?? const <Tenant>[];
    final total =
        (Money.parse(_rent.text) ?? 0) + (Money.parse(_charges.text) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le bail' : 'Nouveau bail'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: Form(
                key: _form,
                onChanged: () => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SectionTitle('Locataire(s)'),
                    if (tenants.isEmpty)
                      const Text("Aucun locataire enregistré pour l'instant."),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in tenants)
                          FilterChip(
                            label: Text(t.displayName),
                            selected: _tenantIds.contains(t.id),
                            onSelected: (s) => setState(
                              () => s
                                  ? _tenantIds.add(t.id)
                                  : _tenantIds.remove(t.id),
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Nouveau locataire'),
                          onPressed: () async {
                            final t = await showQuickTenantDialog(context, ref);
                            if (t != null) setState(() => _tenantIds.add(t.id));
                          },
                        ),
                      ],
                    ),
                    const SectionTitle('Loyer'),
                    FieldRow(
                      children: [
                        MoneyField(
                          controller: _rent,
                          label: 'Loyer hors charges',
                          required: true,
                        ),
                        MoneyField(
                          controller: _charges,
                          label: 'Provision pour charges',
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Total mensuel : ${Money.format(total)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FieldRow(
                      children: [
                        AppTextField(
                          controller: _dueDay,
                          label: "Jour d'échéance",
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 1 || n > 31
                                ? 'Entre 1 et 31'
                                : null;
                          },
                        ),
                        AppTextField(
                          controller: _paymentDay,
                          label: 'Jour de paiement habituel',
                          hint: 'Date proposée par défaut',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 1 || n > 31
                                ? 'Entre 1 et 31'
                                : null;
                          },
                        ),
                      ],
                    ),
                    MoneyField(
                      controller: _deposit,
                      label: 'Dépôt de garantie',
                    ),
                    const SectionTitle('Durée'),
                    FieldRow(
                      children: [
                        DateField(
                          label: 'Début du bail',
                          value: _start,
                          required: true,
                          onChanged: (d) => setState(() => _start = d),
                        ),
                        DateField(
                          label: 'Fin du bail (départ)',
                          value: _end,
                          clearable: true,
                          onChanged: (d) => setState(() => _end = d),
                        ),
                      ],
                    ),
                    AppTextField(
                      controller: _notes,
                      label: 'Notes',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
