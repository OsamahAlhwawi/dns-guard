import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import * as users from "../services/userService.ts";
import { requireAuth, type AuthVariables } from "../middleware/auth.ts";
import { config } from "../config.ts";

const app = new Hono<{ Variables: AuthVariables }>();
app.use("*", requireAuth);

function statusFor(row: ReturnType<typeof users.findById>): string {
  if (!row) return "unknown";
  if (row.is_suspended) return "suspended";
  if (!row.is_active) return "pending_activation";
  if (row.expires_at && new Date(row.expires_at).getTime() < Date.now()) return "expired";
  return "active";
}

app.get("/status", (c) => {
  const claims = c.get("jwt");
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404);
  return c.json({
    status: statusFor(row),
    is_active: !!row.is_active,
    is_suspended: !!row.is_suspended,
    expires_at: row.expires_at,
  });
});

app.get("/config", (c) => {
  const claims = c.get("jwt");
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404);
  return c.json({
    doh_url: `${config.dnsBaseUrl}/dns-query/${row.token}`,
    status: statusFor(row),
  });
});

export const dnsRouter = app;
