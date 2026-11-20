# Gestion locative : serveur de données

Ce module garde les données de l'app de gestion locative (biens, locataires,
baux, paiements, paramètres du bailleur) et les partage entre tous les
appareils et utilisateurs. Pour un même élément, la modification la plus
récente gagne.

Il contient **deux bases complètement séparées** :

| Base | Adresse publique | Utilisée par |
| --- | --- | --- |
| PROD | `https://gestion-locative.<réseau>.ts.net` | l'app de tous les jours |
| TEST | `https://gestion-locative.<réseau>.ts.net:8443` | l'app de test (bandeau TEST) |

## Mise en route

1. Onglet **Configuration** : saisissez deux clés **différentes**, `cle_prod`
   et `cle_test` (20 caractères minimum : lettres, chiffres, tirets).
   Enregistrez.
2. Onglet **Info** : activez **Démarrage au boot** et **Chien de garde**, puis
   **Démarrer**. Ouvrez l'onglet **Journal**.
3. Au premier démarrage, un lien `https://login.tailscale.com/…` s'affiche.
   Ouvrez-le et connectez-vous avec votre compte Tailscale.
4. Si un lien pour **Funnel** s'affiche, ouvrez-le et acceptez, puis
   **redémarrez le module**.
5. Le journal affiche les deux adresses. Dans l'app (prod, puis test) :
   Paramètres › Synchronisation, vérifiez l'adresse, collez la clé
   correspondante, puis **Connecter**.

## Bon à savoir

- **Données** : stockées sur cette machine (`/data/pb_prod` et `/data/pb_test`),
  incluses dans les **sauvegardes de Home Assistant**.
- **Sécurité** : sans la clé, le serveur ne montre et n'accepte rien. La clé
  n'est pas dans le code de l'app (site public) : elle est saisie sur chaque
  appareil. Personne ne peut supprimer de données depuis l'app (une
  suppression est seulement un marquage). Seul le site celestindeal.github.io
  peut appeler le serveur depuis un navigateur.
- **Tableau de bord PocketBase** : `https://<adresse>/_/` (prod) et
  `https://<adresse>:8443/_/` (test). Créez tout de suite un compte
  administrateur sur chacun (lien affiché dans le journal), avec un mot de
  passe solide : les adresses sont publiques.
- **Le module se surveille seul** : toutes les 3 minutes, il teste ses deux
  adresses depuis Internet. Après 2 échecs, il recrée Funnel ; après 4, il
  s'arrête et le chien de garde le relance.
- **Si le module est arrêté**, l'app continue de fonctionner : chaque appareil
  garde ses changements et les envoie quand le serveur revient.
