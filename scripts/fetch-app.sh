#!/usr/bin/env bash
# Check out the PDF chatbot at the exact commit pinned in app.env.
#
#   scripts/fetch-app.sh [dir]     # default dir: app-src
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=app.env
source app.env

dest="${1:-app-src}"
url="https://github.com/${APP_REPOSITORY}.git"

if [ ! -d "$dest/.git" ]; then
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
fi

git -C "$dest" fetch -q --depth 1 origin "$APP_COMMIT"
git -C "$dest" -c advice.detachedHead=false checkout -q --force FETCH_HEAD

actual="$(git -C "$dest" rev-parse HEAD)"
if [ "$actual" != "$APP_COMMIT" ]; then
  echo "expected $APP_COMMIT, got $actual" >&2
  exit 1
fi
echo "$APP_REPOSITORY at $APP_COMMIT in $dest/"
