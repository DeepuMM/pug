#!/usr/bin/env bash
# Build the PUG web UI into src/magentic_ui/backend/web/ui/.
#
# On WSL the build runs in a copy on the Linux filesystem (node_modules on /mnt/c is
# extremely slow) and only the built output is synced back into the repo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PUG_FRONTEND_BUILD_DIR:-$HOME/build/pug-frontend}"
OUT="$REPO/src/magentic_ui/backend/web/ui"

mkdir -p "$BUILD_DIR"
rsync -a --delete --exclude node_modules --exclude .cache --exclude public \
  "$REPO/frontend/" "$BUILD_DIR/"

cd "$BUILD_DIR"
npx -y yarn@1.22.22 install --frozen-lockfile --network-timeout 600000
npx -y yarn@1.22.22 gatsby clean
PREFIX_PATH_VALUE='' npx -y yarn@1.22.22 gatsby build --prefix-paths

rm -rf "$OUT"
mkdir -p "$OUT"
rsync -a --delete public/ "$OUT/"
echo "Frontend built into $OUT"
