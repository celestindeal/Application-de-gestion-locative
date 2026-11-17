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

  Lease copyWith({
    String? propertyId,
    List<String>? tenantIds,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? rentCents,
    int? chargesCents,
    int? dueDay,
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
    depositCents: (json['depositCents'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
    createdAt: Dates.tryParseIso(json['createdAt']),
  );
}
