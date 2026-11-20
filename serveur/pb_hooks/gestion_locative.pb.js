/// <reference path="../pb_data/types.d.ts" />

// Serveur de données de l'app de gestion locative (PocketBase).
//
// Le même fichier sert aux deux bases (prod et test) : chacune est un
// PocketBase séparé, avec son propre dossier de données et sa propre clé
// (variable d'environnement CLE_SYNCHRO, donnée par run.sh). La clé n'est
// jamais écrite dans ce dépôt public.
//
// À chaque démarrage :
// 1. crée les tables si elles n'existent pas encore ;
// 2. les ouvre aux appareils qui envoient la clé (en-tête « X-Cle-Synchro »).
//
// Table « donnees » : un enregistrement par élément de l'app (bien,
// locataire, bail, paiement, paramètres du bailleur), stocké en JSON.
// Règles :
// - lecture et création : avec la bonne clé ;
// - modification : avec la bonne clé, et seulement si elle est plus récente
//   (champ t, en millisecondes) que celle enregistrée : la plus récente gagne ;
// - suppression : jamais depuis l'app. Une suppression est un enregistrement
//   marqué « supprime », pour qu'elle se propage aux autres appareils.

onBootstrap((e) => {
  e.next();
  const app = e.app;

  const cle = $os.getenv("CLE_SYNCHRO");
  if (!/^[A-Za-z0-9-]{20,}$/.test(cle || "")) {
    throw new Error("CLE_SYNCHRO manquante ou trop courte (20 caractères minimum : lettres, chiffres, tirets).");
  }
  const acces = `@request.headers.x_cle_synchro = "${cle}"`;

  const existe = (nom) => {
    try {
      app.findCollectionByNameOrId(nom);
      return true;
    } catch (_) {
      return false;
    }
  };

  if (!existe("donnees")) {
    app.save(new Collection({
      type: "base",
      name: "donnees",
      fields: [
        { name: "type", type: "text", required: true, max: 20 },
        { name: "uid", type: "text", required: true, max: 64 },
        { name: "data", type: "json", maxSize: 2000000 },
        { name: "supprime", type: "bool" },
        { name: "t", type: "number", required: true, onlyInt: true },
        { name: "appareil", type: "text", max: 40 },
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: ["CREATE INDEX idx_donnees_maj ON donnees (updated)"],
    }));
  }

  // Sert à vérifier la clé : sa liste n'est visible qu'avec la bonne clé.
  if (!existe("acces")) {
    const collection = new Collection({ type: "base", name: "acces", fields: [{ name: "nom", type: "text", max: 40 }] });
    app.save(collection);
    const enregistrement = new Record(collection);
    enregistrement.set("nom", "gestion-locative");
    app.save(enregistrement);
  }

  const donnees = app.findCollectionByNameOrId("donnees");
  donnees.listRule = acces;
  donnees.viewRule = acces;
  donnees.createRule = acces;
  donnees.updateRule = `${acces} && @request.body.t > t`;
  donnees.deleteRule = null;
  app.save(donnees);

  const controle = app.findCollectionByNameOrId("acces");
  controle.listRule = acces;
  controle.viewRule = acces;
  controle.createRule = null;
  controle.updateRule = null;
  controle.deleteRule = null;
  app.save(controle);

  console.log("Gestion locative : tables prêtes, clé appliquée.");
});
