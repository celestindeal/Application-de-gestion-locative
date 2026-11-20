# Serveur de données sur la Raspberry Pi (prod et test)

Ce document explique comment les données de l'app sont partagées entre tous
les appareils et utilisateurs, comment installer le serveur sur la
Raspberry Pi, et comment l'entretenir.

> **Ne jamais écrire une clé dans ce dépôt (il est public), ni dans le code.**

---

## 1. Vue d'ensemble

```
App PROD  (github.io/Application-de-gestion-locative/)       ──HTTPS :443──▶ ┐
                                                                             │  Tailscale Funnel
App TEST  (github.io/Application-de-gestion-locative/test/)  ──HTTPS :8443─▶ ┤  (adresse publique,
                                                                             │   aucun port ouvert
                                                                             ▼   sur la box)
                         Raspberry Pi 5 › Home Assistant › module « Gestion locative »
                           ├─ PocketBase PROD  127.0.0.1:8090  données : /data/pb_prod  clé : cle_prod
                           └─ PocketBase TEST  127.0.0.1:8091  données : /data/pb_test  clé : cle_test
```

| | PROD | TEST |
|---|---|---|
| App | <https://celestindeal.github.io/Application-de-gestion-locative/> | <https://celestindeal.github.io/Application-de-gestion-locative/test/> |
| Adresse du serveur | `https://gestion-locative.tail8a91ff.ts.net` | `https://gestion-locative.tail8a91ff.ts.net:8443` |
| Base PocketBase | `/data/pb_prod` (port interne 8090) | `/data/pb_test` (port interne 8091) |
| Clé | option `cle_prod` | option `cle_test` |
| Sites autorisés (CORS) | `https://celestindeal.github.io` | idem + `http://localhost:8080` (développement) |

**Les bases prod et test sont complètement séparées** : deux programmes
PocketBase distincts, deux fichiers de base distincts, deux clés différentes.
Ce qu'on fait dans l'app de test ne peut jamais toucher les vraies données.

Les deux bases sont dans **un seul module** Home Assistant (une seule
installation, une seule connexion Tailscale). Ce module est séparé de celui de
la tournée des pompiers : si l'un plante, l'autre n'est pas touché.

---

## 2. Comment fonctionne la synchronisation (côté app)

- **Chaque appareil garde toutes ses données en local** (base du navigateur).
  L'app marche donc sans réseau, comme avant.
- Chaque modification (bien, locataire, bail, paiement, paramètres du
  bailleur) est notée dans une **file d'attente** sur l'appareil, avec l'heure
  de la modification (`t`, en millisecondes).
- **Toutes les 30 s**, 2 s après chaque modification et au retour dans l'app :
  1. la file d'attente est envoyée au serveur ;
  2. l'app reçoit ce qui a changé sur le serveur depuis son dernier passage
     (filtre sur le champ `updated`).
- **Conflits : la plus récente gagne.** Le serveur refuse une mise à jour plus
  ancienne que celle qu'il a (règle `@request.body.t > t`).
- **Suppressions** : jamais de vraie suppression sur le serveur. L'élément est
  marqué `supprime = true`, et les autres appareils le suppriment chez eux.
- **Première connexion d'un appareil** : il récupère tout ce que le serveur a,
  puis envoie ce qu'il a en plus (données saisies avant la synchronisation).
  Rien n'est perdu.
- **Ce qui n'est jamais envoyé** : le jeton Gmail (propre à chaque appareil),
  l'adresse du serveur et la clé.

Code : `lib/data/sync/` (`sync_queue.dart`, `sync_remote.dart`,
`sync_service.dart`, `synced_repository.dart`, `sync_config.dart`).
Tests : `test/sync_test.dart` (avec un faux serveur qui applique les mêmes
règles que PocketBase).

### Où est la clé ?

Contrairement à l'app des pompiers, **la clé n'est pas intégrée au site**.
Le site est public : une clé intégrée serait lisible par n'importe qui dans
le code de la page, et ici les données sont personnelles (noms, adresses,
e-mails des locataires, loyers). La clé est donc **saisie une fois sur chaque
appareil**, dans *Paramètres › Synchronisation*, et ne quitte jamais
l'appareil (elle n'est pas dans les sauvegardes exportées).

---

## 3. Le module (dans ce dépôt)

