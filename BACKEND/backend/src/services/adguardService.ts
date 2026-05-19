import { config } from "../config.ts";

function authHeader(): string {
  return "Basic " + Buffer.from(`${config.adguard.user}:${config.adguard.password}`).toString("base64");
}

async function request<T = unknown>(path: string, init: RequestInit = {}): Promise<T> {
  const url = `${config.adguard.url}${path}`;
  const headers = new Headers(init.headers);
  headers.set("Authorization", authHeader());
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  const res = await fetch(url, { ...init, headers });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`AdGuard ${path} → ${res.status}: ${body.slice(0, 200)}`);
  }
  const text = await res.text();
  if (!text) return undefined as T;
  try {
    return JSON.parse(text) as T;
  } catch {
    return text as unknown as T;
  }
}

type AdguardClient = {
  name: string;
  ids: string[];
  use_global_settings?: boolean;
  filtering_enabled?: boolean;
  safebrowsing_enabled?: boolean;
  parental_enabled?: boolean;
  use_global_blocked_services?: boolean;
  blocked_services?: string[];
  upstreams?: string[];
  tags?: string[];
};

export async function addClient(client_id: string, username: string): Promise<void> {
  const body: AdguardClient = {
    name: username,
    ids: [client_id],
    use_global_settings: true,
    use_global_blocked_services: true,
  };
  try {
    await request("/control/clients/add", { method: "POST", body: JSON.stringify(body) });
  } catch (err) {
    const msg = (err as Error).message;
    if (msg.includes("already exists") || msg.includes("409")) return;
    throw err;
  }
}

export async function deleteClient(client_id: string): Promise<void> {
  try {
    await request("/control/clients/delete", {
      method: "POST",
      body: JSON.stringify({ name: client_id }),
    });
  } catch {
    /* swallow — best-effort cleanup */
  }
}

export async function updateClient(client_id: string, patch: Partial<AdguardClient>): Promise<void> {
  await request("/control/clients/update", {
    method: "POST",
    body: JSON.stringify({ name: client_id, data: { ids: [client_id], ...patch } }),
  });
}

export async function getStats(): Promise<unknown> {
  return request("/control/stats");
}

export async function getQueryLog(params: {
  client_id?: string;
  older_than?: string;
  limit?: number;
  search?: string;
}): Promise<unknown> {
  const qs = new URLSearchParams();
  if (params.client_id) qs.set("search", params.client_id);
  if (params.older_than) qs.set("older_than", params.older_than);
  if (params.limit) qs.set("limit", String(params.limit));
  if (params.search) qs.set("search", params.search);
  return request(`/control/querylog?${qs.toString()}`);
}

export async function forwardDohRequest(opts: {
  client_id: string;
  method: "GET" | "POST";
  body: ArrayBuffer | null;
  query: string;
  accept: string;
}): Promise<Response> {
  const path = `/dns-query/${encodeURIComponent(opts.client_id)}`;
  const url = `${config.adguard.url}${path}${opts.query ? `?${opts.query}` : ""}`;
  const headers: Record<string, string> = {
    Accept: opts.accept || "application/dns-message",
  };
  if (opts.method === "POST" && opts.body) {
    headers["Content-Type"] = "application/dns-message";
  }
  return fetch(url, {
    method: opts.method,
    headers,
    body: opts.method === "POST" ? opts.body : undefined,
  });
}
