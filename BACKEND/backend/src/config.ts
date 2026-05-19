import { z } from "zod";
import { readFileSync } from "node:fs";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("production"),
  PORT: z.coerce.number().int().positive().default(8080),

  DOMAIN: z.string().min(1),
  API_BASE_URL: z.string().url(),
  DNS_BASE_URL: z.string().url(),

  DB_PATH: z.string().default("./data/dns-guard.sqlite"),

  JWT_ISSUER: z.string().default("dns-guard"),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(1800),
  JWT_REFRESH_TTL_SECONDS: z.coerce.number().int().positive().default(2_592_000),
  JWT_PRIVATE_KEY_PATH: z.string(),
  JWT_PUBLIC_KEY_PATH: z.string(),

  ADGUARD_URL: z.string().url(),
  ADGUARD_API_USER: z.string().min(1),
  ADGUARD_API_PASSWORD: z.string().min(1),

  ARGON2_MEMORY_KIB: z.coerce.number().int().positive().default(19_456),
  ARGON2_ITERATIONS: z.coerce.number().int().positive().default(2),
  ARGON2_PARALLELISM: z.coerce.number().int().positive().default(1),

  LOGIN_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),
  LOGIN_LOCKOUT_MINUTES: z.coerce.number().int().positive().default(15),
  DEFAULT_DAILY_LIMIT: z.coerce.number().int().nonnegative().default(0),

  TOKEN_RATE_LIMIT_PER_MIN: z.coerce.number().int().positive().default(2_000),

  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment configuration:", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

const env = parsed.data;

const jwtPrivateKeyPem = readFileSync(env.JWT_PRIVATE_KEY_PATH, "utf8");
const jwtPublicKeyPem = readFileSync(env.JWT_PUBLIC_KEY_PATH, "utf8");

export const config = {
  env: env.NODE_ENV,
  port: env.PORT,

  domain: env.DOMAIN,
  apiBaseUrl: env.API_BASE_URL,
  dnsBaseUrl: env.DNS_BASE_URL,

  dbPath: env.DB_PATH,

  jwt: {
    issuer: env.JWT_ISSUER,
    accessTtl: env.JWT_ACCESS_TTL_SECONDS,
    refreshTtl: env.JWT_REFRESH_TTL_SECONDS,
    privateKeyPem: jwtPrivateKeyPem,
    publicKeyPem: jwtPublicKeyPem,
  },

  adguard: {
    url: env.ADGUARD_URL,
    user: env.ADGUARD_API_USER,
    password: env.ADGUARD_API_PASSWORD,
  },

  argon2: {
    memoryCost: env.ARGON2_MEMORY_KIB,
    timeCost: env.ARGON2_ITERATIONS,
    parallelism: env.ARGON2_PARALLELISM,
  },

  auth: {
    maxLoginAttempts: env.LOGIN_MAX_ATTEMPTS,
    lockoutMinutes: env.LOGIN_LOCKOUT_MINUTES,
    defaultDailyLimit: env.DEFAULT_DAILY_LIMIT,
  },

  rateLimit: {
    tokenPerMinute: env.TOKEN_RATE_LIMIT_PER_MIN,
  },

  logLevel: env.LOG_LEVEL,
} as const;

export type Config = typeof config;
