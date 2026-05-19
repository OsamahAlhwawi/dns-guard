// Unit-test the small pure helpers of the DoH proxy without booting the full app.
import { describe, expect, it } from "bun:test";

function servfailFor(reqId: number): Uint8Array {
  const buf = new Uint8Array(12);
  buf[0] = (reqId >> 8) & 0xff;
  buf[1] = reqId & 0xff;
  buf[2] = 0x81;
  buf[3] = 0x82;
  return buf;
}

function extractReqId(body: Uint8Array | null): number {
  if (!body || body.length < 2) return 0;
  return (body[0]! << 8) | body[1]!;
}

function decodeBase64Url(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

describe("servfailFor", () => {
  it("echoes request id into bytes 0–1", () => {
    const out = servfailFor(0xdead);
    expect(out[0]).toBe(0xde);
    expect(out[1]).toBe(0xad);
  });
  it("sets RCODE=SERVFAIL (2) in byte 3 low nibble", () => {
    const out = servfailFor(1);
    expect(out[3]! & 0x0f).toBe(2);
  });
  it("sets QR=1 (response) in byte 2 high bit", () => {
    const out = servfailFor(1);
    expect((out[2]! & 0x80) >> 7).toBe(1);
  });
});

describe("extractReqId", () => {
  it("returns 0 for empty body", () => {
    expect(extractReqId(null)).toBe(0);
    expect(extractReqId(new Uint8Array(0))).toBe(0);
    expect(extractReqId(new Uint8Array(1))).toBe(0);
  });
  it("decodes big-endian 16-bit id", () => {
    expect(extractReqId(new Uint8Array([0xab, 0xcd, 0, 0]))).toBe(0xabcd);
  });
});

describe("decodeBase64Url", () => {
  it("round-trips ASCII without padding", () => {
    // "hello" → aGVsbG8 (no padding)
    expect(new TextDecoder().decode(decodeBase64Url("aGVsbG8"))).toBe("hello");
  });
  it("handles url-safe alphabet", () => {
    // bytes: 0xfb 0xff → "-_8" url-safe
    const out = decodeBase64Url("-_8");
    expect(Array.from(out)).toEqual([0xfb, 0xff]);
  });
});
