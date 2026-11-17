# Gestion locative

Application web (Flutter) de gestion locative, utilisable sur ordinateur et sur iPhone
sans passer par les stores (application web installable / PWA).

**Version actuelle (MVP)** : saisir ses biens, ses locataires et ses baux, puis, en un
clic sur « Paiement reçu », enregistrer le loyer du mois et envoyer automatiquement la
quittance PDF au locataire depuis son propre compte Gmail.

## Version en ligne

<https://celestindeal.github.io/Application-de-gestion-locative/>

Publiée automatiquement par GitHub Actions à chaque push sur `main`
(`.github/workflows/deploy.yml`). Le code est public, mais **aucune donnée** n'est
sur GitHub : biens, locataires et quittances restent dans le navigateur de chaque
appareil.

## Démarrer en local

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) (stable).

```bash
flutter pub get
```

**Développement** (rechargement à chaud, dans Chrome) — garder le port 8080, c'est celui
déclaré chez Google pour Gmail :

```bash
flutter run -d chrome --web-port 8080
```

**Version compilée** (plus rapide) :

```bash
flutter build web
```

```bash
dart run tool/serve.dart
```

puis ouvrir <http://localhost:8080>.

Première utilisation : suivre le guide « Pour bien démarrer » de l'accueil, et
[configurer Gmail](docs/CONFIGURATION_GMAIL.md) (une seule fois, gratuit).

## Utilisation

1. **Paramètres** : nom et adresse du bailleur (en-tête des quittances), Gmail.
2. **Biens** → *Ajouter un bien* → sur la fiche du bien, *Nouveau bail* (locataire(s),
   loyer hors charges, provision pour charges, date de début).
3. **Accueil** : chaque mois, cliquez **Paiement reçu** → la quittance part par mail.
   - L'icône ⚙ à côté permet de saisir un autre montant ou une autre date. Un montant
     inférieur au dû génère un **reçu de paiement partiel** (et non une quittance,
     conformément à la loi du 6 juillet 1989).
   - Le menu ⋮ d'un loyer payé permet de voir, télécharger, renvoyer la quittance ou
     annuler le paiement.
4. **Quittances** : historique complet, groupé par année.

## Données

Pour l'instant, **les données sont stockées uniquement dans le navigateur** de
l'appareil (IndexedDB). Conséquences :

- l'ordinateur et l'iPhone ont chacun leurs propres données ;
- vider les données du navigateur efface tout.

👉 **Paramètres → Exporter une sauvegarde** régulièrement (fichier JSON). Ce fichier
permet aussi de transférer les données d'un appareil à l'autre (*Restaurer*).

La synchronisation entre appareils et utilisateurs viendra avec le serveur sur le
Raspberry Pi (voir Feuille de route).

## Utiliser l'application sur iPhone

L'iPhone doit accéder à l'application via une adresse **HTTPS** (exigence de Google
pour la connexion Gmail et de Safari pour l'installation). La version GitHub Pages
ci-dessus convient. Autres options :

| Option | Coût | Remarques |
| --- | --- | --- |
| Raspberry Pi (Caddy + nom de domaine ou Tailscale) | Gratuit | Cible finale, accueillera aussi la base partagée |
| Cloudflare Pages / Netlify / Firebase Hosting | Gratuit | Hébergement de `build/web`, dépôt privé possible |
| GitHub Pages | Gratuit | Nécessite un dépôt public (le code ne contient aucune donnée personnelle) |

Ensuite, dans Safari : **Partager → Sur l'écran d'accueil**. L'application s'ouvre en
plein écran comme une app native. Ne pas oublier d'ajouter l'adresse HTTPS aux
« Origines JavaScript autorisées » côté Google.

## Architecture

```
lib/
  main.dart              Démarrage : base locale, SDK Google, ProviderScope
  app/                   MaterialApp, thème, routes (go_router), navigation adaptative
  core/                  Formats (€, dates), widgets et champs communs, accès fichiers web
  models/                Entités métier sérialisables en JSON (montants en centimes)
  data/                  Repository<T> abstrait + implémentation locale (Sembast/IndexedDB)
                         + providers Riverpod + sauvegarde JSON
  services/              Gmail (OAuth navigateur + API REST), construction MIME
  features/<module>/     Un dossier par fonctionnalité (écrans + logique)
    dashboard/ properties/ tenants/ leases/ receipts/ settings/
test/                    Tests unitaires (montants, baux, MIME, PDF, sauvegarde)
tool/serve.dart          Petit serveur statique pour build/web
```

Choix structurants, pensés pour la suite :

- **Repository abstrait** (`data/repository.dart`) : les écrans ne connaissent pas le
  stockage. Passer au serveur Raspberry Pi = écrire un `HttpRepository` et le brancher
  dans `data/providers.dart`, sans toucher aux écrans.
- **Modèles JSON** avec identifiants UUID : prêts pour une API REST et pour la
  synchronisation multi-appareils.
- **Montants en centimes (int)** : aucune erreur d'arrondi, indispensable pour la
  comptabilité.
- **Un dossier par fonctionnalité** + une branche de navigation par module.

## Feuille de route (idées)

- [x] Biens, locataires, baux
- [x] Paiement en un clic + quittance PDF envoyée par Gmail
- [ ] Relances de loyers impayés, révision annuelle (IRL)
- [ ] Documents (bail signé, états des lieux, diagnostics)
- [ ] Suivi des chantiers (devis, factures, avancement)
- [ ] Étude de rentabilité à l'achat (rendement, cash-flow, fiscalité)
- [ ] Comptabilité (recettes/dépenses par bien, export déclaration 2044 / LMNP)
- [ ] Serveur sur Raspberry Pi 5 : base partagée, synchronisation, multi-utilisateurs
