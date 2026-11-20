#!/bin/sh
# Démarrage du module : deux PocketBase séparés (prod et test, données dans
# /data, sauvegardées par Home Assistant), puis Tailscale Funnel pour les
# adresses HTTPS publiques :
#   prod : https://<adresse>        -> PocketBase prod sur 127.0.0.1:8090
#   test : https://<adresse>:8443   -> PocketBase test sur 127.0.0.1:8091
set -eu

OPTIONS=/data/options.json
CLE_PROD=$(jq -r '.cle_prod // ""' "$OPTIONS")
CLE_TEST=$(jq -r '.cle_test // ""' "$OPTIONS")
NOM=$(jq -r '.nom_tailscale // "gestion-locative"' "$OPTIONS")
CLE_TS=$(jq -r '.cle_tailscale // ""' "$OPTIONS")

for CLE in "$CLE_PROD" "$CLE_TEST"; do
  if ! echo "$CLE" | grep -Eq '^[A-Za-z0-9-]{20,}$'; then
    echo "[locatif] ERREUR : réglez les deux clés (onglet Configuration) :"
    echo "[locatif] 20 caractères minimum, lettres, chiffres et tirets."
    exit 1
  fi
done
if [ "$CLE_PROD" = "$CLE_TEST" ]; then
  echo "[locatif] ERREUR : la clé de test doit être différente de la clé de prod."
  exit 1
fi

mkdir -p /data/pb_prod /data/pb_test /data/tailscale /data/tailscale/certificat /var/run/tailscale
SOCKET=/var/run/tailscale/tailscaled.sock
TS="tailscale --socket=$SOCKET"

echo "[locatif] Démarrage de la base PROD (PocketBase, port 8090)…"
CLE_SYNCHRO="$CLE_PROD" /opt/pocketbase/pocketbase serve \
  --http=127.0.0.1:8090 \
  --dir=/data/pb_prod \
  --hooksDir=/opt/pocketbase/pb_hooks \
  --origins=https://celestindeal.github.io &
PB_PROD=$!

echo "[locatif] Démarrage de la base TEST (PocketBase, port 8091)…"
CLE_SYNCHRO="$CLE_TEST" /opt/pocketbase/pocketbase serve \
  --http=127.0.0.1:8091 \
  --dir=/data/pb_test \
  --hooksDir=/opt/pocketbase/pb_hooks \
  --origins=https://celestindeal.github.io,http://localhost:8080 &
PB_TEST=$!

echo "[locatif] Démarrage de Tailscale…"
# Journal de Tailscale : seules les lignes utiles (connexion, certificat
# HTTPS, Funnel, erreurs) sont recopiées dans le journal du module.
tailscaled --tun=userspace-networking --statedir=/data/tailscale --socket="$SOCKET" 2>&1 \
  | grep --line-buffered -iE "cert|acme|funnel|serve|tls|error|fail|denied|derp.*(home|connected)|LinkChange" \
  | sed -u 's/^/[tailscale] /' &
for _ in $(seq 1 30); do
  [ -S "$SOCKET" ] && break
  sleep 1
done

echo "[locatif] Connexion à Tailscale. Si un lien https://login.tailscale.com/… s'affiche"
echo "[locatif] ci-dessous, ouvrez-le pour relier ce serveur à votre compte Tailscale."
if [ -n "$CLE_TS" ]; then
  $TS up --hostname="$NOM" --authkey="$CLE_TS"
else
  $TS up --hostname="$NOM"
fi

# Au démarrage de la Raspberry Pi, le réseau (Wi-Fi) et l'heure peuvent ne pas
# être prêts : on attend que Tailscale soit vraiment connecté.
etat() { $TS status --json 2>/dev/null | jq -r '.BackendState // "?"'; }
for i in $(seq 1 60); do
  [ "$(etat)" = "Running" ] && break
  [ "$i" = 1 ] && echo "[locatif] En attente de la connexion à Tailscale…"
  sleep 5
done
echo "[locatif] Tailscale : $(etat), heure : $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

ADRESSE=$($TS status --json | jq -r '.Self.DNSName' | sed 's/\.$//')

# Certificat HTTPS de l'adresse publique (le même pour les ports 443 et 8443) :
# demandé explicitement, et redemandé tant qu'il n'est pas obtenu.
for i in $(seq 1 40); do
  if sortie=$($TS cert --cert-file /data/tailscale/certificat/cert.pem --key-file /data/tailscale/certificat/cle.pem "$ADRESSE" 2>&1); then
    echo "[locatif] Certificat HTTPS prêt pour $ADRESSE."
    break
  fi
  echo "[locatif] Certificat HTTPS pas encore obtenu (essai $i) : $sortie"
  sleep 30
done

echo "[locatif] Ouverture des adresses publiques (Tailscale Funnel). Si un lien s'affiche,"
echo "[locatif] ouvrez-le pour autoriser Funnel, le module continue tout seul ensuite."
# Funnel est toujours effacé puis recréé : la configuration gardée du
# démarrage précédent n'est pas toujours annoncée de nouveau aux relais de
# Tailscale, qui ne joignent alors plus le serveur.
ouvrir_funnel() {
  $TS serve reset >/dev/null 2>&1 || true
  $TS funnel --bg --https=443 8090
  $TS funnel --bg --https=8443 8091
  $TS funnel status 2>&1 | sed 's/^/[tailscale] /'
}
ouvrir_funnel

echo "[locatif] ------------------------------------------------------------"
echo "[locatif] Serveur prêt."
echo "[locatif]   PROD : https://$ADRESSE"
echo "[locatif]   TEST : https://$ADRESSE:8443"
echo "[locatif] ------------------------------------------------------------"

# Surveillance : toutes les 3 minutes, les deux adresses publiques sont
# testées depuis Internet (comme le ferait un téléphone). Après 2 échecs de
# suite, Funnel est recréé ; après 4, le module s'arrête et le chien de garde
# de Home Assistant le relance. Il s'arrête aussi si une base s'arrête.
joignable() {
  curl -fsS --max-time 20 -o /dev/null "https://$ADRESSE/api/health" 2>/dev/null \
    && curl -fsS --max-time 20 -o /dev/null "https://$ADRESSE:8443/api/health" 2>/dev/null
}
echecs=0
sleep 120
while kill -0 "$PB_PROD" 2>/dev/null && kill -0 "$PB_TEST" 2>/dev/null; do
  if joignable; then
    if [ "$echecs" -gt 0 ]; then
      echo "[locatif] $(date -u '+%H:%M') UTC : adresses publiques de nouveau joignables."
    fi
    echecs=0
  else
    echecs=$((echecs + 1))
    echo "[locatif] $(date -u '+%H:%M') UTC : adresse publique injoignable (contrôle $echecs/4)."
    echo "[tailscale] $($TS status --json 2>/dev/null | jq -c '{etat: .BackendState, enLigne: .Self.Online, relais: .Self.Relay}')"
    if [ "$echecs" = 2 ]; then
      echo "[locatif] Funnel est recréé…"
      ouvrir_funnel
    elif [ "$echecs" -ge 4 ]; then
      echo "[locatif] Redémarrage du module pour rétablir les adresses publiques…"
      exit 1
    fi
  fi
  sleep 180
done
echo "[locatif] Une base PocketBase s'est arrêtée : redémarrage du module."
exit 1
