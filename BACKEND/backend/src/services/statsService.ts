import * as adguard from "./adguardService.ts";
import * as users from "./userService.ts";

export async function overview(): Promise<{
  users: ReturnType<typeof users.countUsers>;
  adguard: unknown;
}> {
  const adg = await adguard.getStats().catch(() => null);
  return { users: users.countUsers(), adguard: adg };
}

export async function userQueryLog(client_id: string, opts: { older_than?: string; limit?: number } = {}) {
  return adguard.getQueryLog({ client_id, older_than: opts.older_than, limit: opts.limit ?? 100 });
}
