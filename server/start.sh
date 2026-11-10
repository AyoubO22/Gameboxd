#!/bin/sh
# Starts the Gameboxd server (PocketBase) on this Mac, reachable from the iPhone on the
# same Wi-Fi at http://<mac name>.local:8090. Secrets come from server/.env (gitignored).
cd "$(dirname "$0")"
set -a; [ -f .env ] && . ./.env; set +a
exec ./pocketbase serve --http 0.0.0.0:8090
