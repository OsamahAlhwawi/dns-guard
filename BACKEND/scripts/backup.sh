#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="$(date -u +%Y%m%d-%H%M%S)"
DEST_DIR="backups"
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/dns-guard-$STAMP.tar.gz"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ snapshotting SQLite"
docker compose exec -T backend sh -c 'sqlite3 /data/dns-guard.sqlite ".backup /tmp/dns-guard.sqlite" 2>/dev/null || cp /data/dns-guard.sqlite /tmp/dns-guard.sqlite'
docker compose cp backend:/tmp/dns-guard.sqlite "$TMP/dns-guard.sqlite"

echo "→ snapshotting AdGuard data volume"
docker run --rm \
  -v dns-guard_adguard_work:/from \
  -v "$TMP":/to \
  alpine sh -c 'tar -C /from -czf /to/adguard_work.tar.gz .'

tar -czf "$DEST" -C "$TMP" dns-guard.sqlite adguard_work.tar.gz

echo "✓ wrote $DEST ($(du -h "$DEST" | cut -f1))"
