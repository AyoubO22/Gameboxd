#!/bin/bash
# Starts a throwaway server (own data folder, port 8097) with this folder's migrations and
# hooks, and checks the rules the app relies on. Needs curl and jq. Run by CI on every
# pull request; locally: ./smoke-test.sh (uses ./pocketbase, or PB=/path/to/pocketbase).
set -euo pipefail
cd "$(dirname "$0")"

PB=${PB:-./pocketbase}
URL=http://127.0.0.1:8097
DATA=$(mktemp -d)
"$PB" superuser upsert admin@example.com admin-password-1234 --dir "$DATA" --migrationsDir pb_migrations >/dev/null
"$PB" serve --dir "$DATA" --hooksDir pb_hooks --migrationsDir pb_migrations --http 127.0.0.1:8097 >"$DATA/log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$DATA"' EXIT
for _ in $(seq 50); do curl -sf "$URL/api/health" >/dev/null && break; sleep 0.2; done

FAILED=0
STATUS=""
BODY=""
# call METHOD PATH [TOKEN] [JSON]: sets STATUS and BODY.
call() {
  local args=(-s -o "$DATA/body" -w "%{http_code}" -X "$1" "$URL$2")
  [ -n "${3:-}" ] && args+=(-H "Authorization: $3")
  [ -n "${4:-}" ] && args+=(-H "Content-Type: application/json" -d "$4")
  STATUS=$(curl "${args[@]}")
  BODY=$(cat "$DATA/body")
}
# check LABEL ACTUAL EXPECTED
check() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', expected '$3' ($BODY)"; FAILED=1; fi
}
signup() {
  call POST /api/collections/users/records "" "{\"email\":\"$1@example.com\",\"password\":\"password-$1\",\"passwordConfirm\":\"password-$1\",\"username\":\"$1\"}"
  check "sign up $1" "$STATUS" 200
  call POST /api/collections/users/auth-with-password "" "{\"identity\":\"$1@example.com\",\"password\":\"password-$1\"}"
  check "sign in $1" "$STATUS" 200
}

call GET "/api/gameboxd/username-available?name=alice"
check "free pseudo is available" "$(jq -r .available <<<"$BODY")" true
call GET "/api/gameboxd/username-available?name=admin"
check "reserved pseudo is not" "$(jq -r .available <<<"$BODY")" false

signup alice; ALICE=$(jq -r .token <<<"$BODY"); ALICE_ID=$(jq -r .record.id <<<"$BODY")
signup bob;   BOB=$(jq -r .token <<<"$BODY");   BOB_ID=$(jq -r .record.id <<<"$BODY")
signup carol; CAROL=$(jq -r .token <<<"$BODY")
call POST /api/collections/_superusers/auth-with-password "" '{"identity":"admin@example.com","password":"admin-password-1234"}'
ADMIN=$(jq -r .token <<<"$BODY")

call GET "/api/gameboxd/username-available?name=alice"
check "taken pseudo is not available" "$(jq -r .available <<<"$BODY")" false

# Only the Steam sign-in route writes a Steam id.
STEAM=76561198000000001
call PATCH "/api/collections/users/records/$ALICE_ID" "$ALICE" "{\"steam_id\":\"$STEAM\"}"
check "a player can't claim a Steam id" "$([ "$STATUS" -ge 400 ] && echo refused)" refused
call PATCH "/api/collections/users/records/$ALICE_ID" "$ADMIN" "{\"steam_id\":\"$STEAM\"}"
check "(setup) Steam id set by the server" "$STATUS" 200

# Library mirror.
GAME=11111111-2222-4333-8444-555555555555
call POST /api/gameboxd/library "" '{"upsert":[]}'
check "library needs an account" "$STATUS" 401
call POST /api/gameboxd/library "$ALICE" "{\"upsert\":[{\"game_id\":\"$GAME\",\"title\":\"Celeste\",\"status\":\"completed\",\"rating\":5,\"genres\":[\"Platformer\"]}]}"
check "library upsert" "$STATUS" 204
call POST /api/gameboxd/library "$ALICE" "{\"upsert\":[{\"game_id\":\"$GAME\",\"title\":\"Celeste\",\"status\":\"platinum\",\"rating\":5,\"genres\":[]}]}"
check "library upsert again (same game)" "$STATUS" 204
call GET "/api/collections/library_games/records" "$BOB"
check "a public collection is visible, one row per game" "$(jq -r '.items | map(.status) | join(",")' <<<"$BODY")" platinum
call GET "/api/collections/users/records/$ALICE_ID" "$BOB"
check "a public profile shows its Steam id" "$(jq -r .steam_id <<<"$BODY")" "$STEAM"

# Private profile: collection, Steam id and follows are hidden from others.
call POST /api/collections/follows/records "$BOB" "{\"follower_id\":\"$BOB_ID\",\"followee_id\":\"$ALICE_ID\"}"
check "follow" "$STATUS" 200
call POST /api/collections/follows/records "$BOB" "{\"follower_id\":\"$ALICE_ID\",\"followee_id\":\"$BOB_ID\"}"
check "can't follow in someone else's name" "$([ "$STATUS" -ge 400 ] && echo refused)" refused
call GET /api/collections/follows/records "$CAROL"
check "follows between public profiles are visible" "$(jq -r '.items | length' <<<"$BODY")" 1
call PATCH "/api/collections/users/records/$ALICE_ID" "$ALICE" '{"is_public":false}'
check "profile made private" "$STATUS" 200
call GET "/api/collections/library_games/records" "$BOB"
check "a private collection is hidden" "$(jq -r '.items | length' <<<"$BODY")" 0
call GET "/api/collections/library_games/records" "$ALICE"
check "its owner still sees it" "$(jq -r '.items | length' <<<"$BODY")" 1
call GET "/api/collections/users/records/$ALICE_ID" "$BOB"
check "a private profile is still found" "$(jq -r .username <<<"$BODY")" alice
check "a private profile hides its Steam id" "$(jq -r '.steam_id // ""' <<<"$BODY")" ""
call GET "/api/collections/users/records/$ALICE_ID" "$ALICE"
check "its owner still sees the Steam id" "$(jq -r .steam_id <<<"$BODY")" "$STEAM"
call GET /api/collections/follows/records "$CAROL"
check "a private profile's follows are hidden from others" "$(jq -r '.items | length' <<<"$BODY")" 0
call GET /api/collections/follows/records "$BOB"
check "but not from the follower" "$(jq -r '.items | length' <<<"$BODY")" 1

call POST /api/gameboxd/library "$ALICE" '{"removeAll":true}'
check "library removeAll" "$STATUS" 204
call GET "/api/collections/library_games/records" "$ALICE"
check "the online copy is empty" "$(jq -r '.items | length' <<<"$BODY")" 0

# Without keys or a mail server, the app is told so.
call POST /api/gameboxd/igdb "" '{"endpoint":"games","query":"fields name;"}'
check "IGDB proxy without keys" "$STATUS" 503
call GET /api/gameboxd/mail-enabled
check "no mail server" "$(jq -r .enabled <<<"$BODY")" false

# Passwords can't be tried without end.
for _ in $(seq 15); do
  call POST /api/collections/users/auth-with-password "" '{"identity":"alice@example.com","password":"wrong-password"}'
done
check "sign-in attempts are limited" "$STATUS" 429

[ "$FAILED" = 0 ] && echo "All server checks passed." || { echo "--- server log ---"; tail -40 "$DATA/log"; exit 1; }
