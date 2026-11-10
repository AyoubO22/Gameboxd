/// <reference path="../pb_data/types.d.ts" />
// Server settings that PocketBase leaves off by default, and who sees who follows whom.

const SIGNED_IN = '@request.auth.id != ""';

migrate((app) => {
  const settings = app.settings();

  // Per address: nobody on the network can try passwords without end, create accounts
  // in bulk, or burn through the IGDB and Steam keys behind the proxies (which the app
  // also uses without an account, so they can't simply require one).
  settings.rateLimits.enabled = true;
  settings.rateLimits.rules = [
    { label: "*:auth", maxRequests: 10, duration: 60 },
    { label: "users:create", maxRequests: 10, duration: 3600 },
    { label: "/api/gameboxd/username-available", maxRequests: 60, duration: 60 },
    { label: "/api/gameboxd/igdb", maxRequests: 300, duration: 60 },
    { label: "/api/gameboxd/steam", maxRequests: 300, duration: 60 },
    { label: "*:create", maxRequests: 60, duration: 10 },
    { label: "/api/", maxRequests: 600, duration: 10 },
  ];

  // A copy of the whole database every day at 13:00 (the Mac is rarely on at night),
  // the last 7 kept in pb_data/backups.
  settings.backups.cron = "0 13 * * *";
  settings.backups.cronMaxKeep = 7;
  app.save(settings);

  // A private profile's follows are seen only by the two players involved.
  const follows = app.findCollectionByNameOrId("follows");
  const visible = SIGNED_IN + " && (follower_id = @request.auth.id || followee_id = @request.auth.id"
    + " || (follower_id.is_public = true && followee_id.is_public = true))";
  follows.listRule = visible;
  follows.viewRule = visible;
  app.save(follows);
}, (app) => {
  const settings = app.settings();
  settings.rateLimits.enabled = false;
  settings.rateLimits.rules = [];
  settings.backups.cron = "";
  app.save(settings);

  const follows = app.findCollectionByNameOrId("follows");
  follows.listRule = SIGNED_IN;
  follows.viewRule = SIGNED_IN;
  app.save(follows);
});
