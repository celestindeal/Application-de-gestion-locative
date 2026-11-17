import '../core/format.dart';
import 'entity.dart';

/// Un paiement de loyer reçu pour un mois donné, et la quittance associée.
///
/// Les montants dus sont recopiés depuis le bail au moment de la validation :
/// si le loyer est révisé plus tard, l'historique reste juste.
class RentPayment implements Entity {
  RentPayment({
    required this.id,
    required this.leaseId,
    required this.propertyId,
    required this.year,
    required this.month,
    required this.rentCents,
    required this.chargesCents,
    required this.paidCents,
    required this.paymentDate,
    required this.receiptNumber,
    this.sentAt,
    this.sentTo = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  final String id;
  final String leaseId;
  final String propertyId;
  final int year;
  final int month;
  final int rentCents;
  final int chargesCents;
  final int paidCents;
  final DateTime paymentDate;

  /// Ex. "2026-007"
  final String receiptNumber;

  /// Date d'envoi du mail de quittance (null = pas encore envoyée).
  final DateTime? sentAt;
  final List<String> sentTo;
  final DateTime createdAt;

  int get dueCents => rentCents + chargesCents;

  /// Paiement partiel : on émet un reçu, pas une quittance (loi du 6/07/1989).
  bool get isPartial => paidCents < dueCents;
  int get remainingCents => isPartial ? dueCents - paidCents : 0;

  String get periodLabel => Dates.monthYear(year, month);

  RentPayment copyWith({
    int? paidCents,
    DateTime? paymentDate,
    DateTime? sentAt,
    List<String>? sentTo,
  }) => RentPayment(
    id: id,
    leaseId: leaseId,
    propertyId: propertyId,
    year: year,
    month: month,
    rentCents: rentCents,
    chargesCents: chargesCents,
    paidCents: paidCents ?? this.paidCents,
    paymentDate: paymentDate ?? this.paymentDate,
    receiptNumber: receiptNumber,
    sentAt: sentAt ?? this.sentAt,
    sentTo: sentTo ?? this.sentTo,
    createdAt: createdAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'leaseId': leaseId,
    'propertyId': propertyId,
    'year': year,
    'month': month,
    'rentCents': rentCents,
    'chargesCents': chargesCents,
    'paidCents': paidCents,
    'paymentDate': Dates.isoDate(paymentDate),
    'receiptNumber': receiptNumber,
    'sentAt': sentAt?.toIso8601String(),
    'sentTo': sentTo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RentPayment.fromJson(Map<String, Object?> json) => RentPayment(
    id: json['id'] as String,
    leaseId: json['leaseId'] as String,
    propertyId: json['propertyId'] as String? ?? '',
    year: (json['year'] as num).toInt(),
    month: (json['month'] as num).toInt(),
    rentCents: (json['rentCents'] as num?)?.toInt() ?? 0,
    chargesCents: (json['chargesCents'] as num?)?.toInt() ?? 0,
    paidCents: (json['paidCents'] as num?)?.toInt() ?? 0,
    paymentDate: Dates.tryParseIso(json['paymentDate']) ?? DateTime.now(),
    receiptNumber: json['receiptNumber'] as String? ?? '',
    sentAt: Dates.tryParseIso(json['sentAt']),
    sentTo: (json['sentTo'] as List?)?.cast<String>().toList() ?? const [],
    createdAt: Dates.tryParseIso(json['createdAt']),
  );
}
