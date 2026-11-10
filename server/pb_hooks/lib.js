// Shared helpers for gameboxd.pb.js. PocketBase runs each handler in its own VM, so
// handlers `require` this file instead of seeing top-level variables.

const STEAM_ID = /^\d{17}$/;
const VANITY = /^[A-Za-z0-9_-]{2,32}$/;
const STEAM_LOGIN = "https://steamcommunity.com/openid/login";
const APP_RETURN = "gameboxd://steam-linked";
const STATE_LIFETIME_MS = 10 * 60 * 1000;

function env(name) {
  return $os.getenv(name) || "";
}

// Names that would pass for the app itself.
function isReservedName(name) {
  const n = String(name || "").toLowerCase();
  return n.includes("gameboxd") ||
    /^(admin|administrateur|administrator|moderateur|moderator|modo|support|staff|team|official|officiel)([_ ]|$)/.test(n);
}

function query(params) {
  return Object.keys(params).map((k) => encodeURIComponent(k) + "=" + encodeURIComponent(params[k])).join("&");
}

function parseQuery(text) {
  const out = {};
  for (const part of String(text || "").split("&")) {
    if (!part) continue;
    const i = part.indexOf("=");
    const key = decodeURIComponent((i < 0 ? part : part.slice(0, i)).replace(/\+/g, " "));
    out[key] = i < 0 ? "" : decodeURIComponent(part.slice(i + 1).replace(/\+/g, " "));
  }
  return out;
}

// ── IGDB (Twitch credentials stay on the server) ─────────────────────────────

function igdbToken(force) {
  const cached = $app.store().get("igdb_token");
  if (!force && cached && cached.expires > Date.now()) return cached.value;
  const res = $http.send({
    method: "POST",
    url: "https://id.twitch.tv/oauth2/token?" + query({
      client_id: env("IGDB_CLIENT_ID"),
      client_secret: env("IGDB_CLIENT_SECRET"),
      grant_type: "client_credentials",
    }),
    timeout: 15,
  });
  if (res.statusCode !== 200) throw new Error("twitch token " + res.statusCode);
  const token = { value: res.json.access_token, expires: Date.now() + (res.json.expires_in - 60) * 1000 };
  $app.store().set("igdb_token", token);
  return token.value;
}

function igdb(endpoint, body) {
  const call = (force) => $http.send({
    method: "POST",
    url: "https://api.igdb.com/v4/" + endpoint,
    headers: { "Client-ID": env("IGDB_CLIENT_ID"), Authorization: "Bearer " + igdbToken(force) },
    body,
    timeout: 20,
  });
  let res = call(false);
  if (res.statusCode === 401) res = call(true);
  return res;
}

// ── Steam Web API (key stays on the server; inputs checked) ──────────────────

function steamURL(p) {
  const value = typeof p.value === "string" ? p.value : "";
  const appId = typeof p.appId === "number" && Number.isInteger(p.appId) && p.appId > 0 ? String(p.appId) : null;
  const params = { key: env("STEAM_API_KEY"), format: "json" };
  let path;
  switch (p.method) {
    case "resolveVanity":
      if (!VANITY.test(value)) return null;
      path = "/ISteamUser/ResolveVanityURL/v1/";
      params.vanityurl = value;
      break;
    case "playerSummary": {
      const ids = value.split(",");
      if (ids.length < 1 || ids.length > 100 || !ids.every((id) => STEAM_ID.test(id))) return null;
      path = "/ISteamUser/GetPlayerSummaries/v2/";
      params.steamids = ids.join(",");
      break;
    }
    case "ownedGames":
      if (!STEAM_ID.test(value)) return null;
      path = "/IPlayerService/GetOwnedGames/v1/";
      params.steamid = value;
      params.include_appinfo = p.appInfo === false ? "0" : "1";
      params.include_played_free_games = "1";
      break;
    case "achievements":
      if (!STEAM_ID.test(value) || !appId) return null;
      path = "/ISteamUserStats/GetPlayerAchievements/v1/";
      params.steamid = value;
      params.appid = appId;
      break;
    case "schema":
      if (!appId) return null;
      path = "/ISteamUserStats/GetSchemaForGame/v2/";
      params.appid = appId;
      params.l = "french";
      break;
    case "friends":
      if (!STEAM_ID.test(value)) return null;
      path = "/ISteamUser/GetFriendList/v1/";
      params.steamid = value;
      params.relationship = "friend";
      break;
    default:
      return null;
  }
  return "https://api.steampowered.com" + path + "?" + query(params);
}

// ── Steam sign-in (OpenID 2.0) proves a player owns the Steam id on their profile ──

function sign(payload) {
  return $security.hs256(payload, env("STEAM_LINK_SECRET"));
}

// "<user id>.<expiry>.<signature>": who asked, until when, and proof it came from here.
function makeState(userId) {
  const payload = userId + "." + (Date.now() + STATE_LIFETIME_MS);
  return payload + "." + sign(payload);
}

function readState(state) {
  const parts = String(state || "").split(".");
  if (parts.length !== 3) return null;
  const [userId, expiry, signature] = parts;
  if (!/^[0-9a-f-]{36}$/.test(userId) || !(Number(expiry) > Date.now())) return null;
  return $security.equal(sign(userId + "." + expiry), signature) ? userId : null;
}

// The phone reaches the Mac by the address it used for this request.
function baseURL(e) {
  return "http://" + e.request.host;
}

function callbackURL(e, state) {
  return baseURL(e) + "/api/gameboxd/steam-link?state=" + encodeURIComponent(state);
}

function steamLoginURL(e, state) {
  return STEAM_LOGIN + "?" + query({
    "openid.ns": "http://specs.openid.net/auth/2.0",
    "openid.mode": "checkid_setup",
    "openid.return_to": callbackURL(e, state),
    "openid.realm": baseURL(e),
    "openid.identity": "http://specs.openid.net/auth/2.0/identifier_select",
    "openid.claimed_id": "http://specs.openid.net/auth/2.0/identifier_select",
  });
}

// Asks Steam whether this sign-in answer really comes from it; returns the Steam id.
function verifiedSteamId(e, params, state) {
  if (params["openid.mode"] !== "id_res") return null;
  if (params["openid.return_to"] !== callbackURL(e, state)) return null;
  if (params["openid.op_endpoint"] !== STEAM_LOGIN) return null;
  const match = String(params["openid.claimed_id"] || "").match(/^https:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/);
  if (!match) return null;
  const check = {};
  for (const key of Object.keys(params)) if (key.startsWith("openid.")) check[key] = params[key];
  check["openid.mode"] = "check_authentication";
  const res = $http.send({
    method: "POST",
    url: STEAM_LOGIN,
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: query(check),
    timeout: 15,
  });
  return res.statusCode === 200 && /^is_valid\s*:\s*true\s*$/m.test(toString(res.body)) ? match[1] : null;
}

function backToApp(e, error) {
  return e.redirect(302, error ? APP_RETURN + "?error=" + encodeURIComponent(error) : APP_RETURN);
}

// ── Library mirror ───────────────────────────────────────────────────────────

const LIBRARY_FIELDS = ["rawg_id", "title", "platform", "release_year", "cover_url", "genres", "status", "rating",
  "review", "is_spoiler", "play_minutes", "completion", "is_favorite", "completed_at"];
const LIBRARY_QUOTA = 10000;

module.exports = {
  STEAM_ID, env, isReservedName, parseQuery, igdb, steamURL, makeState, readState, steamLoginURL,
  verifiedSteamId, backToApp, LIBRARY_FIELDS, LIBRARY_QUOTA,
};
