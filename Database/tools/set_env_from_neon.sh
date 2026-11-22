#!/usr/bin/env bash
# Writes the Neon connection settings into DiaMate/.env (backup: .env.local-backup). JWT_SECRET etc. are kept.
# Asks for the Neon connection string with hidden input; nothing is printed or stored elsewhere.
set -euo pipefail
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
ENVF="$(cd "$(dirname "$0")/../../DiaMate" && pwd)/.env"
[ -f "$ENVF" ] || { echo "HATA: $ENVF yok"; exit 1; }

read -r -s -p "Neon connection string: " RAW; echo
URL="$(printf '%s' "$RAW" | grep -Eo "postgres(ql)?://[^'\" [:space:]]+" | head -n1 || true)"
[ -n "$URL" ] || { echo "HATA: postgresql:// dizesi bulunamadi."; exit 1; }

python3 - "$ENVF" "$URL" <<'PY'
import sys, re, shutil
from urllib.parse import urlparse, unquote
envf, url = sys.argv[1], sys.argv[2]
u = urlparse(url)
vals = {
  "POSTGRES_HOST": u.hostname, "POSTGRES_PORT": str(u.port or 5432),
  "POSTGRES_DB": (u.path or "/neondb").lstrip("/") or "neondb",
  "POSTGRES_USER": unquote(u.username or ""), "POSTGRES_PASSWORD": unquote(u.password or ""),
  "POSTGRES_SSLMODE": "require",
}
if not all(vals[k] for k in ("POSTGRES_HOST","POSTGRES_USER","POSTGRES_PASSWORD")):
    sys.exit("HATA: dizede host/kullanici/sifre eksik")
if "-pooler" in vals["POSTGRES_HOST"]:
    sys.exit("HATA: pooled baglanti (-pooler). Connect'te 'Pooled connection' kutusunu kapatip direct dizeyi kopyala.")
shutil.copyfile(envf, envf + ".local-backup")
lines = open(envf).read().splitlines()
seen = set()
for i, l in enumerate(lines):
    m = re.match(r"^([A-Z_]+)=", l)
    if m and m.group(1) in vals:
        lines[i] = f"{m.group(1)}={vals[m.group(1)]}"; seen.add(m.group(1))
for k, v in vals.items():
    if k not in seen:
        lines.append(f"{k}={v}")
open(envf, "w").write("\n".join(lines) + "\n")
print("OK: .env guncellendi (yedek: .env.local-backup)")
print("host =", vals["POSTGRES_HOST"], "| db =", vals["POSTGRES_DB"], "| user =", vals["POSTGRES_USER"])
PY
chmod 600 "$ENVF"

echo "== Baglanti testi =="
set -a; . "$ENVF"; set +a
PGPASSWORD="$POSTGRES_PASSWORD" PGSSLMODE=require psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select 'baglandi, users=' || count(*) from public.users;"
