# Software Requirements Specification (SRS)
## DNS Guard - Secure Ad-Blocking DNS Service

**Version:** 1.0
**Date:** May 2026
**Project Type:** Private DNS System with User Authentication

---

## 1. Introduction

### 1.1 Purpose

This document specifies the requirements for **DNS Guard**, an integrated system that provides encrypted, ad-blocking DNS service for family and friends. The system consists of:

- A centralized DNS server hosted on a VPS
- An authentication layer
- A native iOS/macOS application built with Swift

### 1.2 Scope

The system provides:

- **Ad and tracker blocking** across all device applications
- **Encrypted DNS queries** via DoH protocol
- **User authentication** with username/password
- **Personal usage statistics** per user
- **Remote administrative control** of users
- **Protection against malicious sites** (Phishing & Malware)

### 1.3 Definitions and Acronyms

| Term | Definition |
|------|------------|
| DNS | Domain Name System |
| DoH | DNS over HTTPS |
| DoT | DNS over TLS |
| ClientID | Unique identifier for each user in AdGuard Home |
| Upstream | Primary DNS server queried by AdGuard |
| Blocklist | List of blocked domains |
| VPS | Virtual Private Server |
| Network Extension | Apple framework for network management |
| JWT | JSON Web Token |
| HIG | Human Interface Guidelines |

### 1.4 Target Audience

- **Developer/Admin:** System owner, manages VPS and users
- **End Users:** Family and friends (10-100 users)
- **Usage Environment:** iOS (15+) and macOS (12+) devices

---

## 2. Overall Description

### 2.1 Product Perspective

The system is fully self-contained, composed of three layers:

```
┌─────────────────────────────────────────────┐
│         Client Layer                        │
│   Swift Application on iOS/macOS            │
└────────────────┬────────────────────────────┘
                 │ HTTPS (DoH)
                 ↓
┌─────────────────────────────────────────────┐
│         Server Layer                        │
│   ┌──────────────────────────────────┐      │
│   │   Nginx (TLS + Rate Limit)       │      │
│   ├──────────────────────────────────┤      │
│   │   Bun + SQLite (Auth Proxy)      │      │
│   ├──────────────────────────────────┤      │
│   │   AdGuard Home (DNS + Filter)    │      │
│   └──────────────────────────────────┘      │
└────────────────┬────────────────────────────┘
                 │ DoH/DoT
                 ↓
┌─────────────────────────────────────────────┐
│       Upstream DNS (External)               │
│   Cloudflare, Quad9, Google                 │
└─────────────────────────────────────────────┘
```

### 2.2 Product Functions

**Application Level:**
1. Register new account
2. Sign in and sign out
3. Toggle protection on/off with a single tap
4. Display personal statistics
5. Show connection status
6. Manage personal settings

**Server Level:**
1. Authenticate users
2. Generate and manage tokens
3. Securely route DNS queries
4. Block ads and trackers
5. Log usage and statistics
6. Enforce usage limits

### 2.3 User Characteristics

| Type | Technical Skill | Expected Usage |
|------|----------------|----------------|
| Admin | High | Full management |
| Family | Low | Toggle only |
| Friends | Medium | Monitor statistics |

### 2.4 Constraints

- **Supports iOS 15+ and macOS 12+ only**
- **Requires constant internet connection**
- **VPS capacity determines concurrent users**
- **Valid TLS certificate is mandatory**
- **Requires user approval for DNS profile**

### 2.5 Assumptions and Dependencies

- User has an active Apple ID
- User runs a supported iOS version
- VPS availability is 99.9%
- Let's Encrypt certificates auto-renew

---

## 3. Functional Requirements

### 3.1 Authentication Module

#### FR-001: Register New Account

**Description:** User can create an account by entering credentials.

**Inputs:**
- Username (3-20 chars, alphanumeric only)
- Password (min 8 chars, must include number + letter + symbol)
- Full name (optional)
- Email (optional, for recovery)

**Process:**
1. Verify username availability
2. Hash password with Argon2id
3. Generate unique ClientID (16 random chars)
4. Generate API Token (32 random chars)
5. Save to SQLite
6. Create client in AdGuard Home

**Outputs:**
- JWT token for session
- ClientID
- Account information

**Acceptance Criteria:**
- Usernames are unique
- Passwords are hashed (never stored as plaintext)
- Tokens generated securely
- No partial accounts on failure

---

#### FR-002: Sign In

**Description:** User signs into their account.

**Inputs:**
- Username
- Password

**Process:**
1. Look up user in DB
2. Verify password (Argon2id verify)
3. Check account status (active/suspended)
4. Generate JWT token
5. Update `last_login`

**Outputs:**
- JWT token (30-day validity)
- User data

**Acceptance Criteria:**
- Reject login after 5 failed attempts (15-min lockout)
- JWT signed with secure key
- Log login attempts

---

#### FR-003: Sign Out

**Description:** User ends their session.

**Process:**
1. Add token to blacklist
2. Delete token from Keychain
3. Disable DNS on device
4. Return to login screen

---

### 3.2 DNS Management Module

