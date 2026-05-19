import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { config } from "./config.ts";
import { authRouter } from "./routes/auth.ts";
import { userRouter } from "./routes/user.ts";
import { statsRouter } from "./routes/stats.ts";
import { dnsRouter } from "./routes/dns.ts";
import { adminRouter } from "./routes/admin.ts";
import { dnsProxyRouter } from "./routes/dns-proxy.ts";
import { requestLogger, log } from "./middleware/logging.ts";
import { pruneBlacklist } from "./services/tokenService.ts";

const app = new Hono();

app.use("*", requestLogger);

app.get("/healthz", (c) => c.json({ ok: true }));

app.route("/v1/auth", authRouter);
app.route("/v1/user", userRouter);
app.route("/v1/stats", statsRouter);
app.route("/v1/dns", dnsRouter);
app.route("/v1/admin", adminRouter);
app.route("/dns-query", dnsProxyRouter);

app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ error: err.message }, err.status);
  }
  log.error("unhandled", { err: err.message, stack: err.stack });
  return c.json({ error: "internal_error" }, 500);
});

app.notFound((c) => c.json({ error: "not_found" }, 404));

setInterval(() => {
  try {
    pruneBlacklist();
  } catch (err) {
    log.warn("blacklist prune failed", { err: (err as Error).message });
  }
}, 60 * 60 * 1000).unref?.();

const server = Bun.serve({
  port: config.port,
  hostname: "0.0.0.0",
  fetch: app.fetch,
  idleTimeout: 30,
});

log.info("server ready", { port: server.port, env: config.env });
