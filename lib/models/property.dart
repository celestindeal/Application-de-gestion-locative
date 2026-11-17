import '../core/format.dart';
import 'entity.dart';

enum PropertyType {
  appartement('Appartement'),
  maison('Maison'),
  studio('Studio'),
  immeuble('Immeuble'),
  parking('Parking / Garage'),
  localCommercial('Local commercial'),
  autre('Autre');

  const PropertyType(this.label);
  final String label;

  static PropertyType fromName(Object? name) => PropertyType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => PropertyType.autre,
  );
}

/// Un bien immobilier (logement, parking, local…).
class Property implements Entity {
  Property({
    required this.id,
    required this.name,
    this.type = PropertyType.appartement,
    this.address = '',
    this.postalCode = '',
    this.city = '',
    this.surface,
    this.rooms,
    this.floor = '',
    this.furnished = false,
    this.purchaseDate,
    this.purchasePriceCents,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  final String id;

  /// Nom court pour s'y retrouver, ex. "T2 rue Victor Hugo".
  final String name;
  final PropertyType type;
  final String address;
  final String postalCode;
  final String city;

  /// Surface habitable en m².
  final double? surface;
  final int? rooms;
  final String floor;
  final bool furnished;

  // Données d'acquisition — utiles plus tard pour la rentabilité.
  final DateTime? purchaseDate;
  final int? purchasePriceCents;

  final String notes;
  final DateTime createdAt;

  String get fullAddress => [
    address,
    [postalCode, city].where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.trim().isNotEmpty).join(', ');

  Property copyWith({
    String? name,
    PropertyType? type,
    String? address,
    String? postalCode,
    String? city,
    double? surface,
    int? rooms,
    String? floor,
    bool? furnished,
    DateTime? purchaseDate,
    int? purchasePriceCents,
    String? notes,
  }) => Property(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    address: address ?? this.address,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    surface: surface ?? this.surface,
    rooms: rooms ?? this.rooms,
    floor: floor ?? this.floor,
    furnished: furnished ?? this.furnished,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'address': address,
    'postalCode': postalCode,
    'city': city,
    'surface': surface,
    'rooms': rooms,
    'floor': floor,
    'furnished': furnished,
    'purchaseDate': purchaseDate == null ? null : Dates.isoDate(purchaseDate!),
    'purchasePriceCents': purchasePriceCents,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Property.fromJson(Map<String, Object?> json) => Property(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type: PropertyType.fromName(json['type']),
    address: json['address'] as String? ?? '',
    postalCode: json['postalCode'] as String? ?? '',
    city: json['city'] as String? ?? '',
    surface: (json['surface'] as num?)?.toDouble(),
    rooms: (json['rooms'] as num?)?.toInt(),
    floor: json['floor'] as String? ?? '',
    furnished: json['furnished'] as bool? ?? false,
    purchaseDate: Dates.tryParseIso(json['purchaseDate']),
    purchasePriceCents: (json['purchasePriceCents'] as num?)?.toInt(),
    notes: json['notes'] as String? ?? '',
    createdAt: Dates.tryParseIso(json['createdAt']),
  );
}
