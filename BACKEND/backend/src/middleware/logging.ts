import type { MiddlewareHandler } from "hono";
import { config } from "../config.ts";

const levels = { debug: 10, info: 20, warn: 30, error: 40 } as const;
const threshold = levels[config.logLevel];

function emit(level: keyof typeof levels, msg: string, fields: Record<string, unknown> = {}) {
  if (levels[level] < threshold) return;
  const line = JSON.stringify({ ts: new Date().toISOString(), level, msg, ...fields });
  if (level === "error") console.error(line);
  else console.log(line);
}

export const log = {
  debug: (msg: string, fields?: Record<string, unknown>) => emit("debug", msg, fields),
  info: (msg: string, fields?: Record<string, unknown>) => emit("info", msg, fields),
  warn: (msg: string, fields?: Record<string, unknown>) => emit("warn", msg, fields),
  error: (msg: string, fields?: Record<string, unknown>) => emit("error", msg, fields),
};

export const requestLogger: MiddlewareHandler = async (c, next) => {
  const start = performance.now();
  await next();
  const ms = Math.round(performance.now() - start);
  log.info("http", {
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    ms,
  });
};
