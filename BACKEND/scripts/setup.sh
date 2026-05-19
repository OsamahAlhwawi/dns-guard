#!/usr/bin/env bash
set -euo pipefail

# First-run helper:
#   - copies .env.example → .env if missing
#   - generates RS256 JWT keypair under ./secrets/ if missing
#   - prints next steps

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ROTATE=0
if [[ "${1:-}" == "--rotate-keys" ]]; then
  ROTATE=1
fi

if [[ ! -f .env ]]; then
  echo "→ creating .env from .env.example"
  cp .env.example .env
  echo "  edit .env to set DOMAIN, ADGUARD_API_PASSWORD, …"
fi

mkdir -p secrets
chmod 700 secrets

if [[ $ROTATE -eq 1 ]] || [[ ! -f secrets/jwt_private.pem ]]; then
  echo "→ generating RS256 JWT keypair under secrets/"
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out secrets/jwt_private.pem
  openssl rsa -in secrets/jwt_private.pem -pubout -out secrets/jwt_public.pem
  chmod 600 secrets/jwt_private.pem
  chmod 644 secrets/jwt_public.pem
fi

mkdir -p backups

cat <<MSG

DNS Guard backend is ready to start.

Next steps:
  1. Edit .env (DOMAIN, ADGUARD_API_USER, ADGUARD_API_PASSWORD, …)
  2. Set the AdGuard admin bcrypt hash in adguard/AdGuardHome.yaml — see adguard/README.md
  3. docker compose up -d
  4. Open the AdGuard UI via SSH tunnel and complete first-run:
        ssh -L 3000:localhost:3000 \$USER@\$HOST   →   http://localhost:3000
  5. make admin       # create the first DNS Guard admin user
  6. Wire host Nginx vhosts using docs/nginx-example.conf as a template.

MSG