| Fichier | Rôle |
|---|---|
| `repository.yaml` (racine) | Déclare le dépôt GitHub comme « dépôt de modules » Home Assistant |
| `serveur/config.yaml` | Nom, **version**, slug `gestion_locative`, options (`cle_prod`, `cle_test`, `nom_tailscale`) |
| `serveur/Dockerfile` | Image : Alpine + PocketBase 0.40.6 (empreinte vérifiée) + Tailscale |
| `serveur/run.sh` | Démarre les deux PocketBase, Tailscale, le certificat, Funnel (443 et 8443), la surveillance |
| `serveur/pb_hooks/gestion_locative.pb.js` | Crée les tables et les règles d'accès au démarrage (même fichier pour les deux bases) |
| `serveur/DOCS.md` | Notice affichée dans Home Assistant |
| `serveur/translations/fr.yaml` | Libellés des options dans Home Assistant |

Tables créées dans chaque base :

- `donnees` : un enregistrement par élément de l'app. Champs : `type`
  (`bien`, `locataire`, `bail`, `paiement`, `parametres`), `uid` (identifiant
  de l'app), `data` (l'élément en JSON), `supprime`, `t`, `appareil`,
  `created`, `updated`. Identifiant PocketBase (15 caractères) : la lettre du
  type + les 14 premiers caractères de l'identifiant de l'app.
- `acces` : sert seulement à vérifier la clé.

Règles : lecture et création avec la clé ; modification avec la clé et
seulement si plus récente ; suppression interdite.

---

## 4. Installation sur la Raspberry Pi (une seule fois)

### 4.1 Choisir les deux clés

Deux clés **différentes**, 20 caractères minimum (lettres, chiffres, tirets).
Pour en fabriquer une au hasard, dans PowerShell sur le PC :

```powershell
-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Lancez la commande deux fois (une clé prod, une clé test) et gardez-les dans
votre gestionnaire de mots de passe.

### 4.2 Installer le module

Dans Home Assistant (`http://192.168.1.201:8123`) :

1. **Paramètres › Modules (Apps) › Boutique › menu ⋮ › Dépôts** : ajouter
   `https://github.com/celestindeal/Application-de-gestion-locative#test`
   (`#test` = la branche `test`, voir § 6).
2. Fermer, puis **⋮ › Rechercher des mises à jour**. Le module
   **Gestion locative** apparaît : **Installer** (quelques minutes, l'image est
   construite sur la Pi).
3. Onglet **Configuration** : coller `cle_prod` et `cle_test`, laisser
   `nom_tailscale` à `gestion-locative`. **Enregistrer**.
4. Onglet **Info** : activer **Démarrage au boot** et **Chien de garde**, puis
   **Démarrer**.
5. Onglet **Journal** :
   - un lien `https://login.tailscale.com/…` s'affiche : l'ouvrir et se
     connecter avec le **même compte Tailscale** que pour les pompiers ;
   - si un lien pour autoriser **Funnel** s'affiche, l'ouvrir aussi, puis
     **redémarrer le module** ;
   - attendre les lignes :
     ```
     [locatif] Serveur prêt.
     [locatif]   PROD : https://gestion-locative.tail8a91ff.ts.net
     [locatif]   TEST : https://gestion-locative.tail8a91ff.ts.net:8443
     ```
6. **Vérifier** dans un navigateur :
   - <https://gestion-locative.tail8a91ff.ts.net/api/health>
   - <https://gestion-locative.tail8a91ff.ts.net:8443/api/health>

   Les deux doivent afficher `{"message":"API is healthy."…}`.

Si l'adresse affichée dans le journal est différente (autre nom de réseau
Tailscale), la saisir dans l'app (§ 4.4) ; et la corriger dans
`lib/core/env.dart` (`defaultServerUrl`) pour qu'elle soit proposée par défaut.

### 4.3 Créer les comptes administrateur PocketBase (important)

Les adresses sont publiques : il faut créer **tout de suite** un compte
administrateur sur chaque base, sinon quelqu'un d'autre pourrait le faire.

- Au premier démarrage, le **Journal** affiche pour chaque base un lien à
  usage unique `…/_/#/pbinstal/…`. L'ouvrir en remplaçant le début par
  l'adresse publique (`https://gestion-locative.tail8a91ff.ts.net/_/…` pour la
  prod, `…ts.net:8443/_/…` pour le test).
