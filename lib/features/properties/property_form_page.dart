import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_fields.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/property.dart';

class PropertyFormPage extends ConsumerStatefulWidget {
  const PropertyFormPage({super.key, this.propertyId});
  final String? propertyId;

  @override
  ConsumerState<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends ConsumerState<PropertyFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _surface = TextEditingController();
  final _rooms = TextEditingController();
  final _floor = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _notes = TextEditingController();
  PropertyType _type = PropertyType.appartement;
  bool _furnished = false;
  DateTime? _purchaseDate;
  Property? _existing;
  bool _loading = true;

  bool get _isEdit => widget.propertyId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final p = await ref
          .read(propertyRepositoryProvider)
          .getById(widget.propertyId!);
      if (p != null) {
        _existing = p;
        _name.text = p.name;
        _address.text = p.address;
        _postalCode.text = p.postalCode;
        _city.text = p.city;
        _surface.text = p.surface?.toString().replaceAll('.', ',') ?? '';
        _rooms.text = p.rooms?.toString() ?? '';
        _floor.text = p.floor;
        _purchasePrice.text = p.purchasePriceCents == null
            ? ''
            : Money.toInput(p.purchasePriceCents!);
        _notes.text = p.notes;
        _type = p.type;
        _furnished = p.furnished;
        _purchaseDate = p.purchaseDate;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _postalCode,
      _city,
      _surface,
      _rooms,
      _floor,
      _purchasePrice,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final property = Property(
      id: _existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      type: _type,
      address: _address.text.trim(),
      postalCode: _postalCode.text.trim(),
      city: _city.text.trim(),
      surface: double.tryParse(_surface.text.replaceAll(',', '.').trim()),
      rooms: int.tryParse(_rooms.text.trim()),
      floor: _floor.text.trim(),
      furnished: _furnished,
      purchaseDate: _purchaseDate,
      purchasePriceCents: Money.parse(_purchasePrice.text),
      notes: _notes.text.trim(),
      createdAt: _existing?.createdAt,
    );
    await ref.read(propertyRepositoryProvider).save(property);
    if (!mounted) return;
    showMessage(context, _isEdit ? 'Bien mis à jour' : 'Bien ajouté');
    context.go('/biens/${property.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le bien' : 'Nouveau bien'),
        actions: [
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
                    AppTextField(
                      controller: _name,
                      label: 'Nom du bien',
                      hint: 'Ex. T2 rue Victor Hugo',
                      required: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: DropdownButtonFormField<PropertyType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in PropertyType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                    ),
                    const SectionTitle('Adresse'),
                    AppTextField(
                      controller: _address,
                      label: 'Adresse',
                      hint: 'Numéro, rue, bâtiment, appartement…',
                      required: true,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                    ),
                    FieldRow(
                      children: [
                        AppTextField(
                          controller: _postalCode,
                          label: 'Code postal',
                          required: true,
                          keyboardType: TextInputType.number,
                        ),
                        AppTextField(
                          controller: _city,
                          label: 'Ville',
                          required: true,
                        ),
                      ],
                    ),
                    const SectionTitle('Caractéristiques'),
                    FieldRow(
                      children: [
                        AppTextField(
                          controller: _surface,
                          label: 'Surface',
                          suffixText: 'm²',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        AppTextField(
                          controller: _rooms,
                          label: 'Nombre de pièces',
                          keyboardType: TextInputType.number,
                        ),
                        AppTextField(controller: _floor, label: 'Étage'),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Location meublée'),
                      value: _furnished,
                      onChanged: (v) => setState(() => _furnished = v),
                    ),
                    const SectionTitle('Acquisition (facultatif)'),
                    FieldRow(
                      children: [
                        DateField(
                          label: "Date d'achat",
                          value: _purchaseDate,
                          clearable: true,
                          onChanged: (d) => setState(() => _purchaseDate = d),
                        ),
                        MoneyField(
                          controller: _purchasePrice,
                          label: "Prix d'achat (frais inclus)",
                        ),
                      ],
                    ),
                    const SectionTitle('Notes'),
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
