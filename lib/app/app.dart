import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../data/providers.dart';
import 'router.dart';

class GestionLocativeApp extends ConsumerStatefulWidget {
  const GestionLocativeApp({super.key});

  @override
  ConsumerState<GestionLocativeApp> createState() => _GestionLocativeAppState();
}

class _GestionLocativeAppState extends ConsumerState<GestionLocativeApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Synchronisation avec le serveur : au démarrage, toutes les 30 s, et au
    // retour dans l'app.
    final sync = ref.read(syncServiceProvider)..start();
    _lifecycle = AppLifecycleListener(onResume: sync.syncNow);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const _seed = Color(0xFF1F4E79);

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppEnv.isTest ? 'Gestion locative (TEST)' : 'Gestion locative',
    debugShowCheckedModeBanner: false,
    builder: AppEnv.isTest
        ? (context, child) => Banner(
            message: 'TEST',
            location: BannerLocation.topEnd,
            color: Colors.deepOrange,
            child: child!,
          )
        : null,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    routerConfig: appRouter,
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}
