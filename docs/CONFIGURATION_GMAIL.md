# Configurer l'envoi des quittances par Gmail

L'application envoie les quittances **depuis votre propre compte Gmail**, directement
depuis le navigateur, grâce à l'API Gmail de Google. C'est gratuit. Il faut juste
déclarer l'application une fois auprès de Google (≈ 10 minutes).

L'autorisation demandée est uniquement `gmail.send` : l'application peut **envoyer**
des mails en votre nom, mais **ne peut pas lire** votre boîte de réception.

## 1. Créer un projet Google Cloud

1. Ouvrez <https://console.cloud.google.com/> avec votre compte Gmail.
2. En haut, sélecteur de projet → **Nouveau projet** → nom : `Gestion locative` → **Créer**.

## 2. Activer l'API Gmail

1. Menu ☰ → **API et services** → **Bibliothèque**.
2. Cherchez **Gmail API** → **Activer**.

## 3. Écran de consentement (Google Auth Platform)

1. Menu ☰ → **API et services** → **Écran de consentement OAuth** (ou *Google Auth Platform*).
2. Type d'utilisateur : **Externe**. Nom de l'application : `Gestion locative`.
   E-mail d'assistance et e-mail du développeur : votre Gmail.
3. **Audience** : laissez l'application en mode **Test** et ajoutez votre adresse
   Gmail dans **Utilisateurs test**. (Pas besoin de faire valider l'application par
   Google tant qu'elle est pour vous.)
4. **Accès aux données** (ou *Champs d'application*) → **Ajouter** →
   cherchez `gmail.send` → cochez `https://www.googleapis.com/auth/gmail.send`.

## 4. Créer l'identifiant client

1. **Clients** (ou *Identifiants* → **Créer des identifiants** → **ID client OAuth**).
2. Type d'application : **Application Web**.
3. **Origines JavaScript autorisées** — ajoutez chaque adresse depuis laquelle vous
   ouvrez l'application :
   - `http://localhost:8080` (version locale sur l'ordinateur)
   - `https://celestindeal.github.io` (version en ligne, GitHub Pages — ordinateur et iPhone)
   - plus tard, l'adresse du Raspberry Pi si l'application y est hébergée
4. Pas besoin d'« URI de redirection ».
5. **Créer**, puis copiez l'**ID client** (`xxxxxxxx.apps.googleusercontent.com`).

> L'ID client n'est pas un secret : il identifie l'application, il ne donne accès à rien
> sans votre autorisation explicite.

## 5. Dans l'application

1. **Paramètres** → collez l'ID client, renseignez votre adresse Gmail → **Enregistrer**.
2. Rechargez la page (le SDK Google se charge au démarrage).
3. **Envoyer un mail de test** : une fenêtre Google s'ouvre. Comme l'application est en
   mode test, Google affiche « Google n'a pas validé cette application » :
   cliquez **Continuer**, puis autorisez l'envoi de mails.
4. Vous devez recevoir le mail de test. C'est prêt !

## Fonctionnement au quotidien

- Google délivre une autorisation valable **1 heure**. Au-delà, le prochain clic sur
  « Paiement reçu » rouvre brièvement la fenêtre Google (souvent un simple clic).
- Si la fenêtre ne s'ouvre pas, vérifiez que le navigateur n'a pas bloqué la popup.
- Erreur `origin_mismatch` / `redirect_uri_mismatch` : l'adresse affichée dans la barre
  du navigateur (port compris) n'est pas dans les **Origines JavaScript autorisées**.
