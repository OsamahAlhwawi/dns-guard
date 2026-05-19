import { SignJWT, jwtVerify, importPKCS8, importSPKI, type KeyLike } from "jose";
import { randomUUID } from "node:crypto";
import { db } from "../db/connection.ts";
import { config } from "../config.ts";

let privateKey: KeyLike | null = null;
let publicKey: KeyLike | null = null;

async function getPrivateKey(): Promise<KeyLike> {
  if (!privateKey) {
    privateKey = await importPKCS8(config.jwt.privateKeyPem, "RS256");
  }
  return privateKey;
}

async function getPublicKey(): Promise<KeyLike> {
  if (!publicKey) {
    publicKey = await importSPKI(config.jwt.publicKeyPem, "RS256");
  }
  return publicKey;
}

export type JwtClaims = {
  sub: string;
  user_id: number;
  username: string;
  role: "user" | "admin";
  is_active: boolean;
  typ: "access" | "refresh";
  jti: string;
  iat: number;
  exp: number;
  iss: string;
};

type SignInput = Omit<JwtClaims, "iat" | "exp" | "jti" | "iss">;

async function sign(payload: SignInput, ttlSeconds: number): Promise<{ token: string; jti: string; exp: number }> {
  const jti = randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const exp = now + ttlSeconds;
  const key = await getPrivateKey();
  const token = await new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(config.jwt.issuer)
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .setJti(jti)
    .setSubject(payload.sub)
    .sign(key);
  return { token, jti, exp };
}

export async function signAccessToken(input: Omit<SignInput, "typ">) {
  return sign({ ...input, typ: "access" }, config.jwt.accessTtl);
}

export async function signRefreshToken(input: Omit<SignInput, "typ">) {
  const result = await sign({ ...input, typ: "refresh" }, config.jwt.refreshTtl);
  db.prepare(
    "INSERT INTO sessions (user_id, jwt_id, expires_at) VALUES (?, ?, datetime(?, 'unixepoch'))",
  ).run(input.user_id, result.jti, result.exp);
  return result;
}

export async function verifyToken(token: string): Promise<JwtClaims> {
  const key = await getPublicKey();
  const { payload } = await jwtVerify(token, key, { issuer: config.jwt.issuer });
  if (!payload.jti) throw new Error("token missing jti");
  if (isBlacklisted(payload.jti as string)) {
    throw new Error("token revoked");
  }
  return payload as unknown as JwtClaims;
}

export function blacklistToken(jti: string, expEpoch: number): void {
  db.prepare(
    "INSERT OR IGNORE INTO token_blacklist (jwt_id, expires_at) VALUES (?, datetime(?, 'unixepoch'))",
  ).run(jti, expEpoch);
}

export function isBlacklisted(jti: string): boolean {
  const row = db.prepare("SELECT 1 FROM token_blacklist WHERE jwt_id = ?").get(jti);
  return !!row;
}

export function pruneBlacklist(): void {
  db.prepare("DELETE FROM token_blacklist WHERE expires_at < CURRENT_TIMESTAMP").run();
}
