#!/usr/bin/env bash
# Load playbooks/*.json into a running PUG as Saved Plans.
#
# Usage: scripts/load-playbooks.sh [base_url] [user_id]
#   base_url  default http://127.0.0.1:8081
#   user_id   default guestuser@gmail.com (the UI's default user)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${1:-http://127.0.0.1:8081}"
USER_ID="${2:-guestuser@gmail.com}"

existing="$(curl -sf "$BASE/api/plans/?user_id=$USER_ID")"

for f in "$REPO"/playbooks/*.json; do
  task="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["task"])' "$f")"
  if python3 -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if any(p["task"]==sys.argv[2] for p in d["data"]) else 1)' \
      "$existing" "$task"; then
    echo "skip (already saved): $(basename "$f")"
    continue
  fi
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["user_id"]=sys.argv[2]; print(json.dumps(d))' "$f" "$USER_ID" \
    | curl -sf -X POST "$BASE/api/plans/" -H "Content-Type: application/json" -d @- >/dev/null
  echo "loaded: $(basename "$f")"
done
