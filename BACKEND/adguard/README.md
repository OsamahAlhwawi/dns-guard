# AdGuard Home — DNS Guard config

The seed config lives at `conf/AdGuardHome.yaml`. The `conf/` directory is bind-mounted into the container at `/opt/adguardhome/conf`. We mount the directory (not the file) so AdGuard's config migrator can rewrite `AdGuardHome.yaml` on upgrades — single-file bind mounts break that rename.

## First-time setup

1. Generate a bcrypt hash for the admin user (replace with your password):

   ```bash
   docker run --rm -it httpd:2.4-alpine htpasswd -nbB admin "your-password"
   # output: admin:$2y$05$...
   ```

2. Paste the hash (everything after `admin:`) into `AdGuardHome.yaml` under `users[0].password`.
3. Put the **plaintext** version of the same password into `BACKEND/.env` as `ADGUARD_API_PASSWORD` so the Bun backend can call the control API.
4. `docker compose up -d adguardhome`.

## Reaching the admin UI

The web UI is bound to `127.0.0.1:3000` on the host and **is not** reverse-proxied by the public Nginx. To reach it:

```bash
ssh -L 3000:localhost:3000 you@vps
# then browse http://localhost:3000
```

If the UI is reachable from the public internet, something is misconfigured — recheck `docker-compose.yml` and host Nginx vhosts.

## Things you can change without touching code

- **Upstreams**: edit `dns.upstream_dns` (default: Cloudflare, Quad9, Google over DoH).
- **Filter lists**: edit `filters:` (default: AdGuard DNS filter, AdAway, PhishTank).
- **Query log retention**: `querylog.interval` (default 168h = 7 days).
- **Stats retention**: `statistics.interval` (default 720h = 30 days).

After editing, `docker compose restart adguardhome`.

## Notes

- `dns.port: 53` is internal to the container — we don't expose 53 publicly. All traffic flows via DoH through the Bun proxy.
- `tls.enabled: false` — TLS termination is on the host Nginx, not AdGuard.
- The Bun backend creates per-user clients via `/control/clients/add` at registration, so the `clients.persistent` list grows automatically.
