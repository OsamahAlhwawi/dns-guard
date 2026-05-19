import { describe, expect, it } from "bun:test";
import { generateClientId, generateDohToken } from "../src/utils/crypto.ts";

describe("token generators", () => {
  it("client_id is 16 chars, alphanumeric", () => {
    const id = generateClientId();
    expect(id).toMatch(/^[A-Za-z0-9]{16}$/);
  });
  it("doh token is 32 chars, alphanumeric", () => {
    const t = generateDohToken();
    expect(t).toMatch(/^[A-Za-z0-9]{32}$/);
  });
  it("client_ids are reasonably unique across 1000 calls", () => {
    const seen = new Set<string>();
    for (let i = 0; i < 1000; i++) seen.add(generateClientId());
    expect(seen.size).toBe(1000);
  });
});
