// Proves a player owns a Steam account before their profile shows it (`profiles.steam_id`).
// The app can't write steam_id itself (see the trigger in supabase/schema.sql): without
// this proof anyone could claim someone else's Steam id and appear as them to friends.
//
// Flow (Steam OpenID 2.0, the "Sign in through Steam" button):
//   1. POST with the player's session → { url }: Steam's sign-in page.
//   2. The app opens it; after sign-in Steam sends the browser back here (GET).
//   3. This checks the answer with Steam, saves the Steam id on the profile, and sends
//      the browser to gameboxd://steam-linked (?error=… when it didn't work).
//
// Secret: STEAM_LINK_SECRET (any long random string; signs the state between 1 and 2).
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// Deploy: supabase functions deploy steam-link --no-verify-jwt
// (step 2 comes from Steam without a session, so the POST checks the session itself.)

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const LINK_SECRET = Deno.env.get("STEAM_LINK_SECRET") ?? "";
const STEAM_LOGIN = "https://steamcommunity.com/openid/login";
const APP_RETURN = "gameboxd://steam-linked";
const STATE_LIFETIME_MS = 10 * 60 * 1000;

const encoder = new TextEncoder();

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function backToApp(error?: string): Response {
  const target = error ? `${APP_RETURN}?error=${encodeURIComponent(error)}` : APP_RETURN;
  return new Response(null, { status: 302, headers: { Location: target } });
}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sign(payload: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(LINK_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, encoder.encode(payload)));
}

/// "<user id>.<expiry>.<signature>": who asked, until when, and proof it came from here.
async function makeState(userId: string): Promise<string> {
  const payload = `${userId}.${Date.now() + STATE_LIFETIME_MS}`;
  return `${payload}.${await sign(payload)}`;
}

async function readState(state: string | null): Promise<string | null> {
  const parts = state?.split(".") ?? [];
  if (parts.length !== 3) return null;
  const [userId, expiry, signature] = parts;
  if (!/^[0-9a-f-]{36}$/.test(userId) || !(Number(expiry) > Date.now())) return null;
  return (await sign(`${userId}.${expiry}`)) === signature ? userId : null;
}

function callbackURL(state: string): string {
  return `${SUPABASE_URL}/functions/v1/steam-link?state=${encodeURIComponent(state)}`;
}

async function signedInUser(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { Authorization: auth, apikey: ANON_KEY } });
  if (!res.ok) return null;
  const user = await res.json().catch(() => null);
  return typeof user?.id === "string" ? user.id : null;
}

/// Asks Steam whether this sign-in answer really comes from it; returns the Steam id.
async function verifiedSteamId(params: URLSearchParams, state: string): Promise<string | null> {
  if (params.get("openid.mode") !== "id_res") return null;
  if (params.get("openid.return_to") !== callbackURL(state)) return null;
  if (params.get("openid.op_endpoint") !== STEAM_LOGIN) return null;
  const claimed = params.get("openid.claimed_id") ?? "";
  const match = claimed.match(/^https:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/);
  if (!match) return null;

  const check = new URLSearchParams();
  for (const [key, value] of params) if (key.startsWith("openid.")) check.set(key, value);
  check.set("openid.mode", "check_authentication");
  const res = await fetch(STEAM_LOGIN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: check.toString(),
  });
  const text = await res.text();
  return res.ok && /^is_valid\s*:\s*true\s*$/m.test(text) ? match[1] : null;
}

async function saveSteamId(userId: string, steamId: string): Promise<boolean> {
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    "Content-Type": "application/json",
    Prefer: "return=minimal",
  };
  // Proven ownership wins over an earlier claim on another account.
  await fetch(`${SUPABASE_URL}/rest/v1/profiles?steam_id=eq.${steamId}&id=neq.${userId}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ steam_id: null, steam_verified: false }),
  });
  const res = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ steam_id: steamId, steam_verified: true }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  if (!SUPABASE_URL || !SERVICE_KEY || !LINK_SECRET) return json({ error: "not configured" }, 503);
  const url = new URL(req.url);

  if (req.method === "POST") {
    const userId = await signedInUser(req);
    if (!userId) return json({ error: "sign in first" }, 401);
    const state = await makeState(userId);
    const login = new URL(STEAM_LOGIN);
    login.search = new URLSearchParams({
      "openid.ns": "http://specs.openid.net/auth/2.0",
      "openid.mode": "checkid_setup",
      "openid.return_to": callbackURL(state),
      "openid.realm": SUPABASE_URL,
      "openid.identity": "http://specs.openid.net/auth/2.0/identifier_select",
      "openid.claimed_id": "http://specs.openid.net/auth/2.0/identifier_select",
    }).toString();
    return json({ url: login.toString() });
  }

  if (req.method === "GET") {
    const state = url.searchParams.get("state");
    const userId = await readState(state);
    if (!userId || !state) return backToApp("expired");
    const steamId = await verifiedSteamId(url.searchParams, state).catch(() => null);
    if (!steamId) return backToApp("not_verified");
    return (await saveSteamId(userId, steamId)) ? backToApp() : backToApp("save_failed");
  }

  return json({ error: "method not allowed" }, 405);
});
