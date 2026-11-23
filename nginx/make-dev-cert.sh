#!/usr/bin/env bash
# Self-signed certificate for running the stack locally (docker-compose.yml). Not for production: there, use a
# certificate from a real CA (e.g. Let's Encrypt) with the same file names.
# Writes nginx/ssl/server.crt and nginx/ssl/server.key (both ignored by Git).
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)/ssl"
mkdir -p "$dir"

if [[ -f "$dir/server.key" && "${1:-}" != "--force" ]]; then
    echo "$dir/server.key already exists (use --force to replace it)"
    exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.0.2.2" \
    -keyout "$dir/server.key" -out "$dir/server.crt"
chmod 600 "$dir/server.key"
echo "Wrote $dir/server.crt and $dir/server.key"
