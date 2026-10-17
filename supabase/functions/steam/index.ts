// Steam Web API proxy: the app imports a library through here, so the Steam key stays
// on the server instead of shipping inside the app.
//
// Secret (Dashboard → Edge Functions → Secrets, or `supabase secrets set`): STEAM_API_KEY
// Deploy: supabase functions deploy steam
//
// Callers need the project's anon key or a signed-in session (Supabase checks the JWT
// before this code runs). Only the read-only calls the app makes are forwarded, with
// checked inputs:
//   { method: "resolveVanity", value: "<vanity name>" }
//   { method: "playerSummary", value: "<steam id>[,<steam id>…]" }   (up to 100)
//   { method: "ownedGames",    value: "<steam id>", appInfo?: boolean }
//   { method: "achievements",  value: "<steam id>", appId: number }
//   { method: "schema",        appId: number }
//   { method: "friends",       value: "<steam id>" }

const API_KEY = Deno.env.get("STEAM_API_KEY") ?? "";
const STEAM_ID = /^\d{17}$/;
const VANITY = /^[A-Za-z0-9_-]{2,32}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

type Payload = { method?: unknown; value?: unknown; appId?: unknown; appInfo?: unknown };

function steamURL(payload: Payload): URL | null {
  const value = typeof payload.value === "string" ? payload.value : "";
  const appId = typeof payload.appId === "number" && Number.isInteger(payload.appId) && payload.appId > 0
    ? String(payload.appId)
    : null;
  const url = new URL("https://api.steampowered.com");
  const params = new URLSearchParams({ key: API_KEY, format: "json" });
  switch (payload.method) {
    case "resolveVanity":
      if (!VANITY.test(value)) return null;
      url.pathname = "/ISteamUser/ResolveVanityURL/v1/";
      params.set("vanityurl", value);
      break;
    case "playerSummary": {
      const ids = value.split(",");
      if (ids.length < 1 || ids.length > 100 || !ids.every((id) => STEAM_ID.test(id))) return null;
      url.pathname = "/ISteamUser/GetPlayerSummaries/v2/";
      params.set("steamids", ids.join(","));
      break;
    }
    case "ownedGames":
      if (!STEAM_ID.test(value)) return null;
      url.pathname = "/IPlayerService/GetOwnedGames/v1/";
      params.set("steamid", value);
      params.set("include_appinfo", payload.appInfo === false ? "0" : "1");
      params.set("include_played_free_games", "1");
      break;
    case "achievements":
      if (!STEAM_ID.test(value) || !appId) return null;
      url.pathname = "/ISteamUserStats/GetPlayerAchievements/v1/";
      params.set("steamid", value);
      params.set("appid", appId);
      break;
    case "schema":
      if (!appId) return null;
      url.pathname = "/ISteamUserStats/GetSchemaForGame/v2/";
      params.set("appid", appId);
      params.set("l", "french");
      break;
    case "friends":
      if (!STEAM_ID.test(value)) return null;
      url.pathname = "/ISteamUser/GetFriendList/v1/";
      params.set("steamid", value);
      params.set("relationship", "friend");
      break;
    default:
      return null;
  }
  url.search = params.toString();
  return url;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!API_KEY) return json({ error: "not configured" }, 503);

  const payload = await req.json().catch(() => null);
  const url = payload && typeof payload === "object" ? steamURL(payload as Payload) : null;
  if (!url) return json({ error: "bad request" }, 400);

  try {
    const res = await fetch(url);
    // Keep the statuses the app tells apart (private profile, rate limit); never pass
    // Steam's 401/403 bodies, which could echo the request.
    const status = res.ok ? 200 : [403, 429].includes(res.status) ? res.status : 502;
    return new Response(res.ok ? await res.text() : JSON.stringify({ error: "steam" }), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    return json({ error: "upstream" }, 502);
  }
});