#### FR-004: Enable Protection

**Description:** User activates secure DNS on their device.

**Process:**
1. Retrieve token from Keychain
2. Create `NEDNSSettings` with DoH
3. Set URL: `https://dns.yoursite.com/dns-query/{TOKEN}`
4. Request user approval (first time only)
5. Save preferences
6. Verify activation success

**Outputs:**
- Activation status (success/failure)
- User-facing message

**Acceptance Criteria:**
- Activation within 3 seconds max
- Clear error messages in Arabic
- Works without external VPN

---

#### FR-005: Disable Protection

**Description:** User temporarily disables DNS.

**Process:**
1. Call `removeFromPreferences()`
2. Update UI
3. Preserve account data

---

#### FR-006: Check Protection Status

**Description:** Display current protection state.

**Auto-check triggers:**
- On app launch
- Every 30 seconds in background
- On return from Settings

---

### 3.3 Statistics Module

#### FR-007: Display Personal Statistics

**Displayed Information:**
- Total queries today
- Number of blocked ads
- Block ratio (%)
- Top queried domains
- Top blocked domains
- Daily limit usage

**Update Frequency:**
- Auto-refresh every minute when app is open
- Manual pull-to-refresh

---

#### FR-008: Usage History

**Description:** Display usage charts.

**Time Periods:**
- Last 24 hours
- Last 7 days
- Last 30 days

---

### 3.4 Admin Module

#### FR-009: Admin Dashboard

**Features:**
- View all users
- Add/delete/edit users
- Activate/suspend accounts
- Adjust limits
- View aggregate statistics
- Export reports

---

## 4. Non-Functional Requirements

### 4.1 Performance

| Metric | Target |
|--------|--------|
| DNS response time | < 50ms (average) |
| Token validation time | < 5ms |
| App launch time | < 2 seconds |
| Queries per second | 1,000 (server) |
| Concurrent users | 100+ |

### 4.2 Security

**Network Level:**
- TLS 1.2+ mandatory
- HSTS enabled
- Certificate pinning in app
- Rate limiting (100 req/sec per IP)
- DDoS protection

**Data Level:**
- Passwords hashed with Argon2id
- Tokens stored in Keychain only
- JWT signed with RS256
- Encrypted SQLite (SQLCipher)

**Application Level:**
- App Transport Security
- Jailbreak detection
- Code obfuscation for sensitive parts

### 4.3 Reliability

- **Target uptime:** 99.5% monthly
- **Backups:** Daily automated SQLite backup
- **Recovery time:** < 15 minutes
- **Failover:** Multiple upstream DNS servers

### 4.4 Usability

- **Languages:** Arabic + English
- **Design:** Follows Human Interface Guidelines
- **Accessibility:** VoiceOver support
- **Direction:** Full RTL support
- **Dark Mode:** Supported

### 4.5 Compatibility

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 15.0 |
| iPadOS | 15.0 |
| macOS | 12.0 (Monterey) |
| Architecture | ARM64 + x86_64 |

### 4.6 Maintainability

- MVVM architecture
- 70%+ unit test coverage
- Inline code documentation
- Organized Git workflow

---

## 5. Interface Requirements

### 5.1 User Interfaces

#### Screen 1: Onboarding
- App logo
- 3-slide explanation
- "Get Started" button

#### Screen 2: Sign In / Register
- Input fields
- Primary action button
- Link to create account

#### Screen 3: Dashboard (Home)
- Large circular status indicator (protected/unprotected)
- Toggle button
- 4 quick stat cards
- Bottom navigation bar

#### Screen 4: Statistics
- Interactive chart
- Top sites list
- Time filters

#### Screen 5: Settings
- Account info
- Change password
- Notification settings
- Legal information
- Sign out button

### 5.2 Application Programming Interfaces (API)

**Base URL:** `https://api.yoursite.com/v1`

**Endpoints:**

```
POST   /auth/register      - Create account
POST   /auth/login         - Sign in
POST   /auth/logout        - Sign out
POST   /auth/refresh       - Refresh token

GET    /user/profile       - User data
PATCH  /user/profile       - Update profile
DELETE /user/account       - Delete account

GET    /stats/today        - Today's stats
GET    /stats/history      - Usage history
GET    /stats/top-domains  - Top domains

GET    /dns/status         - DNS status
GET    /dns/config         - DNS configuration

# Admin only
GET    /admin/users        - All users
POST   /admin/users        - Add user
PATCH  /admin/users/:id    - Update user
DELETE /admin/users/:id    - Delete user
```

**DNS Endpoint:**
```
POST/GET  /dns-query/:token  - DoH endpoint
```

### 5.3 Hardware Interfaces

- No special hardware requirements
- Uses network via iOS APIs only

---

## 6. Data Model

### 6.1 Database Schema

