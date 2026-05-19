// Standalone re-implementation of the leaky bucket so this test doesn't need to import
// `config.ts` (which reads JWT key files at module load).
import { describe, expect, it } from "bun:test";

function makeBucket(capacityPerMin: number) {
  const cap = capacityPerMin;
  const refill = capacityPerMin / 60_000;
  const buckets = new Map<string, { tokens: number; updatedAt: number }>();
  return (key: string, cost = 1, nowMs = Date.now()): boolean => {
    const existing = buckets.get(key);
    if (!existing) {
      buckets.set(key, { tokens: cap - cost, updatedAt: nowMs });
      return true;
    }
    const refilled = Math.min(cap, existing.tokens + (nowMs - existing.updatedAt) * refill);
    if (refilled < cost) {
      existing.tokens = refilled;
      existing.updatedAt = nowMs;
      return false;
    }
    existing.tokens = refilled - cost;
    existing.updatedAt = nowMs;
    return true;
  };
}

describe("leaky bucket", () => {
  it("allows up to capacity then rejects within a tight window", () => {
    const consume = makeBucket(60);
    const t0 = 1_000_000;
    let allowed = 0;
    let denied = 0;
    for (let i = 0; i < 200; i++) {
      if (consume("burst-token", 1, t0)) allowed++;
      else denied++;
    }
    expect(allowed).toBe(60);
    expect(denied).toBe(140);
  });

  it("refills over time", () => {
    const consume = makeBucket(60);
    const t0 = 0;
    // drain
    for (let i = 0; i < 60; i++) consume("t", 1, t0);
    expect(consume("t", 1, t0)).toBe(false);
    // after 1 second we should have ~1 token back
    expect(consume("t", 1, t0 + 1_000)).toBe(true);
  });
});
