/// <reference path="../pb_data/types.d.ts" />
// Gameboxd server logic: the routes the app calls besides the plain collection API,
// and the checks the old Postgres triggers made.

// ── Accounts ─────────────────────────────────────────────────────────────────

// Is a pseudo free? Callable before sign-up.
routerAdd("GET", "/api/gameboxd/username-available", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  const name = String(e.requestInfo().query.name || "").toLowerCase();
  if (!/^[a-z0-9_]{3,20}$/.test(name) || lib.isReservedName(name)) return e.json(200, { available: false });
  let taken = true;
  try {
    $app.findFirstRecordByFilter("users", "username = {:name}", { name });
  } catch (_) {
    taken = false;
  }
  return e.json(200, { available: !taken });
});

onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  const username = String(e.record.get("username") || "").toLowerCase();
  e.record.set("username", username);
  e.record.set("is_public", true); // new profiles are public, as before
  if (lib.isReservedName(username) || lib.isReservedName(e.record.get("display_name"))) {
    throw new BadRequestError("reserved name");
  }
  e.next();
}, "users");

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  const before = e.record.original();
  for (const field of ["username", "display_name"]) {
    const value = e.record.get(field);
    if (value !== before.get(field) && lib.isReservedName(value)) throw new BadRequestError("reserved name");
  }
  e.next();
}, "users");

// ── Flood limits: one account can't bury everyone's feed ─────────────────────

onRecordCreateRequest((e) => {
  const since = new Date(Date.now() - 3600 * 1000).toISOString().replace("T", " ");
  const recent = $app.findRecordsByFilter("activities", "user_id = {:u} && created_at > {:since}", "", 60, 0,
    { u: e.record.get("user_id"), since }).length;
  if (recent >= 60) throw new TooManyRequestsError("rate limit: too many activities");
  e.next();
}, "activities");

onRecordCreateRequest((e) => {
  const since = new Date(Date.now() - 3600 * 1000).toISOString().replace("T", " ");
  const recent = $app.findRecordsByFilter("follows", "follower_id = {:u} && created_at > {:since}", "", 100, 0,
    { u: e.record.get("follower_id"), since }).length;
  if (recent >= 100) throw new TooManyRequestsError("rate limit: too many follows");
  e.next();
}, "follows");

// ── Library mirror: upsert by game, remove, or clear, in one call ────────────
// { upsert: [library game], remove: [game id], removeAll: bool }

routerAdd("POST", "/api/gameboxd/library", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  const me = e.auth.id;
  const body = e.requestInfo().body || {};
  const upsert = Array.isArray(body.upsert) ? body.upsert : [];
  const remove = Array.isArray(body.remove) ? body.remove.map(String) : [];
  if (upsert.length > 500 || remove.length > 10000) throw new BadRequestError("too many games");

  $app.runInTransaction((tx) => {
    const find = (gameId) => {
      try {
        return tx.findFirstRecordByFilter("library_games", "user_id = {:me} && game_id = {:g}", { me, g: gameId });
      } catch (_) {
        return null;
      }
    };
    if (body.removeAll === true) {
      for (const r of tx.findRecordsByFilter("library_games", "user_id = {:me}", "", 0, 0, { me })) tx.delete(r);
    }
    for (const gameId of remove) {
      const r = find(gameId.toLowerCase());
      if (r) tx.delete(r);
    }
    const collection = tx.findCollectionByNameOrId("library_games");
    let count = tx.countRecords("library_games", $dbx.hashExp({ user_id: me }));
    for (const game of upsert) {
      const gameId = String(game.game_id || "").toLowerCase();
      let record = find(gameId);
      if (!record) {
        if (++count > lib.LIBRARY_QUOTA) throw new TooManyRequestsError("rate limit: library too large");
        record = new Record(collection);
        record.set("user_id", me);
        record.set("game_id", gameId);
      }
      for (const field of lib.LIBRARY_FIELDS) record.set(field, game[field] === undefined ? null : game[field]);
      tx.save(record);
    }
  });
  return e.noContent(204);
}, $apis.requireAuth("users"));

// ── IGDB proxy: box art and characters ───────────────────────────────────────

routerAdd("POST", "/api/gameboxd/igdb", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  if (!lib.env("IGDB_CLIENT_ID") || !lib.env("IGDB_CLIENT_SECRET")) return e.json(503, { error: "not configured" });
  const body = e.requestInfo().body || {};
  if (!["games", "characters"].includes(body.endpoint) || typeof body.query !== "string" || body.query.length > 1000) {
    return e.json(400, { error: "bad request" });
  }
  try {
    const res = lib.igdb(body.endpoint, body.query);
    if (res.statusCode === 200) return e.json(200, res.json);
    return e.json(res.statusCode === 429 ? 429 : 502, { error: "igdb" });
  } catch (_) {
    return e.json(502, { error: "upstream" });
  }
});

// ── Steam Web API proxy ──────────────────────────────────────────────────────

routerAdd("POST", "/api/gameboxd/steam", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  if (!lib.env("STEAM_API_KEY")) return e.json(503, { error: "not configured" });
  const url = lib.steamURL(e.requestInfo().body || {});
  if (!url) return e.json(400, { error: "bad request" });
  try {
    const res = $http.send({ url, timeout: 30 });
    // Keep the statuses the app tells apart (private profile, rate limit).
    if (res.statusCode === 200) return e.json(200, res.json);
    return e.json([403, 429].includes(res.statusCode) ? res.statusCode : 502, { error: "steam" });
  } catch (_) {
    return e.json(502, { error: "upstream" });
  }
});

// ── Steam sign-in: 1. the app asks for Steam's page, 2. Steam sends the browser back ──

routerAdd("POST", "/api/gameboxd/steam-link", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  if (!lib.env("STEAM_LINK_SECRET")) return e.json(503, { error: "not configured" });
  return e.json(200, { url: lib.steamLoginURL(e, lib.makeState(e.auth.id)) });
}, $apis.requireAuth("users"));

routerAdd("GET", "/api/gameboxd/steam-link", (e) => {
  const lib = require(`${__hooks}/lib.js`);
  const params = lib.parseQuery(e.request.url.rawQuery);
  const state = params.state;
  const userId = lib.readState(state);
  if (!userId) return lib.backToApp(e, "expired");
  let steamId = null;
  try {
    steamId = lib.verifiedSteamId(e, params, state);
  } catch (_) {}
  if (!steamId) return lib.backToApp(e, "not_verified");
  try {
    $app.runInTransaction((tx) => {
      // Proven ownership wins over an earlier claim on another account.
      for (const other of tx.findRecordsByFilter("users", "steam_id = {:s} && id != {:u}", "", 0, 0, { s: steamId, u: userId })) {
        other.set("steam_id", "");
        tx.save(other);
      }
      const user = tx.findRecordById("users", userId);
      user.set("steam_id", steamId);
      tx.save(user);
    });
  } catch (_) {
    return lib.backToApp(e, "save_failed");
  }
  return lib.backToApp(e);
});
