import { db, type UserRow } from "../db/connection.ts";

export type TokenCacheEntry = {
  user_id: number;
  client_id: string;
  username: string;
  is_active: boolean;
  is_suspended: boolean;
  daily_limit: number;
  expires_at: string | null;
};

const TTL_MS = 60_000;
const cache = new Map<string, { entry: TokenCacheEntry | null; cachedAt: number }>();

function lookup(token: string): TokenCacheEntry | null {
  const row = db
    .prepare(
      "SELECT id, username, client_id, is_active, is_suspended, daily_limit, expires_at FROM users WHERE token = ?",
    )
    .get(token) as Pick<
      UserRow,
      "id" | "username" | "client_id" | "is_active" | "is_suspended" | "daily_limit" | "expires_at"
    > | undefined;
  if (!row) return null;
  return {
    user_id: row.id,
    client_id: row.client_id,
    username: row.username,
    is_active: !!row.is_active,
    is_suspended: !!row.is_suspended,
    daily_limit: row.daily_limit,
    expires_at: row.expires_at,
  };
}

export function getByToken(token: string): TokenCacheEntry | null {
  const hit = cache.get(token);
  const now = Date.now();
  if (hit && now - hit.cachedAt < TTL_MS) {
    return hit.entry;
  }
  const entry = lookup(token);
  cache.set(token, { entry, cachedAt: now });
  return entry;
}

export function invalidate(token: string): void {
  cache.delete(token);
}

export function invalidateAll(): void {
  cache.clear();
}

export function invalidateUser(userId: number): void {
  for (const [token, value] of cache.entries()) {
    if (value.entry?.user_id === userId) cache.delete(token);
  }
}
