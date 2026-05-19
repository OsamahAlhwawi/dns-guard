import { config } from "../config.ts";

type Bucket = { tokens: number; updatedAt: number };

const buckets = new Map<string, Bucket>();
const REFILL_PER_MS = config.rateLimit.tokenPerMinute / 60_000;
const CAPACITY = config.rateLimit.tokenPerMinute;

export function tryConsume(key: string, cost = 1): boolean {
  const now = Date.now();
  const existing = buckets.get(key);
  if (!existing) {
    buckets.set(key, { tokens: CAPACITY - cost, updatedAt: now });
    return true;
  }
  const elapsed = now - existing.updatedAt;
  const refilled = Math.min(CAPACITY, existing.tokens + elapsed * REFILL_PER_MS);
  if (refilled < cost) {
    existing.tokens = refilled;
    existing.updatedAt = now;
    return false;
  }
  existing.tokens = refilled - cost;
  existing.updatedAt = now;
  return true;
}

setInterval(() => {
  const cutoff = Date.now() - 5 * 60_000;
  for (const [key, bucket] of buckets.entries()) {
    if (bucket.updatedAt < cutoff && bucket.tokens >= CAPACITY) {
      buckets.delete(key);
    }
  }
}, 60_000).unref?.();
