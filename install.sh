#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
exec "$ROOT_DIR/setup-ubuntu-one-go.sh"
