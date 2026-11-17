import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_fields.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/tenant.dart';

/// Création rapide d'un locataire depuis un autre écran (ex. bail).
Future<Tenant?> showQuickTenantDialog(BuildContext context, WidgetRef ref) {
  final form = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  return showDialog<Tenant>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nouveau locataire'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: firstName, label: 'Prénom'),
              AppTextField(controller: lastName, label: 'Nom', required: true),
              AppTextField(
                controller: email,
                label: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                validator: emailValidator,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            final t = Tenant(
              id: const Uuid().v4(),
              firstName: firstName.text.trim(),
              lastName: lastName.text.trim(),
              email: email.text.trim(),
            );
            await ref.read(tenantRepositoryProvider).save(t);
            if (context.mounted) Navigator.pop(context, t);
          },
          child: const Text('Ajouter'),
        ),
      ],
    ),
  );
}

class TenantFormPage extends ConsumerStatefulWidget {
  const TenantFormPage({super.key, this.tenantId});
  final String? tenantId;

  @override
  ConsumerState<TenantFormPage> createState() => _TenantFormPageState();
}

class _TenantFormPageState extends ConsumerState<TenantFormPage> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String _civility = '';
  Tenant? _existing;
  bool _loading = true;

  bool get _isEdit => widget.tenantId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final t = await ref
          .read(tenantRepositoryProvider)
          .getById(widget.tenantId!);
      if (t != null) {
        _existing = t;
        _civility = t.civility;
        _firstName.text = t.firstName;
        _lastName.text = t.lastName;
        _email.text = t.email;
        _phone.text = t.phone;
        _notes.text = t.notes;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final tenant = Tenant(
      id: _existing?.id ?? const Uuid().v4(),
      civility: _civility,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      notes: _notes.text.trim(),
      createdAt: _existing?.createdAt,
    );
    await ref.read(tenantRepositoryProvider).save(tenant);
    if (!mounted) return;
    showMessage(context, _isEdit ? 'Locataire mis à jour' : 'Locataire ajouté');
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/locataires');
    }
  }

  Future<void> _delete() async {
    final leases = await ref.read(leaseRepositoryProvider).getAll();
    if (!mounted) return;
    if (leases.any((l) => l.tenantIds.contains(widget.tenantId))) {
      showMessage(
        context,
        'Ce locataire est rattaché à un bail : retirez-le du bail d\'abord.',
        error: true,
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce locataire ?',
      message: 'Cette action est définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(tenantRepositoryProvider).delete(widget.tenantId!);
    if (mounted) context.go('/locataires');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le locataire' : 'Nouveau locataire'),
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'M.', label: Text('M.')),
                          ButtonSegment(value: 'Mme', label: Text('Mme')),
                          ButtonSegment(value: '', label: Text('—')),
                        ],
                        selected: {_civility},
                        onSelectionChanged: (s) =>
                            setState(() => _civility = s.first),
                      ),
                    ),
                    FieldRow(
                      children: [
                        AppTextField(controller: _firstName, label: 'Prénom'),
                        AppTextField(
                          controller: _lastName,
                          label: 'Nom',
                          required: true,
                        ),
                      ],
                    ),
                    AppTextField(
                      controller: _email,
                      label: 'E-mail',
                      hint: 'Pour recevoir les quittances',
                      keyboardType: TextInputType.emailAddress,
                      validator: emailValidator,
                    ),
                    AppTextField(
                      controller: _phone,
                      label: 'Téléphone',
                      keyboardType: TextInputType.phone,
                    ),
                    AppTextField(
                      controller: _notes,
                      label: 'Notes',
                      maxLines: 4,
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
