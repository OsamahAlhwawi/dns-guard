#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "usage: $0 backups/<file>.tar.gz" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

tar -xzf "$ARCHIVE" -C "$TMP"

echo "→ stopping containers"
docker compose stop backend adguardhome

echo "→ restoring SQLite"
docker compose cp "$TMP/dns-guard.sqlite" backend:/data/dns-guard.sqlite

echo "→ restoring AdGuard data"
docker run --rm \
  -v dns-guard_adguard_work:/to \
  -v "$TMP":/from \
  alpine sh -c 'rm -rf /to/* && tar -C /to -xzf /from/adguard_work.tar.gz'

echo "→ starting containers"
docker compose up -d

echo "✓ restored from $ARCHIVE"
