#!/usr/bin/env bash
# Development certificates for running the stack locally (docker-compose.yml). Not for production: there, use a
# certificate from a real CA (e.g. Let's Encrypt) as nginx/ssl/server.crt and server.key.
#
# Writes into nginx/ssl/ (ignored by Git):
#   ca.crt, ca.key          a small local certificate authority ("DiaMate Dev CA"), valid 2 years
#   server.crt, server.key  the certificate Nginx serves, signed by that CA, valid 1 year
#
# A phone or simulator trusts the CA once (ca.crt), not the server certificate. The server certificate has what iOS and
# Android require of a TLS server certificate: subjectAltName (localhost, 127.0.0.1 and 10.0.2.2, the host as seen from
# the Android emulator), extendedKeyUsage serverAuth, no CA flag, and a lifetime under 398 days.
#
#   iOS simulator:     xcrun simctl keychain booted add-root-cert nginx/ssl/ca.crt
#   Android emulator:  Settings -> Security -> Encryption & credentials -> Install a certificate -> CA certificate
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)/ssl"
mkdir -p "$dir"

if [[ -f "$dir/server.key" && -f "$dir/ca.crt" && "${1:-}" != "--force" ]]; then
    echo "$dir already has a certificate (use --force to replace it)"
    exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes -days 730 -sha256 \
    -subj "/CN=DiaMate Dev CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -keyout "$dir/ca.key" -out "$dir/ca.crt" 2>/dev/null

openssl req -newkey rsa:2048 -nodes -sha256 -subj "/CN=localhost" \
    -keyout "$dir/server.key" -out "$dir/server.csr" 2>/dev/null

extfile="$(mktemp)"
trap 'rm -f "$extfile" "$dir/server.csr" "$dir/ca.srl"' EXIT
cat > "$extfile" <<'EXT'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.0.2.2
EXT
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.crt" -CAkey "$dir/ca.key" -CAcreateserial \
    -days 365 -sha256 -extfile "$extfile" -out "$dir/server.crt" 2>/dev/null

chmod 600 "$dir/ca.key" "$dir/server.key"
echo "Wrote $dir/ca.crt (trust this one on the device) and $dir/server.crt / server.key (served by Nginx)"
