import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { profileUpdateSchema, changePasswordSchema } from "../utils/validators.ts";
import * as users from "../services/userService.ts";
import { requireAuth, type AuthVariables } from "../middleware/auth.ts";
import { hashPassword, verifyPassword } from "../utils/crypto.ts";
import { db } from "../db/connection.ts";

const app = new Hono<{ Variables: AuthVariables }>();
app.use("*", requireAuth);

app.get("/profile", (c) => {
  const claims = c.get("jwt");
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404, { message: "user not found" });
  return c.json(users.toPublic(row));
});

app.patch("/profile", async (c) => {
  const claims = c.get("jwt");
  const parsed = profileUpdateSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: "invalid input" });
  const updated = users.updateUser(claims.user_id, parsed.data);
  return c.json(updated);
});

app.post("/password", async (c) => {
  const claims = c.get("jwt");
  const parsed = changePasswordSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: "invalid input" });
  const row = users.findById(claims.user_id);
  if (!row) throw new HTTPException(404);
  const ok = await verifyPassword(parsed.data.current_password, row.password_hash);
  if (!ok) throw new HTTPException(401, { message: "current password incorrect" });
  const newHash = await hashPassword(parsed.data.new_password);
  db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").run(newHash, row.id);
  return c.json({ ok: true });
});

app.delete("/account", async (c) => {
  const claims = c.get("jwt");
  await users.deleteUser(claims.user_id);
  return c.json({ ok: true });
});

export const userRouter = app;
