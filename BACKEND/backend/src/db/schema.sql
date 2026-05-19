PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    full_name TEXT,
    token TEXT UNIQUE NOT NULL,
    client_id TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    is_active INTEGER NOT NULL DEFAULT 0,
    is_suspended INTEGER NOT NULL DEFAULT 0,
    plan TEXT NOT NULL DEFAULT 'standard',
    daily_limit INTEGER NOT NULL DEFAULT 100000,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    last_used DATETIME,
    expires_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_users_token ON users(token);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    jwt_id TEXT UNIQUE NOT NULL,
    device_info TEXT,
    ip_address TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_jwt_id ON sessions(jwt_id);

CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    date DATE NOT NULL,
    queries_count INTEGER NOT NULL DEFAULT 0,
    blocked_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, date),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_usage_user_date ON usage_logs(user_id, date);

CREATE TABLE IF NOT EXISTS login_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    ip_address TEXT,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    success INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_username_time
    ON login_attempts(username, attempted_at);

CREATE TABLE IF NOT EXISTS token_blacklist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    jwt_id TEXT UNIQUE NOT NULL,
    blacklisted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_blacklist_jwt_id ON token_blacklist(jwt_id);
CREATE INDEX IF NOT EXISTS idx_blacklist_expires ON token_blacklist(expires_at);
