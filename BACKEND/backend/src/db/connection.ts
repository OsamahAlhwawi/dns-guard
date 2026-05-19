import { Database } from "bun:sqlite";
import { readFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "../config.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

function openDatabase(path: string): Database {
  mkdirSync(dirname(path), { recursive: true });
  const db = new Database(path, { create: true });
  const schemaPath = resolve(__dirname, "schema.sql");
  const schema = readFileSync(schemaPath, "utf8");
  db.exec(schema);
  return db;
}

export const db = openDatabase(config.dbPath);

export type UserRow = {
  id: number;
  username: string;
  password_hash: string;
  email: string | null;
  full_name: string | null;
  token: string;
  client_id: string;
  role: "user" | "admin";
  is_active: number;
  is_suspended: number;
  plan: string;
  daily_limit: number;
  created_at: string;
  last_login: string | null;
  last_used: string | null;
  expires_at: string | null;
};
