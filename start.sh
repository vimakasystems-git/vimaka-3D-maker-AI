#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
if [ ! -x "$ROOT_DIR/.venv/bin/python" ]; then echo "Execute ./setup-ubuntu-one-go.sh primeiro." >&2; exit 1; fi
if [ ! -f "$ROOT_DIR/models/stable-fast-3d/run.py" ]; then echo "Motor 3D ausente. Execute ./setup-ubuntu-one-go.sh." >&2; exit 1; fi
if ! "$ROOT_DIR/.venv/bin/python" -m uvicorn --version >/dev/null 2>&1; then echo "Uvicorn ausente. Execute ./setup-ubuntu-one-go.sh novamente." >&2; exit 1; fi
if [ -f "$ROOT_DIR/runtime.env" ]; then
  set -a
  source "$ROOT_DIR/runtime.env"
  set +a
fi
cd "$ROOT_DIR"
exec "$ROOT_DIR/.venv/bin/python" -m uvicorn server.app:app --host "${VIMAKA_HOST:-127.0.0.1}" --port "${VIMAKA_PORT:-7860}"
