import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import * as users from "../services/userService.ts";
import * as adguard from "../services/adguardService.ts";
import { requireAuth, type AuthVariables } from "../middleware/auth.ts";

const app = new Hono<{ Variables: AuthVariables }>();
app.use("*", requireAuth);

app.get("/today", (c) => {
  const claims = c.get("jwt");
  const u = users.getTodayUsage(claims.user_id);
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404);
  return c.json({
    queries: u.queries,
    blocked: u.blocked,
    daily_limit: row.daily_limit,
    block_ratio: u.queries > 0 ? u.blocked / u.queries : 0,
  });
});

app.get("/history", (c) => {
  const claims = c.get("jwt");
  const period = c.req.query("period") ?? "7d";
  const days = period === "30d" ? 30 : period === "24h" ? 1 : 7;
  return c.json({ period, days, points: users.getUsageHistory(claims.user_id, days) });
});

app.get("/top-domains", async (c) => {
  const claims = c.get("jwt");
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404);
  const log = await adguard.getQueryLog({ client_id: row.client_id, limit: 200 }).catch(() => null);
  return c.json({ client_id: row.client_id, log });
});

export const statsRouter = app;
