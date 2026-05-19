import { hash as argonHash, verify as argonVerify, Algorithm } from "@node-rs/argon2";
import { randomBytes } from "node:crypto";

export async function hashPassword(plain: string): Promise<string> {
  const { config } = await import("../config.ts");
  return argonHash(plain, {
    algorithm: Algorithm.Argon2id,
    memoryCost: config.argon2.memoryCost,
    timeCost: config.argon2.timeCost,
    parallelism: config.argon2.parallelism,
  });
}

export async function verifyPassword(plain: string, hashStr: string): Promise<boolean> {
  try {
    return await argonVerify(hashStr, plain);
  } catch {
    return false;
  }
}

const TOKEN_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

function randomString(length: number): string {
  const bytes = randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += TOKEN_ALPHABET[bytes[i]! % TOKEN_ALPHABET.length];
  }
  return out;
}

export function generateClientId(): string {
  return randomString(16);
}

export function generateDohToken(): string {
  return randomString(32);
}
