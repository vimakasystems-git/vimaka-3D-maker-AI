#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
if [ ! -x "$ROOT_DIR/.venv/bin/python" ]; then echo "Execute ./install.sh primeiro."; exit 1; fi
if [ -f "$ROOT_DIR/runtime.env" ]; then
  set -a
  source "$ROOT_DIR/runtime.env"
  set +a
fi
cd "$ROOT_DIR"
exec "$ROOT_DIR/.venv/bin/uvicorn" server.app:app --host 0.0.0.0 --port 7860
