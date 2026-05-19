import { describe, expect, it } from "bun:test";
import { usernameSchema, passwordSchema, registerSchema } from "../src/utils/validators.ts";

describe("usernameSchema", () => {
  it("accepts alphanumeric 3–20", () => {
    expect(usernameSchema.safeParse("alice99").success).toBe(true);
    expect(usernameSchema.safeParse("abc").success).toBe(true);
  });
  it("rejects symbols, length out of range", () => {
    expect(usernameSchema.safeParse("ab").success).toBe(false);
    expect(usernameSchema.safeParse("a".repeat(21)).success).toBe(false);
    expect(usernameSchema.safeParse("alice!").success).toBe(false);
  });
});

describe("passwordSchema", () => {
  it("requires letter + number + symbol, min 8", () => {
    expect(passwordSchema.safeParse("aaaaaaaa").success).toBe(false); // no number/symbol
    expect(passwordSchema.safeParse("aaaaaaa1").success).toBe(false); // no symbol
    expect(passwordSchema.safeParse("aaa11!").success).toBe(false); // too short
    expect(passwordSchema.safeParse("alice123!").success).toBe(true);
  });
});

describe("registerSchema", () => {
  it("optional email and full_name", () => {
    const r = registerSchema.safeParse({ username: "alice", password: "alice123!" });
    expect(r.success).toBe(true);
  });
  it("rejects bad email", () => {
    const r = registerSchema.safeParse({ username: "alice", password: "alice123!", email: "not-an-email" });
    expect(r.success).toBe(false);
  });
});
