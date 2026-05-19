import { db, type UserRow } from "../db/connection.ts";
import { hashPassword, generateClientId, generateDohToken } from "../utils/crypto.ts";
import { config } from "../config.ts";
import * as adguard from "./adguardService.ts";
import { invalidateUser } from "./tokenCache.ts";

export type PublicUser = {
  id: number;
  username: string;
  email: string | null;
  full_name: string | null;
  role: "user" | "admin";
  is_active: boolean;
  is_suspended: boolean;
  plan: string;
  daily_limit: number;
  client_id: string;
  token: string;
  created_at: string;
  last_login: string | null;
  expires_at: string | null;
};

function toPublic(row: UserRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    full_name: row.full_name,
    role: row.role,
    is_active: !!row.is_active,
    is_suspended: !!row.is_suspended,
    plan: row.plan,
    daily_limit: row.daily_limit,
    client_id: row.client_id,
    token: row.token,
    created_at: row.created_at,
    last_login: row.last_login,
    expires_at: row.expires_at,
  };
}

export type CreateUserInput = {
  username: string;
  password: string;
  email?: string;
  full_name?: string;
  role?: "user" | "admin";
  is_active?: boolean;
  daily_limit?: number;
};

export async function createUser(input: CreateUserInput): Promise<PublicUser> {
  const existing = db.prepare("SELECT id FROM users WHERE username = ?").get(input.username);
  if (existing) {
    throw new ConflictError("username already taken");
  }
  const password_hash = await hashPassword(input.password);
  const client_id = generateClientId();
  const token = generateDohToken();
  const role = input.role ?? "user";
  const is_active = input.is_active ? 1 : 0;
  const daily_limit = input.daily_limit ?? config.auth.defaultDailyLimit;

  const stmt = db.prepare(`
    INSERT INTO users (username, password_hash, email, full_name, token, client_id, role, is_active, daily_limit)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const info = stmt.run(
    input.username,
    password_hash,
    input.email ?? null,
    input.full_name ?? null,
    token,
    client_id,
    role,
    is_active,
    daily_limit,
  );

  try {
    await adguard.addClient(client_id, input.username);
  } catch (err) {
    db.prepare("DELETE FROM users WHERE id = ?").run(info.lastInsertRowid);
    throw err;
  }

  const row = db.prepare("SELECT * FROM users WHERE id = ?").get(info.lastInsertRowid) as UserRow;
  return toPublic(row);
}

export function findByUsername(username: string): UserRow | null {
  return (db.prepare("SELECT * FROM users WHERE username = ?").get(username) as UserRow) ?? null;
}

export function findById(id: number): UserRow | null {
  return (db.prepare("SELECT * FROM users WHERE id = ?").get(id) as UserRow) ?? null;
}

export function listUsers(opts: { onlyPending?: boolean; limit?: number; offset?: number } = {}): PublicUser[] {
  const limit = opts.limit ?? 100;
  const offset = opts.offset ?? 0;
  const where = opts.onlyPending ? "WHERE is_active = 0 AND is_suspended = 0" : "";
  const rows = db
    .prepare(`SELECT * FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`)
    .all(limit, offset) as UserRow[];
  return rows.map(toPublic);
}

export function countUsers() {
  const total = (db.prepare("SELECT COUNT(*) AS n FROM users").get() as { n: number }).n;
  const active = (db.prepare("SELECT COUNT(*) AS n FROM users WHERE is_active = 1 AND is_suspended = 0").get() as { n: number }).n;
  const pending = (db.prepare("SELECT COUNT(*) AS n FROM users WHERE is_active = 0").get() as { n: number }).n;
  const suspended = (db.prepare("SELECT COUNT(*) AS n FROM users WHERE is_suspended = 1").get() as { n: number }).n;
  return { total, active, pending, suspended };
}

export type UpdateUserInput = {
  is_active?: boolean;
  is_suspended?: boolean;
  role?: "user" | "admin";
  daily_limit?: number;
  expires_at?: string | null;
  full_name?: string;
  email?: string | null;
};

export function updateUser(id: number, patch: UpdateUserInput): PublicUser {
  const fields: string[] = [];
  const values: unknown[] = [];
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    if (key === "is_active" || key === "is_suspended") {
      fields.push(`${key} = ?`);
      values.push(value ? 1 : 0);
    } else {
      fields.push(`${key} = ?`);
      values.push(value);
    }
  }
  if (fields.length === 0) {
    const row = findById(id);
    if (!row) throw new NotFoundError("user not found");
    return toPublic(row);
  }
  values.push(id);
  db.prepare(`UPDATE users SET ${fields.join(", ")} WHERE id = ?`).run(...values);
  const row = findById(id);
  if (!row) throw new NotFoundError("user not found");
  invalidateUser(id);
  return toPublic(row);
}

export async function deleteUser(id: number): Promise<void> {
  const row = findById(id);
  if (!row) throw new NotFoundError("user not found");
  await adguard.deleteClient(row.client_id);
  db.prepare("DELETE FROM users WHERE id = ?").run(id);
  invalidateUser(id);
}

export function recordLoginAttempt(username: string, ip: string | null, success: boolean): void {
  db.prepare("INSERT INTO login_attempts (username, ip_address, success) VALUES (?, ?, ?)").run(
    username,
    ip,
    success ? 1 : 0,
  );
}

export function isLockedOut(username: string): boolean {
  const row = db
    .prepare(
      `SELECT COUNT(*) AS n FROM login_attempts
       WHERE username = ? AND success = 0
         AND attempted_at >= datetime('now', ?)`,
    )
    .get(username, `-${config.auth.lockoutMinutes} minutes`) as { n: number };
  return row.n >= config.auth.maxLoginAttempts;
}

export function touchLastLogin(id: number): void {
  db.prepare("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?").run(id);
}

export function bumpUsage(userId: number, blocked: boolean): void {
  const today = new Date().toISOString().slice(0, 10);
  db.prepare(`
    INSERT INTO usage_logs (user_id, date, queries_count, blocked_count) VALUES (?, ?, 1, ?)
    ON CONFLICT(user_id, date) DO UPDATE SET
      queries_count = queries_count + 1,
      blocked_count = blocked_count + excluded.blocked_count
  `).run(userId, today, blocked ? 1 : 0);
}

export function getTodayUsage(userId: number): { queries: number; blocked: number } {
  const today = new Date().toISOString().slice(0, 10);
  const row = db
    .prepare("SELECT queries_count, blocked_count FROM usage_logs WHERE user_id = ? AND date = ?")
    .get(userId, today) as { queries_count: number; blocked_count: number } | undefined;
  return { queries: row?.queries_count ?? 0, blocked: row?.blocked_count ?? 0 };
}

export function getUsageHistory(userId: number, days: number): Array<{ date: string; queries: number; blocked: number }> {
  const rows = db
    .prepare(
      `SELECT date, queries_count, blocked_count FROM usage_logs
       WHERE user_id = ? AND date >= date('now', ?)
       ORDER BY date ASC`,
    )
    .all(userId, `-${days} days`) as Array<{ date: string; queries_count: number; blocked_count: number }>;
  return rows.map((r) => ({ date: r.date, queries: r.queries_count, blocked: r.blocked_count }));
}

export class ConflictError extends Error {
  status = 409;
}
export class NotFoundError extends Error {
  status = 404;
}

export { toPublic };