```sql
-- Users
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    full_name TEXT,
    token TEXT UNIQUE NOT NULL,
    client_id TEXT UNIQUE NOT NULL,
    role TEXT DEFAULT 'user',  -- user, admin
    is_active INTEGER DEFAULT 1,
    plan TEXT DEFAULT 'standard',
    daily_limit INTEGER DEFAULT 100000,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    last_used DATETIME,
    expires_at DATETIME
);

-- Login sessions
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    jwt_id TEXT UNIQUE NOT NULL,
    device_info TEXT,
    ip_address TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Daily usage logs
CREATE TABLE usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    date DATE NOT NULL,
    queries_count INTEGER DEFAULT 0,
    blocked_count INTEGER DEFAULT 0,
    UNIQUE(user_id, date),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Failed login attempts
CREATE TABLE login_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    ip_address TEXT,
    attempted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    success INTEGER DEFAULT 0
);

-- Blacklisted tokens
CREATE TABLE token_blacklist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token TEXT UNIQUE NOT NULL,
    blacklisted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_token ON users(token);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_usage_user_date ON usage_logs(user_id, date);
```

---

## 7. Project Structure

### 7.1 Swift Application

```
DNSGuard/
├── DNSGuardApp/
│   ├── App/
│   │   ├── DNSGuardApp.swift
│   │   └── AppDelegate.swift
│   │
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Stats.swift
│   │   └── APIError.swift
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── DashboardViewModel.swift
│   │   └── StatsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── RegisterView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── ProtectionToggleView.swift
│   │   ├── Stats/
│   │   │   ├── StatsView.swift
│   │   │   └── ChartView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   │
│   ├── Services/
│   │   ├── APIClient.swift
│   │   ├── DNSManager.swift
│   │   ├── KeychainService.swift
│   │   └── BiometricAuth.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   ├── Constants.swift
│   │   └── Validators.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings (ar)
│       └── Localizable.strings (en)
│
└── DNSGuardTests/
    └── Unit Tests
```

### 7.2 Bun Server

```
dns-guard-server/
├── src/
│   ├── index.ts              # Entry point
│   ├── config.ts             # Configuration
│   │
│   ├── routes/
│   │   ├── auth.ts
│   │   ├── user.ts
│   │   ├── stats.ts
│   │   ├── admin.ts
│   │   └── dns-proxy.ts
│   │
│   ├── middleware/
│   │   ├── auth.ts
│   │   ├── rateLimit.ts
│   │   └── logging.ts
│   │
│   ├── services/
│   │   ├── userService.ts
│   │   ├── tokenService.ts
│   │   ├── adguardService.ts
│   │   └── statsService.ts
│   │
│   ├── db/
│   │   ├── schema.sql
│   │   ├── connection.ts
│   │   └── migrations/
│   │
│   └── utils/
│       ├── crypto.ts
│       └── validators.ts
│
├── nginx/
│   └── dns.conf
│
├── adguard/
│   └── AdGuardHome.yaml
│
├── scripts/
│   ├── setup.sh
│   ├── backup.sh
│   └── deploy.sh
│
└── package.json
```

---

## 8. Testing Plan

### 8.1 Unit Tests

- Authentication logic
- Input validation
- API services
- Keychain management

### 8.2 Integration Tests

- Complete registration flow
- DNS activation flow
- AdGuard Home integration

### 8.3 Performance Tests

- 1,000 DNS queries/second
- 100 concurrent users
- Response time < 50ms

### 8.4 Security Tests

- Brute force attempts
- SQL Injection
- XSS
- Authentication bypass attempts

---

## 9. Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1:** Infrastructure setup | 1 week | VPS + AdGuard Home |
| **Phase 2:** Bun server + DB | 1 week | API + Auth |
| **Phase 3:** Nginx + TLS integration | 3 days | Complete system |
| **Phase 4:** Swift app MVP | 2 weeks | Basic app |
| **Phase 5:** Statistics & optimization | 1 week | Advanced features |
| **Phase 6:** Testing & launch | 1 week | Production |

**Total Estimate:** 6-7 weeks

---

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| App Store rejection | Medium | High | Strictly follow HIG |
| VPS downtime | Low | High | Backup + Monitoring |
| Server exploitation | Medium | High | Rate limit + WAF |
| Apple API changes | Low | Medium | Track WWDC announcements |
| Rapid user growth | Low | Medium | Auto-scaling |

---

## 11. Required Resources

### 11.1 Infrastructure

- **VPS:** 2 vCPU, 2GB RAM, 40GB SSD (~$10/month)
- **Domain:** ~$10/year
- **TLS Certificate:** Free (Let's Encrypt)

### 11.2 Development

- **Apple Developer Account:** $99/year
- **Xcode 15+** on macOS
- **TestFlight** for beta testing

### 11.3 Tools

- Git + GitHub
- Postman for API testing
- Charles Proxy for network inspection

---

## 12. Appendices

### A. Technical References

- [Apple NetworkExtension Docs](https://developer.apple.com/documentation/networkextension)
- [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Bun Documentation](https://bun.sh/docs)
- [DoH RFC 8484](https://datatracker.ietf.org/doc/html/rfc8484)

### B. Future Enhancements

- Android support
- Web dashboard for users
- Push notifications for alerts
- AI-powered usage analytics
- Family stats sharing

---

**End of Document**
