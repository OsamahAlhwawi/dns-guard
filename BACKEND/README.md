# DNS Guard — Backend

Dockerized backend for the DNS Guard service. Two containers (Bun API + AdGuard Home) sized for a 2 GB / 1 vCPU VPS. TLS, rate limiting, and HSTS are handled by **host Nginx**, not by this stack.

## Topology

```
  Internet ── 443 ──> host Nginx (TLS, rate limit, HSTS)
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
  127.0.0.1:8080 (backend)   no public vhost
        /v1/*                AdGuard control panel
        /dns-query/:token    (SSH-tunnel-only)
            │
            ▼
  dns-guard-net (internal) ──> adguardhome:3000
```

- `backend` → exposes `127.0.0.1:8080` to the host.
- `adguardhome` → exposes `127.0.0.1:3000` to the host. **No host Nginx vhost.** Reach via `ssh -L 3000:localhost:3000 user@vps`.
- DoH path on the public side is `https://dns.<domain>/dns-query/<token>`; the backend resolves the token → `client_id`, then forwards to `http://adguardhome:3000/dns-query/<client_id>`.

## First-run on the VPS

```bash
git clone …
cd BACKEND
make setup        # generates JWT keypair under ./secrets/, copies .env.example → .env
$EDITOR .env      # set DOMAIN, ADGUARD_API_USER/PASSWORD, …
docker compose up -d

# Open the AdGuard wizard via SSH tunnel and complete the first-run setup
# (host: 0.0.0.0, port 3000, set admin user matching ADGUARD_API_PASSWORD in .env)
ssh -L 3000:localhost:3000 you@vps
# then browse http://localhost:3000

# Once AdGuard is configured, create the first admin
make admin
```

After this, configure the host Nginx vhosts using `docs/nginx-example.conf` as a reference.

## Day-to-day

```bash
make up         # start
make down       # stop
make logs       # tail backend
make backup     # snapshot SQLite + AdGuard data → ./backups/
make admin      # promote / create admin users
```

## Endpoint reference

JSON API at `https://api.<domain>/v1/*`, DoH at `https://dns.<domain>/dns-query/:token`. Full list in `backend/src/routes/`.

## Why this layout

- **Bun + Hono + SQLite** for tiny memory footprint and zero ops overhead.
- **AdGuard Home** does the heavy DNS lifting (filtering, per-client stats, query log). The backend never duplicates that data — admin views proxy AdGuard's APIs.
- **Token → ClientID** mapping happens in an in-memory LRU cache (60 s TTL) so each DoH request is essentially a streaming proxy plus a hash-table lookup.
- **AdGuard admin is private** because the wizard, when exposed publicly, is a foot-gun. SSH port-forwarding is the gate.

## Resource budget (2 GB / 1 vCPU)

| Component   | Idle RSS | At 100 qps |
|-------------|----------|------------|
| AdGuard     | ~150 MB  | ~250 MB    |
| Bun backend | ~80 MB   | ~150 MB    |
| Host Nginx  | ~30 MB   | ~60 MB     |
| OS + buffer | ~400 MB  | ~400 MB    |

Total well under 1 GB, leaving headroom for SQLite cache and bursts.

## Security notes

- AdGuard control UI is bound to `127.0.0.1:3000`; never expose it publicly.
- JWT keys live under `./secrets/` (gitignored). Rotate them with `scripts/setup.sh --rotate-keys` (will invalidate all existing sessions).
- `is_active = 0` by default for self-registered users; admin must activate. The DoH proxy enforces the gate independently of the JWT.
- Per-IP rate limiting is the host Nginx's job. The backend adds a per-token leaky bucket so a leaked token can't fan out across IPs.