- Créer le compte avec un **mot de passe solide** (différent pour prod et test).
- Tableau de bord ensuite : `https://<adresse>/_/` et `https://<adresse>:8443/_/`.

### 4.4 Relier chaque appareil

Sur chaque appareil (PC, iPhone, autre utilisateur), **dans l'app de prod** :

1. **Paramètres › Synchronisation** : l'adresse est déjà proposée ; coller la
   **clé prod** ; **Connecter**.
2. Le statut passe à « À jour ». La première fois, les données déjà saisies
   sur l'appareil sont envoyées au serveur.

Puis la même chose **dans l'app de test**, avec la **clé test**.

> Conseil pour le premier appareil : connectez d'abord celui qui a les
> données les plus complètes (le PC), puis les autres : ils récupèrent tout et
> n'envoient que ce qu'ils ont en plus.

---

## 5. Sauvegardes

- Les **sauvegardes de Home Assistant** (Paramètres › Système › Sauvegardes)
  incluent le `/data` du module, donc **les deux bases**. Avec
  `backup: cold`, le module est arrêté pendant la sauvegarde pour copier les
  bases au repos.
- Les données sont sur la **carte SD**. Pensez à envoyer les sauvegardes sur
  la clé USB ou ailleurs (Paramètres › Système › Stockage).
- L'export JSON de l'app (Paramètres › Sauvegarde) reste disponible en plus.

---

## 6. Mettre à jour le module

Le module est installé depuis la **branche `test`** du dépôt
(`…Application-de-gestion-locative#test`), comme pour les pompiers.
Le module contient la prod **et** le test : une mise à jour du module touche
les deux bases (les données, elles, ne bougent pas).

1. Modifier les fichiers de `serveur/`, **augmenter `version`** dans
   `serveur/config.yaml`, pousser sur `test`.
2. Home Assistant : **Paramètres › Modules › Boutique › ⋮ › Rechercher des
   mises à jour**, puis **Mettre à jour** sur le module.
3. Vérifier le journal et les deux `/api/health`.

Les modifications de l'**app** (pas du module) suivent le circuit habituel :
branche `test` → validation sur l'app de test → `main` (prod).

---

## 7. Administration

| Action | Où |
|---|---|
| Voir / corriger des données | Tableau de bord PocketBase `https://<adresse>/_/` (prod) ou `:8443/_/` (test) |
| Journal | Home Assistant › module › onglet *Journal* |
| Redémarrer | onglet *Info* › *Redémarrer* |
| Changer une clé | onglet *Configuration*, redémarrer, puis *Reconnecter* sur chaque appareil avec la nouvelle clé |
| Repartir d'une base test vide | arrêter le module, supprimer les enregistrements de `donnees` dans le tableau de bord test, redémarrer ; sur chaque app de test : *Déconnecter* puis *Connecter* |

---

## 8. Pannes connues (gérées dans `run.sh`)

| Symptôme | Cause | Ce que fait `run.sh` |
|---|---|---|
| Serveur injoignable après un changement de Wi-Fi | Tailscale pas encore connecté, certificat pas obtenu | Attend l'état `Running`, redemande le certificat toutes les 30 s |
| Serveur injoignable après une coupure de courant | Funnel gardé d'avant mais plus annoncé | `tailscale serve reset` puis Funnel 443 et 8443 **à chaque démarrage** |
| Adresse publique qui tombe en cours de route | Relais Tailscale | Teste les deux `/api/health` toutes les 3 min : Funnel recréé après 2 échecs, module relancé après 4 (chien de garde) |

Côté app : si le serveur est injoignable, le statut affiche « Serveur
injoignable » et les changements attendent dans la file ; rien n'est perdu.

---

## 9. Essayer en local, sur le PC

Avec le programme `pocketbase` (même version, téléchargé depuis
<https://github.com/pocketbase/pocketbase/releases>) :

```bash
CLE_SYNCHRO=essai-local-1234567890 pocketbase serve --http=127.0.0.1:8091 --dir=pb_data_local --hooksDir=serveur/pb_hooks --origins=http://localhost:8080
```

```bash
flutter run -d chrome --web-port 8080 --dart-define=APP_ENV=test
```

Puis dans l'app : Paramètres › Synchronisation, adresse
`http://127.0.0.1:8091`, clé `essai-local-1234567890`.
