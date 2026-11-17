import 'package:intl/intl.dart';

/// Les montants sont stockés en centimes (int) pour éviter les erreurs
/// d'arrondi des nombres flottants — indispensable pour la future comptabilité.
abstract final class Money {
  static final _fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  static final _plain = NumberFormat('#,##0.00', 'fr_FR');

  /// 65050 -> "650,50 €"
  static String format(int cents) => _fmt.format(cents / 100);

  /// 65050 -> "650,50" (pour pré-remplir un champ de saisie)
  static String toInput(int cents) =>
      _plain.format(cents / 100).replaceAll(' ', '').replaceAll(' ', '');

  /// "650,50" / "650.5" / "1 200" -> centimes. Renvoie null si invalide.
  static int? parse(String? input) {
    if (input == null) return null;
    final cleaned = input
        .replaceAll(RegExp(r'[\s  €]'), '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }
}

abstract final class Dates {
  static final _day = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final _monthYear = DateFormat('MMMM yyyy', 'fr_FR');
  static final _long = DateFormat('d MMMM yyyy', 'fr_FR');

  static String day(DateTime d) => _day.format(d);
  static String long(DateTime d) => _long.format(d);

  /// "novembre 2026"
  static String monthYear(int year, int month) =>
      _monthYear.format(DateTime(year, month));

  /// "Novembre 2026"
  static String monthYearCapitalized(int year, int month) {
    final s = monthYear(year, month);
    return s[0].toUpperCase() + s.substring(1);
  }

  static DateTime firstDayOfMonth(int year, int month) => DateTime(year, month);
  static DateTime lastDayOfMonth(int year, int month) =>
      DateTime(year, month + 1, 0);

  static DateTime? tryParseIso(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Date sans heure, au format ISO "2026-11-17".
  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
