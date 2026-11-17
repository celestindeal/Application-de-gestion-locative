import '../core/format.dart';

/// Paramètres du bailleur (une seule instance). Sert pour l'en-tête des
/// quittances et pour l'envoi des mails.
class LandlordSettings {
  const LandlordSettings({
    this.name = '',
    this.address = '',
    this.postalCode = '',
    this.city = '',
    this.email = '',
    this.signatureCity = '',
    this.googleClientId = '',
    this.sendCopyToSelf = true,
    this.emailSubject = defaultSubject,
    this.emailBody = defaultBody,
    this.gmailAccessToken,
    this.gmailTokenExpiry,
  });

  static const defaultSubject = 'Quittance de loyer - {periode}';
  static const defaultBody =
      'Bonjour {locataire},\n\n'
      'Veuillez trouver ci-joint votre quittance de loyer pour {periode} '
      '({montant}) concernant le logement situé {adresse}.\n\n'
      'Bien cordialement,\n{bailleur}';

  final String name;
  final String address;
  final String postalCode;
  final String city;

  /// Adresse Gmail du bailleur (copie cachée des quittances).
  final String email;

  /// Ville du "Fait à …" sur la quittance (par défaut la ville du bailleur).
  final String signatureCity;

  /// Identifiant client OAuth "Application Web" de Google Cloud.
  final String googleClientId;
  final bool sendCopyToSelf;
  final String emailSubject;
  final String emailBody;

  /// Jeton d'accès Gmail (validité ~1 h), mémorisé pour éviter de
  /// redemander l'autorisation Google à chaque clic.
  final String? gmailAccessToken;
  final DateTime? gmailTokenExpiry;

  bool get isLandlordComplete => name.trim().isNotEmpty && address.isNotEmpty;
  bool get isGmailConfigured => googleClientId.trim().isNotEmpty;

  String get fullAddress => [
    address,
    [postalCode, city].where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.trim().isNotEmpty).join(', ');

  String get effectiveSignatureCity =>
      signatureCity.trim().isNotEmpty ? signatureCity : city;

  String? get validGmailToken {
    final expiry = gmailTokenExpiry;
    if (gmailAccessToken == null || expiry == null) return null;
    // Marge de sécurité de 2 minutes.
    if (expiry.isBefore(DateTime.now().add(const Duration(minutes: 2)))) {
      return null;
    }
    return gmailAccessToken;
  }

  LandlordSettings copyWith({
    String? name,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? signatureCity,
    String? googleClientId,
    bool? sendCopyToSelf,
    String? emailSubject,
    String? emailBody,
    String? gmailAccessToken,
    DateTime? gmailTokenExpiry,
    bool clearToken = false,
  }) => LandlordSettings(
    name: name ?? this.name,
    address: address ?? this.address,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    email: email ?? this.email,
    signatureCity: signatureCity ?? this.signatureCity,
    googleClientId: googleClientId ?? this.googleClientId,
    sendCopyToSelf: sendCopyToSelf ?? this.sendCopyToSelf,
    emailSubject: emailSubject ?? this.emailSubject,
    emailBody: emailBody ?? this.emailBody,
    gmailAccessToken: clearToken
        ? null
        : (gmailAccessToken ?? this.gmailAccessToken),
    gmailTokenExpiry: clearToken
        ? null
        : (gmailTokenExpiry ?? this.gmailTokenExpiry),
  );

  /// [includeSecrets] = false pour l'export de sauvegarde (pas de jeton).
  Map<String, Object?> toJson({bool includeSecrets = true}) => {
    'name': name,
    'address': address,
    'postalCode': postalCode,
    'city': city,
    'email': email,
    'signatureCity': signatureCity,
    'googleClientId': googleClientId,
    'sendCopyToSelf': sendCopyToSelf,
    'emailSubject': emailSubject,
    'emailBody': emailBody,
    if (includeSecrets) ...{
      'gmailAccessToken': gmailAccessToken,
      'gmailTokenExpiry': gmailTokenExpiry?.toIso8601String(),
    },
  };

  factory LandlordSettings.fromJson(Map<String, Object?>? json) {
    if (json == null) return const LandlordSettings();
    return LandlordSettings(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      city: json['city'] as String? ?? '',
      email: json['email'] as String? ?? '',
      signatureCity: json['signatureCity'] as String? ?? '',
      googleClientId: json['googleClientId'] as String? ?? '',
      sendCopyToSelf: json['sendCopyToSelf'] as bool? ?? true,
      emailSubject: json['emailSubject'] as String? ?? defaultSubject,
      emailBody: json['emailBody'] as String? ?? defaultBody,
      gmailAccessToken: json['gmailAccessToken'] as String?,
      gmailTokenExpiry: Dates.tryParseIso(json['gmailTokenExpiry']),
    );
  }
}
