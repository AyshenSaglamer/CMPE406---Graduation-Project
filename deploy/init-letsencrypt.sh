#!/bin/sh
# Gets the first Let's Encrypt certificate for $DOMAIN on a new server (deploy/DEPLOYMENT.md, step 4).
#
# Nginx needs a certificate to start, and Let's Encrypt needs a running Nginx on port 80 to check the domain. So:
#   1. a temporary self-signed certificate is put where the real one will be,
#   2. Nginx starts with it,
#   3. certbot gets the real certificate through Nginx (HTTP-01 challenge on port 80),
#   4. Nginx reloads with the real certificate.
# Later renewals are done by the certbot service of docker-compose.prod.yml.
#
# Run from the repository root, with DOMAIN and LETSENCRYPT_EMAIL in .env and the domain's DNS A record already
# pointing at this server. STAGING=1 uses Let's Encrypt's test CA (no rate limits; the certificate is not trusted).
set -eu

cd "$(dirname "$0")/.."
[ -f .env ] || { echo "No .env in $(pwd); copy .env.example and fill it in first." >&2; exit 1; }
DOMAIN=$(grep -E '^DOMAIN=' .env | cut -d= -f2-)
EMAIL=$(grep -E '^LETSENCRYPT_EMAIL=' .env | cut -d= -f2-)
[ -n "$DOMAIN" ] || { echo "Set DOMAIN in .env" >&2; exit 1; }
[ -n "$EMAIL" ] || { echo "Set LETSENCRYPT_EMAIL in .env (expiry warnings from Let's Encrypt go there)" >&2; exit 1; }

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
LIVE="/etc/letsencrypt/live/$DOMAIN"
STAGING_ARG=""
[ "${STAGING:-0}" = "1" ] && STAGING_ARG="--staging"

if $COMPOSE run --rm --entrypoint sh certbot -c "test -f $LIVE/fullchain.pem && ! test -f $LIVE/.dummy"; then
  echo "A certificate for $DOMAIN already exists; the certbot service renews it. Nothing to do."
  exit 0
fi

echo "1/4 Temporary certificate for $DOMAIN"
$COMPOSE run --rm --entrypoint sh certbot -c "mkdir -p $LIVE && \
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj /CN=localhost \
    -keyout $LIVE/privkey.pem -out $LIVE/fullchain.pem && touch $LIVE/.dummy"

echo "2/4 Starting Nginx (and the stack behind it)"
$COMPOSE up -d nginx

echo "3/4 Requesting the real certificate"
$COMPOSE run --rm --entrypoint sh certbot -c "rm -rf $LIVE /etc/letsencrypt/archive/$DOMAIN \
  /etc/letsencrypt/renewal/$DOMAIN.conf"
$COMPOSE run --rm --entrypoint certbot certbot certonly --webroot -w /var/www/certbot $STAGING_ARG \
  --email "$EMAIL" --agree-tos --no-eff-email -d "$DOMAIN" --rsa-key-size 4096 --non-interactive

echo "4/4 Reloading Nginx"
$COMPOSE exec nginx nginx -s reload
$COMPOSE up -d
echo "Done: https://$DOMAIN/api/v1/health"
