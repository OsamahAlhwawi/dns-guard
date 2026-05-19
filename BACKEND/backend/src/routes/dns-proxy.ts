import { Hono } from "hono";
import * as tokenCache from "../services/tokenCache.ts";
import * as adguard from "../services/adguardService.ts";
import * as users from "../services/userService.ts";
import { tryConsume } from "../middleware/rateLimit.ts";
import { log } from "../middleware/logging.ts";

const app = new Hono();

// Build a SERVFAIL DNS wire-format response for a given request id.
// 12-byte header: id(2) | flags(2)=0x8182 | qd(2)=0 | an=0 | ns=0 | ar=0
function servfailFor(reqId: number): Uint8Array {
  const buf = new Uint8Array(12);
  buf[0] = (reqId >> 8) & 0xff;
  buf[1] = reqId & 0xff;
  buf[2] = 0x81; // QR=1, OPCODE=0, AA=0, TC=0, RD=1
  buf[3] = 0x82; // RA=1, Z=0, RCODE=2 (SERVFAIL)
  return buf;
}

function extractReqId(body: Uint8Array | null): number {
  if (!body || body.length < 2) return 0;
  return (body[0]! << 8) | body[1]!;
}

function refuse(reqId: number, status = 403): Response {
  return new Response(servfailFor(reqId), {
    status,
    headers: { "Content-Type": "application/dns-message", "Cache-Control": "no-store" },
  });
}

function decodeBase64Url(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function handleDoH(c: Parameters<Parameters<typeof app.get>[1]>[0], token: string): Promise<Response> {
  const accept = c.req.header("accept") ?? "application/dns-message";

  let body: Uint8Array | null = null;
  if (c.req.method === "POST") {
    const buf = await c.req.arrayBuffer();
    body = new Uint8Array(buf);
  } else {
    const dnsParam = c.req.query("dns");
    if (dnsParam) {
      try {
        body = decodeBase64Url(dnsParam);
      } catch {
        return refuse(0, 400);
      }
    }
  }
  const reqId = extractReqId(body);

  const entry = tokenCache.getByToken(token);
  if (!entry) {
    return refuse(reqId, 404);
  }
  if (entry.is_suspended || !entry.is_active) {
    return refuse(reqId, 403);
  }
  if (entry.expires_at && new Date(entry.expires_at).getTime() < Date.now()) {
    return refuse(reqId, 403);
  }
  if (!tryConsume(token, 1)) {
    return refuse(reqId, 429);
  }

  const todayUsage = users.getTodayUsage(entry.user_id);
  if (todayUsage.queries >= entry.daily_limit) {
    return refuse(reqId, 429);
  }

  let upstream: Response;
  try {
    upstream = await adguard.forwardDohRequest({
      client_id: entry.client_id,
      method: c.req.method === "POST" ? "POST" : "GET",
      body: c.req.method === "POST" && body ? body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength) as ArrayBuffer : null,
      query: c.req.url.split("?")[1] ?? "",
      accept,
    });
  } catch (err) {
    log.error("doh upstream failed", { err: (err as Error).message });
    return refuse(reqId, 502);
  }

  users.bumpUsage(entry.user_id, false);

  const headers = new Headers();
  const ct = upstream.headers.get("Content-Type");
  if (ct) headers.set("Content-Type", ct);
  headers.set("Cache-Control", "no-store");
  return new Response(upstream.body, { status: upstream.status, headers });
}

app.get("/:token", (c) => handleDoH(c, c.req.param("token")));
app.post("/:token", (c) => handleDoH(c, c.req.param("token")));

export const dnsProxyRouter = app;
