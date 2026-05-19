import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { adminCreateUserSchema, updateUserSchema } from "../utils/validators.ts";
import * as users from "../services/userService.ts";
import * as statsService from "../services/statsService.ts";
import { requireAuth, requireAdmin, type AuthVariables } from "../middleware/auth.ts";

const app = new Hono<{ Variables: AuthVariables }>();
app.use("*", requireAuth, requireAdmin);

app.get("/users", (c) => {
  const limit = Number(c.req.query("limit") ?? 100);
  const offset = Number(c.req.query("offset") ?? 0);
  const pending = c.req.query("pending") === "1";
  return c.json({ users: users.listUsers({ onlyPending: pending, limit, offset }) });
});

app.get("/pending", (c) => {
  return c.json({ users: users.listUsers({ onlyPending: true, limit: 200 }) });
});

app.post("/users", async (c) => {
  const parsed = adminCreateUserSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: parsed.error.issues[0]?.message ?? "invalid input" });
  try {
    const user = await users.createUser(parsed.data);
    return c.json(user, 201);
  } catch (err) {
    if (err instanceof users.ConflictError) throw new HTTPException(409, { message: err.message });
    throw new HTTPException(500, { message: (err as Error).message });
  }
});

app.patch("/users/:id", async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isFinite(id)) throw new HTTPException(400);
  const parsed = updateUserSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: parsed.error.issues[0]?.message ?? "invalid input" });
  try {
    const user = users.updateUser(id, parsed.data);
    return c.json(user);
  } catch (err) {
    if (err instanceof users.NotFoundError) throw new HTTPException(404, { message: err.message });
    throw new HTTPException(500, { message: (err as Error).message });
  }
});

app.delete("/users/:id", async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isFinite(id)) throw new HTTPException(400);
  try {
    await users.deleteUser(id);
    return c.json({ ok: true });
  } catch (err) {
    if (err instanceof users.NotFoundError) throw new HTTPException(404, { message: err.message });
    throw new HTTPException(500, { message: (err as Error).message });
  }
});

app.get("/users/:id/logs", async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isFinite(id)) throw new HTTPException(400);
  const row = users.findById(id);
  if (!row) throw new HTTPException(404);
  const limit = Number(c.req.query("limit") ?? 100);
  const older_than = c.req.query("older_than") ?? undefined;
  const log = await statsService.userQueryLog(row.client_id, { limit, older_than });
  return c.json({ client_id: row.client_id, log });
});

app.get("/users/:id/stats", (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isFinite(id)) throw new HTTPException(400);
  const row = users.findById(id);
  if (!row) throw new HTTPException(404);
  return c.json({
    today: users.getTodayUsage(id),
    history: users.getUsageHistory(id, 30),
    user: users.toPublic(row),
  });
});

app.get("/stats/overview", async (c) => {
  return c.json(await statsService.overview());
});

export const adminRouter = app;
