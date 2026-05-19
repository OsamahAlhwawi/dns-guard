import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { z } from "zod";
import { registerSchema, loginSchema, refreshSchema } from "../utils/validators.ts";
import * as users from "../services/userService.ts";
import { verifyPassword } from "../utils/crypto.ts";
import {
  signAccessToken,
  signRefreshToken,
  verifyToken,
  blacklistToken,
} from "../services/tokenService.ts";
import { invalidateUser } from "../services/tokenCache.ts";
import { requireAuth, type AuthVariables } from "../middleware/auth.ts";
import { log } from "../middleware/logging.ts";

const app = new Hono<{ Variables: AuthVariables }>();

app.post("/register", async (c) => {
  const body = registerSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!body.success) {
    throw new HTTPException(400, { message: body.error.issues[0]?.message ?? "invalid input" });
  }
  try {
    const user = await users.createUser({ ...body.data, is_active: false });
    return c.json(
      {
        status: "pending_activation",
        user: {
          id: user.id,
          username: user.username,
          is_active: user.is_active,
          role: user.role,
        },
      },
      202,
    );
  } catch (err) {
    if (err instanceof users.ConflictError) {
      throw new HTTPException(409, { message: err.message });
    }
    log.error("register failed", { err: (err as Error).message });
    throw new HTTPException(500, { message: "registration failed" });
  }
});

app.post("/login", async (c) => {
  const parsed = loginSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) {
    throw new HTTPException(400, { message: "invalid input" });
  }
  const { username, password } = parsed.data;
  const ip = c.req.header("x-forwarded-for")?.split(",")[0]?.trim() ?? null;

  if (users.isLockedOut(username)) {
    throw new HTTPException(429, { message: "too many failed attempts; try again later" });
  }
  const row = users.findByUsername(username);
  if (!row) {
    users.recordLoginAttempt(username, ip, false);
    throw new HTTPException(401, { message: "invalid credentials" });
  }
  const ok = await verifyPassword(password, row.password_hash);
  users.recordLoginAttempt(username, ip, ok);
  if (!ok) {
    throw new HTTPException(401, { message: "invalid credentials" });
  }
  if (row.is_suspended) {
    throw new HTTPException(403, { message: "account suspended" });
  }
  users.touchLastLogin(row.id);

  const claims = {
    sub: String(row.id),
    user_id: row.id,
    username: row.username,
    role: row.role,
    is_active: !!row.is_active,
  };
  const access = await signAccessToken(claims);
  const refresh = await signRefreshToken(claims);
  const me = users.toPublic(row);

  return c.json({
    access_token: access.token,
    refresh_token: refresh.token,
    expires_in: access.exp - Math.floor(Date.now() / 1000),
    user: me,
  });
});

app.post("/refresh", async (c) => {
  const parsed = refreshSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: "invalid input" });
  let claims;
  try {
    claims = await verifyToken(parsed.data.refresh_token);
  } catch {
    throw new HTTPException(401, { message: "invalid refresh token" });
  }
  if (claims.typ !== "refresh") {
    throw new HTTPException(401, { message: "wrong token type" });
  }
  const row = users.findById(claims.user_id);
  if (!row || row.is_suspended) {
    throw new HTTPException(403, { message: "account unavailable" });
  }
  const next = {
    sub: String(row.id),
    user_id: row.id,
    username: row.username,
    role: row.role,
    is_active: !!row.is_active,
  };
  const access = await signAccessToken(next);
  return c.json({
    access_token: access.token,
    expires_in: access.exp - Math.floor(Date.now() / 1000),
  });
});

app.post("/logout", requireAuth, async (c) => {
  const claims = c.get("jwt");
  blacklistToken(claims.jti, claims.exp);
  invalidateUser(claims.user_id);
  return c.json({ ok: true });
});

export const authRouter = app;
