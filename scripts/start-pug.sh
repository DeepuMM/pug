#!/usr/bin/env bash
# Start PUG (Playbook Under Guidance).
#
# Usage: scripts/start-pug.sh [port]
#
# Environment overrides:
#   PUG_VENV      Python virtualenv location (default: ~/.venvs/pug — keep it on the
#                 Linux filesystem; a venv under /mnt/c is very slow on WSL)
#   PUG_DATA      App data dir (default: <repo>/pug-data). Must be visible to the
#                 container engine — on WSL + Podman for Windows keep it under /mnt/c.
#   PUG_CONFIG    Model config file (default: <repo>/config.yaml)
#   DOCKER_HOST   Container engine API. If unset and Docker isn't available, the script
#                 starts the Podman-for-Windows API on tcp://127.0.0.1:2375.
#   PODMAN_EXE    Path to podman.exe (default: auto-detected under the Windows user profile)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8081}"
PUG_VENV="${PUG_VENV:-$HOME/.venvs/pug}"
PUG_DATA="${PUG_DATA:-$REPO/pug-data}"
PUG_CONFIG="${PUG_CONFIG:-$REPO/config.yaml}"

if [[ ! -f "$PUG_CONFIG" ]]; then
  echo "Missing $PUG_CONFIG — copy config.example.yaml to config.yaml and fill it in." >&2
  exit 1
fi

# --- Container engine (browser + code sandboxes run as containers) -------------
if [[ -z "${DOCKER_HOST:-}" ]] && ! docker info >/dev/null 2>&1; then
  PODMAN_EXE="${PODMAN_EXE:-$(ls /mnt/c/Users/*/AppData/Local/Programs/Podman/podman.exe 2>/dev/null | head -1)}"
  if [[ -z "$PODMAN_EXE" ]]; then
    echo "No Docker daemon and no Podman for Windows found. Install one (see README)." >&2
    exit 1
  fi
  export DOCKER_HOST=tcp://127.0.0.1:2375
  if ! curl -sf -m 3 "http://127.0.0.1:2375/version" >/dev/null; then
    echo "Starting Podman API on $DOCKER_HOST ..."
    "$PODMAN_EXE" machine start >/dev/null 2>&1 || true
    "$PODMAN_EXE" machine ssh \
      "nohup podman system service --time=0 tcp://127.0.0.1:2375 >/tmp/podman-tcp.log 2>&1 &"
    for _ in $(seq 1 20); do
      curl -sf -m 2 "http://127.0.0.1:2375/version" >/dev/null && break
      sleep 1
    done
  fi
  curl -sf -m 3 "http://127.0.0.1:2375/version" >/dev/null \
    || { echo "Podman API did not come up on $DOCKER_HOST" >&2; exit 1; }
fi

# --- Python environment ---------------------------------------------------------
if [[ ! -x "$PUG_VENV/bin/pug" ]]; then
  echo "Creating Python environment in $PUG_VENV ..."
  uv venv -q --python=3.12 "$PUG_VENV"
  (cd "$REPO" && UV_PROJECT_ENVIRONMENT="$PUG_VENV" uv sync -q --extra azure)
fi

# --- Frontend build ---------------------------------------------------------------
if [[ ! -f "$REPO/src/magentic_ui/backend/web/ui/index.html" ]]; then
  echo "Frontend not built — run scripts/build-frontend.sh first." >&2
  exit 1
fi

# --- Azure sign-in ----------------------------------------------------------------
az account show >/dev/null 2>&1 || { echo "Not signed in to Azure — run: az login" >&2; exit 1; }
# Use the az CLI session directly (faster than probing every DefaultAzureCredential source).
export AZURE_TOKEN_CREDENTIALS="${AZURE_TOKEN_CREDENTIALS:-AzureCliCredential}"

mkdir -p "$PUG_DATA"
cd "$REPO"
echo "Starting PUG on http://127.0.0.1:$PORT (container engine: ${DOCKER_HOST:-docker})"
exec "$PUG_VENV/bin/pug" --port "$PORT" --config "$PUG_CONFIG" --appdir "$PUG_DATA"
