# CLAUDE.md

Application Flutter **web uniquement** (PWA) de gestion locative, en français.
Utilisateur : propriétaire bailleur, usage personnel sur PC et iPhone (Safari).
Voir README.md pour la vision produit et la feuille de route.

## Commandes

- `flutter analyze` — doit rester à 0 problème.
- `flutter test` — tests unitaires (VM, base Sembast en mémoire).
- `dart format lib test`
- `flutter run -d chrome --web-port 8080` — le port 8080 est déclaré comme origine
  OAuth chez Google ; ne pas en changer.
- `flutter build web` puis `dart run tool/serve.dart` — version compilée sur :8080.

## Environnements et processus de livraison (à respecter)

- **test** = branche `test` → https://celestindeal.github.io/Application-de-gestion-locative/test/
- **prod** = branche `main` → https://celestindeal.github.io/Application-de-gestion-locative/
- Chaque nouveau développement est commité sur `test` et poussé : l'utilisateur
  le valide sur l'URL de test. Ne jamais pousser directement sur `main`.
- Quand l'utilisateur valide, mettre en prod : `git checkout main`,
  `git merge --ff-only test`, `git push`, puis revenir sur `test`.
- Un push sur l'une ou l'autre branche republie les deux (workflow
  `.github/workflows/deploy.yml`) ; suivre le run avec `gh run list`.
- `--dart-define=APP_ENV=test` : base IndexedDB séparée (`gestion_locative_test`)
  et bandeau « TEST » (`lib/core/env.dart`). Les deux environnements partagent le
  domaine github.io, donc la même origine OAuth Google.

## Conventions

- Interface, messages, commentaires et noms de routes en **français**.
  Identifiants de code (classes, variables, clés JSON) en **anglais**.
- Montants toujours en **centimes (`int`)** ; affichage via `Money.format`,
  saisie via `Money.parse` (`lib/core/format.dart`).
- Dates de jour sérialisées en `yyyy-MM-dd` (`Dates.isoDate`), horodatages en ISO 8601.
- Chaque entité implémente `Entity` (`id` UUID v4 + `toJson`/`fromJson`). Le JSON est
  le futur format d'échange avec le serveur Raspberry Pi : ajouter des champs avec
  valeur par défaut dans `fromJson`, ne jamais renommer/supprimer une clé sans migration.
- Accès aux données uniquement via `Repository<T>` et les providers de
  `lib/data/providers.dart` — jamais Sembast directement dans un écran.
- État : Riverpod 3 (`Provider`, `StreamProvider`, `ConsumerWidget`). Pas de codegen.
- Navigation : go_router, `StatefulShellRoute` dans `lib/app/router.dart`. Un nouveau
  module = un dossier `lib/features/<module>/` + une branche (et une entrée dans
  `lib/app/shell.dart`).
- Code dépendant du navigateur (`package:web`, `dart:js_interop`) uniquement derrière
  un import conditionnel (`*_stub.dart` / `*_web.dart`) pour que `flutter test` tourne
  sur la VM.
- Après tout `await`, vérifier `context.mounted` avant d'utiliser le `BuildContext`.

## Pièges connus

- **Popups bloquées** (fenêtre Google, nouvel onglet PDF) : elles doivent être ouvertes
  pendant le clic. Ne rien `await` de lent avant `GmailService.accessToken` (passer les
  paramètres déjà en mémoire via `current:`) ni avant `FileIO.openInNewTab`.
- **PDF** : les polices standard (Helvetica) n'ont pas le symbole €. On embarque Roboto
  (`assets/fonts/`, licence Apache 2.0) chargée via `rootBundle`.
- Quittance vs reçu : paiement partiel ⇒ « reçu », jamais « quittance » (loi 89-462, art. 21).
- Données locales au navigateur : l'export/import JSON (`BackupService`) est la seule
  sauvegarde tant que le serveur n'existe pas — le maintenir à jour à chaque nouvelle
  entité.
- Le projet est dans un dossier Google Drive : `build/` et `.dart_tool/` y sont
  synchronisés (lent). Ne pas s'inquiéter de fichiers verrouillés pendant un build.
