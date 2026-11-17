import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../data/providers.dart';
import '../data/settings_repository.dart';
import '../models/landlord_settings.dart';
import 'mime_message.dart';

final gmailServiceProvider = Provider<GmailService>(
  (ref) => GmailService(ref.watch(settingsRepositoryProvider)),
);

class GmailException implements Exception {
  GmailException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Envoi de mails depuis le compte Gmail du bailleur, directement depuis le
/// navigateur, via l'API Gmail (OAuth 2, scope `gmail.send` uniquement :
/// l'application peut envoyer des mails mais pas lire la boîte).
class GmailService {
  GmailService(this._settings);

  static const scope = 'https://www.googleapis.com/auth/gmail.send';
  static const _sendUrl =
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send';

  final SettingsRepository _settings;
  String? _initializedClientId;
  Future<void>? _initFuture;

  /// Charge le SDK Google. Appelé au démarrage pour que la fenêtre
  /// d'autorisation puisse s'ouvrir immédiatement au clic.
  Future<void> init(String clientId) {
    if (clientId.isEmpty) return Future.value();
    if (_initializedClientId != null) {
      if (_initializedClientId != clientId) {
        throw GmailException(
          "L'identifiant Google a changé : rechargez la page pour l'appliquer.",
        );
      }
      return _initFuture!;
    }
    _initializedClientId = clientId;
    return _initFuture = GoogleSignIn.instance.initialize(clientId: clientId);
  }

  /// Renvoie un jeton d'accès valide, en demandant l'autorisation à
  /// l'utilisateur si nécessaire (fenêtre Google).
  ///
  /// Passer [current] (paramètres déjà en mémoire) évite une lecture en base
  /// avant l'ouverture de la fenêtre Google : les navigateurs (Safari surtout)
  /// bloquent les popups ouvertes trop longtemps après le clic.
  Future<String> accessToken({
    LandlordSettings? current,
    bool forcePrompt = false,
  }) async {
    final settings = current ?? await _settings.get();
    if (!settings.isGmailConfigured) {
      throw GmailException(
        "Gmail n'est pas configuré (Paramètres > Envoi des mails).",
      );
    }
    if (!forcePrompt && settings.validGmailToken != null) {
      return settings.validGmailToken!;
    }
    await init(settings.googleClientId);
    try {
      final auth = await GoogleSignIn.instance.authorizationClient
          .authorizeScopes(const [scope]);
      // Les jetons Google sont valables 1 h.
      await _settings.save(
        (await _settings.get()).copyWith(
          gmailAccessToken: auth.accessToken,
          gmailTokenExpiry: DateTime.now().add(const Duration(minutes: 55)),
        ),
      );
      return auth.accessToken;
    } on GoogleSignInException catch (e) {
      throw GmailException(
        "Autorisation Google refusée ou annulée (${e.description ?? e.code.name}).",
      );
    }
  }

  Future<void> send(MimeMessage message, {String? token}) async {
    token ??= await accessToken();
    var response = await _post(token, message);
    if (response.statusCode == 401) {
      // Jeton expiré ou révoqué : on en redemande un.
      await _clearToken(token);
      token = await accessToken(forcePrompt: true);
      response = await _post(token, message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        detail =
            (jsonDecode(response.body)['error']['message'] as String?) ??
            detail;
      } catch (_) {}
      throw GmailException(
        'Échec de l\'envoi (${response.statusCode}) : $detail',
      );
    }
  }

  Future<http.Response> _post(String token, MimeMessage message) => http.post(
    Uri.parse(_sendUrl),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'raw': message.toGmailRaw()}),
  );

  Future<void> _clearToken(String token) async {
    await _settings.save((await _settings.get()).copyWith(clearToken: true));
    try {
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } catch (_) {}
  }

  Future<void> disconnect() async {
    final s = await _settings.get();
    if (s.gmailAccessToken != null) await _clearToken(s.gmailAccessToken!);
  }
}
