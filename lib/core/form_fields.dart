import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';

/// Champs de formulaire réutilisables, homogènes dans toute l'application.

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.suffixText,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : 1,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'Champ obligatoire';
        }
        return validator?.call(v);
      },
    ),
  );
}

class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: controller,
    label: label,
    required: required,
    suffixText: '€',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,. ]'))],
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      return Money.parse(v) == null ? 'Montant invalide' : null;
    },
  );
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;
  final bool clearable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          suffixIcon: clearable && value != null
              ? IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? '—' : Dates.day(value!)),
      ),
    ),
  );
}

/// Deux champs côte à côte sur grand écran, empilés sur téléphone.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 520) return Column(children: children);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}

String? emailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
  return ok ? null : 'Adresse e-mail invalide';
}
