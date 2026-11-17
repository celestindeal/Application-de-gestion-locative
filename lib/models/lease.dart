import '../core/format.dart';
import 'entity.dart';

/// Un bail : relie un bien à un ou plusieurs locataires, avec les montants.
class Lease implements Entity {
  Lease({
    required this.id,
    required this.propertyId,
    required this.tenantIds,
    required this.startDate,
    this.endDate,
    required this.rentCents,
    this.chargesCents = 0,
    this.dueDay = 1,
    this.paymentDay = 5,
    this.depositCents = 0,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  final String id;
  final String propertyId;
  final List<String> tenantIds;
  final DateTime startDate;

  /// Null tant que le bail est en cours.
  final DateTime? endDate;

  /// Loyer hors charges, en centimes.
  final int rentCents;

  /// Provision pour charges, en centimes.
  final int chargesCents;

  /// Jour d'échéance du loyer dans le mois.
  final int dueDay;

  /// Jour où le locataire paie habituellement (date proposée par défaut).
  final int paymentDay;
  final int depositCents;
  final String notes;
  final DateTime createdAt;

  int get totalCents => rentCents + chargesCents;

  /// Le bail couvre-t-il (au moins en partie) le mois donné ?
  bool coversMonth(int year, int month) {
    final first = Dates.firstDayOfMonth(year, month);
    final last = Dates.lastDayOfMonth(year, month);
    if (startDate.isAfter(last)) return false;
    if (endDate != null && endDate!.isBefore(first)) return false;
    return true;
  }

  bool get isActive => coversMonth(DateTime.now().year, DateTime.now().month);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Premier jour du mois couvert par le bail (date d'entrée si en cours de mois).
  DateTime periodStart(int year, int month) {
    final first = Dates.firstDayOfMonth(year, month);
    final start = _day(startDate);
    return start.isAfter(first) ? start : first;
  }

  /// Dernier jour du mois couvert par le bail (date de sortie si en cours de mois).
  DateTime periodEnd(int year, int month) {
    final last = Dates.lastDayOfMonth(year, month);
    if (endDate == null) return last;
    final end = _day(endDate!);
    return end.isBefore(last) ? end : last;
  }

  /// Nombre de jours occupés dans le mois.
  int occupiedDays(int year, int month) {
    if (!coversMonth(year, month)) return 0;
    return periodEnd(year, month).difference(periodStart(year, month)).inDays +
        1;
  }

  /// Entrée ou sortie en cours de mois : loyer et charges au prorata des jours.
  bool isProrated(int year, int month) =>
      occupiedDays(year, month) < Dates.lastDayOfMonth(year, month).day;

  int _prorata(int cents, int year, int month) {
    if (!isProrated(year, month)) return cents;
    final days = Dates.lastDayOfMonth(year, month).day;
    return (cents * occupiedDays(year, month) / days).round();
  }

  int rentForMonth(int year, int month) => _prorata(rentCents, year, month);
  int chargesForMonth(int year, int month) =>
      _prorata(chargesCents, year, month);
  int totalForMonth(int year, int month) =>
      rentForMonth(year, month) + chargesForMonth(year, month);

  /// Date de paiement proposée par défaut : le jour de paiement habituel du
  /// mois, jamais avant l'entrée dans les lieux, jamais dans le futur.
  DateTime defaultPaymentDate(int year, int month, {DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final lastDay = Dates.lastDayOfMonth(year, month).day;
    var date = DateTime(year, month, paymentDay.clamp(1, lastDay));
    final start = periodStart(year, month);
    if (date.isBefore(start)) date = start;
    if (date.isAfter(now)) date = now;
    return date;
  }

  Lease copyWith({
    String? propertyId,
    List<String>? tenantIds,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? rentCents,
    int? chargesCents,
    int? dueDay,
    int? paymentDay,
    int? depositCents,
    String? notes,
  }) => Lease(
    id: id,
    propertyId: propertyId ?? this.propertyId,
    tenantIds: tenantIds ?? this.tenantIds,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    rentCents: rentCents ?? this.rentCents,
    chargesCents: chargesCents ?? this.chargesCents,
    dueDay: dueDay ?? this.dueDay,
    paymentDay: paymentDay ?? this.paymentDay,
    depositCents: depositCents ?? this.depositCents,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'propertyId': propertyId,
    'tenantIds': tenantIds,
    'startDate': Dates.isoDate(startDate),
    'endDate': endDate == null ? null : Dates.isoDate(endDate!),
    'rentCents': rentCents,
    'chargesCents': chargesCents,
    'dueDay': dueDay,
    'paymentDay': paymentDay,
    'depositCents': depositCents,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Lease.fromJson(Map<String, Object?> json) => Lease(
    id: json['id'] as String,
    propertyId: json['propertyId'] as String,
    tenantIds:
        (json['tenantIds'] as List?)?.cast<String>().toList() ?? const [],
    startDate: Dates.tryParseIso(json['startDate']) ?? DateTime.now(),
    endDate: Dates.tryParseIso(json['endDate']),
    rentCents: (json['rentCents'] as num?)?.toInt() ?? 0,
    chargesCents: (json['chargesCents'] as num?)?.toInt() ?? 0,
    dueDay: (json['dueDay'] as num?)?.toInt() ?? 1,
    paymentDay: (json['paymentDay'] as num?)?.toInt() ?? 5,
    depositCents: (json['depositCents'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
    createdAt: Dates.tryParseIso(json['createdAt']),
  );
}
