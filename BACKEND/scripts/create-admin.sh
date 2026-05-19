#!/usr/bin/env bash
set -euo pipefail

# Bootstrap (or promote) an admin user.
# Usage:
#   ./scripts/create-admin.sh
#   ./scripts/create-admin.sh --username alice --password 's3cret!'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

USERNAME=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username) USERNAME="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    *) echo "unknown flag: $1"; exit 2 ;;
  esac
done

if [[ -z "$USERNAME" ]]; then
  read -rp "admin username: " USERNAME
fi
if [[ -z "$PASSWORD" ]]; then
  read -rsp "admin password: " PASSWORD; echo
fi

if ! docker compose ps backend 2>/dev/null | grep -q backend; then
  echo "backend container is not running; run 'docker compose up -d' first" >&2
  exit 1
fi

docker compose exec -T backend bun -e '
import * as users from "/app/src/services/userService.ts";
const [u, p] = process.argv.slice(-2);
const existing = users.findByUsername(u);
if (existing) {
  const updated = users.updateUser(existing.id, { role: "admin", is_active: true, is_suspended: false });
  console.log(JSON.stringify({ promoted: true, user: { id: updated.id, username: updated.username, role: updated.role, is_active: updated.is_active } }, null, 2));
} else {
  const created = await users.createUser({ username: u, password: p, role: "admin", is_active: true });
  console.log(JSON.stringify({ created: true, user: { id: created.id, username: created.username, role: created.role, is_active: created.is_active } }, null, 2));
}
' "$USERNAME" "$PASSWORD"
