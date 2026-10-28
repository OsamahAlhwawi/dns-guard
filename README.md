<div align="center">

# AD BYPASSER

**A private, encrypted, ad-blocking DNS service for family and friends, with a native iOS app.**

*Internal codename: DNS Guard*

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![Backend](https://img.shields.io/badge/backend-Bun%20%2B%20Hono-black)
![DNS](https://img.shields.io/badge/DNS-AdGuard%20Home-68bc71)
![Protocol](https://img.shields.io/badge/protocol-DoH%20(RFC%208484)-blue)

</div>

---

## Overview

AD BYPASSER blocks ads, trackers, phishing, and malware **system-wide**, in every app on the device, using encrypted DNS-over-HTTPS (DoH). It needs no VPN.

Each user has an account and a personal DoH endpoint. With one tap, the iOS app installs a system DNS profile that sends every DNS query through a self-hosted [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) instance. A lightweight Bun API sits in front of AdGuard Home and handles authentication, per-user access control, and statistics.

### Highlights

- 🛡️ **System-wide blocking.** Ads, trackers, phishing, and malware are filtered at the DNS layer.
- 🔒 **Encrypted DNS.** All queries go over HTTPS (DoH, RFC 8484), with TLS terminated by Nginx.
- 👤 **Per-user endpoints.** Each account gets its own token-scoped DoH URL that maps to its own AdGuard client.
- ✅ **Admin-gated sign-ups.** Self-registered accounts stay pending until an admin activates them.
- 📊 **Personal statistics.** Queries, blocked requests, block ratio, top domains, and history charts.
- 🧑‍💼 **In-app admin panel.** Approve, suspend, edit, and delete users, and view aggregate stats.
- 🌍 **Arabic & English.** Full RTL support, Arabic numerals, Dark Mode, and VoiceOver.
- 🪶 **Small footprint.** The whole stack runs comfortably on a 2 GB / 1 vCPU VPS.

---

## Architecture

```
┌──────────────────────────────────────────────┐
│  iOS / iPadOS app  (SwiftUI + MVVM)          │
│  NEDNSSettingsManager → DoH system profile   │
└───────────────┬──────────────────────────────┘
                │  HTTPS  (/v1/* JSON API  +  /dns-query/<token>)
                ▼
┌──────────────────────────────────────────────┐
│  Host Nginx — TLS, HSTS, per-IP rate limit   │
└───────────────┬──────────────────────────────┘
                │  127.0.0.1:8080
                ▼
┌──────────────────────────────────────────────┐
│  Bun + Hono API  (SQLite)                    │
│  • Auth (Argon2id, RS256 JWT)                │
│  • token → client_id lookup (LRU, 60 s TTL)  │
│  • per-token leaky-bucket rate limit         │
└───────────────┬──────────────────────────────┘
                │  internal docker network
                ▼
┌──────────────────────────────────────────────┐
│  AdGuard Home — filtering, per-client stats  │
│  (admin UI on 127.0.0.1:3000, SSH-only)      │
└───────────────┬──────────────────────────────┘
                │  DoH
                ▼
        Upstreams: Cloudflare · Quad9 · Google
```

**How a DNS query flows:**

1. iOS sends the query to `https://<domain>/dns-query/<token>`.
2. Nginx terminates TLS and forwards the request to the Bun backend.
3. The backend resolves `token → client_id`, checks that the account is active and within its rate limit, and streams the request to `http://adguardhome:3000/dns-query/<client_id>`.
4. AdGuard Home filters the query, attributes it to that user's client, and answers from upstream.
5. If the token is unknown or the account is inactive, the backend returns a DNS `SERVFAIL` response.

---

## Repository Structure

```
AD-BYPASSER/
├── AD-BYPASSER-APP/              # Native iOS / iPadOS app (Xcode project)
│   └── AD BYPASSER/
│       ├── App/                  # App entry, root routing, tab bar
│       ├── Models/               # User, Stats, DNSStatus, QueryLogEntry, …
│       ├── ViewModels/           # Auth, Dashboard, Stats, Settings, Admin
│       ├── Views/                # Auth, Onboarding, Dashboard, Stats, Settings, Admin
│       ├── Services/             # APIClient, DNSManager, Keychain, Biometrics, Pinning
│       ├── Utilities/            # Constants, Validators, Extensions
│       └── Resources/            # Localizable.strings (ar)
│
├── BACKEND/                      # Dockerized server stack
│   ├── backend/                  # Bun + Hono + SQLite API
│   │   ├── src/
│   │   │   ├── routes/           # auth, user, stats, dns, admin, dns-proxy
│   │   │   ├── services/         # users, tokens, AdGuard client, stats, token cache
│   │   │   ├── middleware/       # auth, rate limit, logging
│   │   │   ├── db/               # schema.sql, connection
│   │   │   └── utils/            # crypto, validators
│   │   └── test/                 # bun:test suites
│   ├── adguard/conf/             # AdGuardHome.yaml seed config
│   ├── docs/nginx-example.conf   # Host Nginx reference vhost
│   ├── scripts/                  # setup, create-admin, backup, restore
│   ├── docker-compose.yml
│   └── Makefile
│
└── SRS.MD                        # Software Requirements Specification
```

---

## Tech Stack

| Layer      | Technology |
|------------|------------|
| iOS app    | Swift, SwiftUI, Observation, Swift Charts, NetworkExtension (`NEDNSSettingsManager`), Keychain, LocalAuthentication |
| API        | [Bun](https://bun.sh), [Hono](https://hono.dev), [Zod](https://zod.dev), [jose](https://github.com/panva/jose) (RS256 JWT), `@node-rs/argon2` |
| Database   | SQLite (WAL mode) |
| DNS engine | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) |
| Edge       | Nginx + Let's Encrypt |
| Ops        | Docker Compose, Make, Bash scripts |

---

## Getting Started

### Prerequisites

- **Server:** a Linux VPS (2 GB RAM / 1 vCPU is enough) with Docker and Docker Compose, Nginx, a domain name, and a valid TLS certificate (Let's Encrypt works).
- **App:** macOS with **Xcode 26.4+** and an Apple Developer account. The Network Extension `dns-settings` entitlement needs a paid team.

### 1. Deploy the backend

```bash
git clone <repo-url>
cd AD-BYPASSER/BACKEND

make setup            # generates the RS256 JWT keypair in ./secrets/ and creates .env
$EDITOR .env          # set DOMAIN, API_BASE_URL, DNS_BASE_URL, ADGUARD_API_USER/PASSWORD
```

Set the AdGuard Home admin password hash in `adguard/conf/AdGuardHome.yaml`. See [BACKEND/adguard/README.md](BACKEND/adguard/README.md) for the exact steps. Then start the stack:

```bash
docker compose up -d

# Reach the AdGuard UI privately through an SSH tunnel
ssh -L 3000:localhost:3000 you@your-vps     # then open http://localhost:3000

make admin            # create the first AD BYPASSER admin account
```

Finally, configure the host Nginx vhost. Use [BACKEND/docs/nginx-example.conf](BACKEND/docs/nginx-example.conf) as a template.

### 2. Build the iOS app

1. Open `AD-BYPASSER-APP/AD BYPASSER.xcodeproj` in Xcode.
2. Point the app at your server in [Constants.swift](AD-BYPASSER-APP/AD%20BYPASSER/Utilities/Constants.swift):
   ```swift
   static let apiBaseURL = URL(string: "https://your-domain.com")!
   static let dnsBaseURL = URL(string: "https://your-domain.com")!
   ```
3. *(Recommended for production)* Fill in `pinnedSPKIHashes` to turn on certificate pinning. The command that generates the hashes is in a comment in the same file.
4. Choose your development team under **Signing & Capabilities** and update the bundle identifier if you need to.
5. Build and run on a physical device. DNS profiles can't be installed on the simulator.

### 3. First use

1. Register in the app. The account stays **pending activation** at first.
2. An admin approves it from the in-app **Admin** tab.
3. The user taps the protection toggle, and iOS asks once for permission to install the DNS profile.
4. The user then opens **Settings → General → VPN, DNS & Device Management → DNS** and selects **DNS Guard**. The app's status turns to *Protected* within about 30 seconds.

---

## Configuration

All backend settings are environment variables in `BACKEND/.env`. Start from [`.env.example`](BACKEND/.env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | — | Public domain (used for CORS and in DoH URLs) |
| `API_BASE_URL` | — | Public base URL of the JSON API |
| `DNS_BASE_URL` | — | Public base URL of the DoH endpoint |
| `JWT_ACCESS_TTL_SECONDS` | `1800` | Access-token lifetime (30 min) |
| `JWT_REFRESH_TTL_SECONDS` | `2592000` | Refresh-token lifetime (30 days) |
| `ADGUARD_API_USER` / `ADGUARD_API_PASSWORD` | — | Credentials for the AdGuard Home control API |
| `ARGON2_MEMORY_KIB` / `ARGON2_ITERATIONS` / `ARGON2_PARALLELISM` | `19456` / `2` / `1` | Argon2id cost parameters (OWASP minimum) |
| `LOGIN_MAX_ATTEMPTS` / `LOGIN_LOCKOUT_MINUTES` | `5` / `15` | Brute-force lockout |
| `DEFAULT_DAILY_LIMIT` | `0` | Default daily query cap per user (`0` = unlimited) |
| `TOKEN_RATE_LIMIT_PER_MIN` | `2000` | Per-token leaky-bucket rate limit |
| `LOG_LEVEL` | `info` | `debug` · `info` · `warn` · `error` |

You can change upstream resolvers, filter lists, and log retention in `adguard/conf/AdGuardHome.yaml` without touching any code. The default filter lists are the AdGuard DNS filter, AdAway, and PhishTank/OpenPhish.

---

## API Reference

Base URL: `https://<domain>`. Routes marked 🔐 need a `Bearer` JWT, and 👑 routes also need the `admin` role.

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/v1/auth/register` | Create an account (starts as pending) |
| `POST` | `/v1/auth/login` | Sign in and receive access and refresh tokens |
| `POST` | `/v1/auth/refresh` | Get a new access token using the refresh token |
| `POST` | `/v1/auth/logout` 🔐 | Revoke the current session |

### User, DNS & Stats 🔐

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/v1/user/profile` | Current user's profile |
| `POST` | `/v1/user/password` | Change password |
| `GET`  | `/v1/dns/status` | Account status: `active`, `pending_activation`, `suspended`, or `expired` |
| `GET`  | `/v1/dns/config` | The user's personal DoH URL |
| `GET`  | `/v1/stats/today` | Today's query and blocked counts |
| `GET`  | `/v1/stats/history` | Usage history for charts |
| `GET`  | `/v1/stats/top-domains` | Top queried and top blocked domains |

### Admin 👑

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`    | `/v1/admin/users` | List all users |
| `GET`    | `/v1/admin/pending` | List accounts waiting for activation |
| `POST`   | `/v1/admin/users` | Create a user |
| `PATCH`  | `/v1/admin/users/:id` | Update a user (activate, suspend, limits, role, …) |
| `DELETE` | `/v1/admin/users/:id` | Delete a user and their AdGuard client |
| `GET`    | `/v1/admin/users/:id/logs` | A user's recent DNS query log |
| `GET`    | `/v1/admin/users/:id/stats` | A user's statistics |
| `GET`    | `/v1/admin/stats/overview` | Aggregate statistics for all users |

### DNS & Health

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` / `POST` | `/dns-query/:token` | RFC 8484 DoH endpoint |
| `GET` | `/healthz` | Liveness probe |

---

## Security

- **Passwords** are hashed with **Argon2id** and never stored in plaintext.
- **Sessions** use **RS256 JWTs**: short-lived access tokens and revocable refresh tokens, with a server-side blacklist.
- **Brute-force protection:** an account is locked for 15 minutes after 5 failed sign-ins.
- **Activation gate:** new accounts can't resolve DNS until an admin activates them. The DoH proxy checks this on its own, separately from the JWT.
- **Rate limiting** happens at two levels: per IP at Nginx and per token in the backend. Because of the per-token limit, a leaked token can't be abused from many IPs at once.
- **Private admin surface:** the AdGuard Home UI listens only on `127.0.0.1` and is reached through an SSH tunnel.
- **On the device,** tokens are kept in the **Keychain**, Face ID / Touch ID can lock the app, and certificate pinning can be turned on through `pinnedSPKIHashes`.
- **Secrets** (`.env`, `secrets/`, `backups/`) are gitignored. To rotate the JWT keys, run `scripts/setup.sh --rotate-keys`. This signs out every session.

---

## Operations

Run these from `BACKEND/`:

```bash
make up                                # start the stack
make down                              # stop the stack
make restart                           # restart the backend container
make logs                              # tail backend logs
make ps                                # show container status
make admin                             # create or promote an admin user
make backup                            # snapshot SQLite + AdGuard data to ./backups/
make restore F=backups/<file>.tar.gz   # restore from a snapshot
make test                              # run the backend test suite
make build                             # rebuild the backend image
```

### Resource budget (2 GB / 1 vCPU)

| Component   | Idle RSS | At 100 qps |
|-------------|----------|------------|
| AdGuard     | ~150 MB  | ~250 MB    |
| Bun backend | ~80 MB   | ~150 MB    |
| Host Nginx  | ~30 MB   | ~60 MB     |

---

## Testing

**Backend.** Uses `bun:test` and covers crypto, validators, rate limiting, and the DoH proxy:

```bash
cd BACKEND/backend
bun install
bun test
```

**iOS app.** Run the unit and UI tests from Xcode with `⌘U`, or from the command line:

```bash
xcodebuild test \
  -project "AD-BYPASSER-APP/AD BYPASSER.xcodeproj" \
  -scheme "AD BYPASSER" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Documentation

- [SRS.MD](SRS.MD): the full Software Requirements Specification
- [BACKEND/README.md](BACKEND/README.md): backend topology and operations
- [BACKEND/adguard/README.md](BACKEND/adguard/README.md): AdGuard Home setup and tuning
- [BACKEND/docs/nginx-example.conf](BACKEND/docs/nginx-example.conf): reference Nginx vhost

---

## Roadmap

- [ ] Android client
- [ ] Web dashboard for users
- [ ] Push notifications for alerts
- [ ] Family stats sharing
- [ ] English `Localizable.strings` alongside Arabic

---

<div align="center">

Built by [Osamah Alhwawi](https://github.com/OsamahAlhwawi)

</div>
