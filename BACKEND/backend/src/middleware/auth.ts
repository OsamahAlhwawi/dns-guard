import type { MiddlewareHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import { verifyToken, type JwtClaims } from "../services/tokenService.ts";

export type AuthVariables = {
  jwt: JwtClaims;
};

export const requireAuth: MiddlewareHandler<{ Variables: AuthVariables }> = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header || !header.startsWith("Bearer ")) {
    throw new HTTPException(401, { message: "missing bearer token" });
  }
  const token = header.slice(7).trim();
  try {
    const claims = await verifyToken(token);
    if (claims.typ !== "access") {
      throw new HTTPException(401, { message: "wrong token type" });
    }
    c.set("jwt", claims);
  } catch (err) {
    if (err instanceof HTTPException) throw err;
    throw new HTTPException(401, { message: "invalid token" });
  }
  await next();
};

export const requireAdmin: MiddlewareHandler<{ Variables: AuthVariables }> = async (c, next) => {
  const claims = c.get("jwt");
  if (!claims || claims.role !== "admin") {
    throw new HTTPException(403, { message: "admin only" });
  }
  await next();
};
