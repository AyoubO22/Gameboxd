// IGDB proxy: the app asks for box art and characters here, so the Twitch client secret
// stays on the server instead of shipping inside the app.
//
// Secrets (Dashboard → Edge Functions → Secrets, or `supabase secrets set`):
//   IGDB_CLIENT_ID, IGDB_CLIENT_SECRET
// Deploy: supabase functions deploy igdb
//
// Callers need the project's anon key or a signed-in session (Supabase checks the JWT
// before this code runs). Only the two read-only endpoints the app uses are forwarded.

const CLIENT_ID = Deno.env.get("IGDB_CLIENT_ID") ?? "";
const CLIENT_SECRET = Deno.env.get("IGDB_CLIENT_SECRET") ?? "";
const ENDPOINTS = new Set(["games", "characters"]);

let token: { value: string; expires: number } | null = null;

async function accessToken(): Promise<string> {
  if (token && token.expires > Date.now()) return token.value;
  const url = new URL("https://id.twitch.tv/oauth2/token");
  url.search = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: "client_credentials",
  }).toString();
  const res = await fetch(url, { method: "POST" });
  if (!res.ok) throw new Error(`twitch token ${res.status}`);
  const body = await res.json();
  token = { value: body.access_token, expires: Date.now() + (body.expires_in - 60) * 1000 };
  return token.value;
}

async function igdb(endpoint: string, query: string): Promise<Response> {
  const call = async () =>
    fetch(`https://api.igdb.com/v4/${endpoint}`, {
      method: "POST",
      headers: { "Client-ID": CLIENT_ID, Authorization: `Bearer ${await accessToken()}` },
      body: query,
    });
  let res = await call();
  if (res.status === 401) {
    token = null;
    res = await call();
  }
  return res;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!CLIENT_ID || !CLIENT_SECRET) return json({ error: "not configured" }, 503);

  const payload = await req.json().catch(() => null);
  const endpoint = payload?.endpoint;
  const query = payload?.query;
  if (typeof endpoint !== "string" || !ENDPOINTS.has(endpoint) || typeof query !== "string" || query.length > 1000) {
    return json({ error: "bad request" }, 400);
  }

  try {
    const res = await igdb(endpoint, query);
    return new Response(await res.text(), {
      status: res.ok ? 200 : res.status === 429 ? 429 : 502,
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    return json({ error: "upstream" }, 502);
  }
});
