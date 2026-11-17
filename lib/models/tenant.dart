import '../core/format.dart';
import 'entity.dart';

class Tenant implements Entity {
  Tenant({
    required this.id,
    this.civility = '',
    this.firstName = '',
    required this.lastName,
    this.email = '',
    this.phone = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  final String id;

  /// "M.", "Mme" ou vide.
  final String civility;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String notes;
  final DateTime createdAt;

  /// "Jean DUPONT"
  String get displayName =>
      [firstName, lastName.toUpperCase()].where((s) => s.isNotEmpty).join(' ');

  /// "M. Jean DUPONT"
  String get formalName =>
      [civility, displayName].where((s) => s.isNotEmpty).join(' ');

  Tenant copyWith({
    String? civility,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? notes,
  }) => Tenant(
    id: id,
    civility: civility ?? this.civility,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'civility': civility,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Tenant.fromJson(Map<String, Object?> json) => Tenant(
    id: json['id'] as String,
    civility: json['civility'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    createdAt: Dates.tryParseIso(json['createdAt']),
  );
}
