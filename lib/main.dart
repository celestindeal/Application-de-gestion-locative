import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'data/database_factory.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'services/gmail_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');

  final db = await openLocalDatabase();

  // Pré-charge le SDK Google pour que la fenêtre d'autorisation Gmail
  // s'ouvre instantanément au moment du clic.
  final gmail = GmailService(SettingsRepository(db));
  final settings = await SettingsRepository(db).get();
  if (settings.isGmailConfigured) {
    gmail.init(settings.googleClientId).catchError((Object e) {
      debugPrint('Initialisation Google impossible : $e');
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        gmailServiceProvider.overrideWithValue(gmail),
      ],
      child: const GestionLocativeApp(),
    ),
  );
}
