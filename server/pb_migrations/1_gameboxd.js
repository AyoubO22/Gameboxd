/// <reference path="../pb_data/types.d.ts" />
// Gameboxd schema: player profiles (on the `users` auth collection), follows, activity,
// and the public mirror of each collection. Rules mirror the old Postgres policies.

const UUID = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$";
const UUID_GEN = "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
// Pictures other phones load: only from the game databases the app uses (RemoteImage.isAllowed).
const IMAGE = "^https://([a-z0-9-]+\\.)*(rawg\\.io|igdb\\.com|steamstatic\\.com|steampowered\\.com|playstation\\.com|playstation\\.net)/";
const SIGNED_IN = '@request.auth.id != ""';
const VISIBLE = SIGNED_IN + " && (user_id = @request.auth.id || user_id.is_public = true)";

// The app's ids are UUIDs.
function uuidIds(collection) {
  const id = collection.fields.getByName("id");
  id.pattern = UUID;
  id.autogeneratePattern = UUID_GEN;
  id.min = 36;
  id.max = 36;
}

// Fields are added one by one: rules are checked against them when the collection is saved.
function base(spec) {
  const collection = new Collection({ type: "base", name: spec.name });
  for (const field of spec.fields) collection.fields.add(field);
  collection.indexes = spec.indexes;
  for (const rule of ["listRule", "viewRule", "createRule", "updateRule", "deleteRule"]) {
    collection[rule] = spec[rule] === undefined ? null : spec[rule];
  }
  return collection;
}

function owner(name, users) {
  return new RelationField({ name, required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true });
}

migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  uuidIds(users);
  users.fields.add(new TextField({ name: "username", required: true, pattern: "^[a-z0-9_]{3,20}$" }));
  users.fields.add(new TextField({ name: "display_name", max: 40 }));
  users.fields.add(new TextField({ name: "bio", max: 160 }));
  users.fields.add(new TextField({ name: "avatar_url", max: 2048, pattern: IMAGE }));
  users.fields.add(new BoolField({ name: "is_public" }));
  users.fields.add(new TextField({ name: "steam_id", pattern: "^[0-9]{17}$" }));
  users.indexes.push("CREATE UNIQUE INDEX idx_users_username ON users (username)");
  users.indexes.push("CREATE UNIQUE INDEX idx_users_steam_id ON users (steam_id) WHERE steam_id != ''");
  users.listRule = SIGNED_IN;
  users.viewRule = SIGNED_IN;
  users.createRule = '@request.body.steam_id:isset = false';
  // Only the steam-link route sets steam_id (after Steam sign-in); players can only clear it.
  users.updateRule = 'id = @request.auth.id && (@request.body.steam_id:isset = false || @request.body.steam_id = "")';
  users.deleteRule = "id = @request.auth.id";
  app.save(users);

  const follows = base({
    name: "follows",
    listRule: SIGNED_IN,
    viewRule: SIGNED_IN,
    createRule: SIGNED_IN + " && follower_id = @request.auth.id && followee_id != @request.auth.id",
    deleteRule: "follower_id = @request.auth.id",
    fields: [
      owner("follower_id", users),
      owner("followee_id", users),
      new AutodateField({ name: "created_at", onCreate: true }),
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_follows_pair ON follows (follower_id, followee_id)",
      "CREATE INDEX idx_follows_followee ON follows (followee_id)",
    ],
  });
  app.save(follows);

  const activities = base({
    name: "activities",
    listRule: VISIBLE,
    viewRule: VISIBLE,
    createRule: "user_id = @request.auth.id",
    deleteRule: "user_id = @request.auth.id",
    fields: [
      owner("user_id", users),
      new SelectField({ name: "kind", required: true, maxSelect: 1, values: ["played", "completed", "platinum", "rated", "reviewed", "added"] }),
      new TextField({ name: "game_title", required: true, max: 200 }),
      new TextField({ name: "game_cover_url", max: 2048, pattern: IMAGE }),
      new NumberField({ name: "rating", min: 1, max: 5, onlyInt: true }),
      new TextField({ name: "review", max: 2000 }),
      new NumberField({ name: "minutes", min: 0, onlyInt: true }),
      new AutodateField({ name: "created_at", onCreate: true }),
    ],
    indexes: ["CREATE INDEX idx_activities_user_time ON activities (user_id, created_at)"],
  });
  uuidIds(activities);
  app.save(activities);

  // Written only through POST /api/gameboxd/library (pb_hooks), which upserts by game.
  const library = base({
    name: "library_games",
    listRule: VISIBLE,
    viewRule: VISIBLE,
    fields: [
      owner("user_id", users),
      new TextField({ name: "game_id", required: true, pattern: UUID }),
      new NumberField({ name: "rawg_id", onlyInt: true }),
      new TextField({ name: "title", required: true, max: 200 }),
      new TextField({ name: "platform", max: 60 }),
      new TextField({ name: "release_year", max: 10 }),
      new TextField({ name: "cover_url", max: 2048, pattern: IMAGE }),
      new JSONField({ name: "genres", maxSize: 2000 }),
      new SelectField({ name: "status", required: true, maxSelect: 1, values: ["none", "wantToPlay", "playing", "completed", "shelved", "platinum"] }),
      new NumberField({ name: "rating", min: 0, max: 5, onlyInt: true }),
      new TextField({ name: "review", max: 10000 }),
      new BoolField({ name: "is_spoiler" }),
      new NumberField({ name: "play_minutes", min: 0, onlyInt: true }),
      new NumberField({ name: "completion", min: 0, max: 100, onlyInt: true }),
      new BoolField({ name: "is_favorite" }),
      new DateField({ name: "completed_at" }),
      new AutodateField({ name: "updated_at", onCreate: true, onUpdate: true }),
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_library_user_game ON library_games (user_id, game_id)",
      "CREATE INDEX idx_library_user_status ON library_games (user_id, status)",
    ],
  });
  app.save(library);
}, (app) => {
  for (const name of ["library_games", "activities", "follows"]) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
