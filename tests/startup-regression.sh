#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$ROOT_DIR/setup-ubuntu-one-go.sh" "$ROOT_DIR/start.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT_DIR/start.sh" "$TMP/start.sh"
if bash "$TMP/start.sh" >"$TMP/out" 2>&1; then
  echo "Falha: start aceitou ambiente sem venv" >&2; exit 1
fi
grep -q 'setup-ubuntu-one-go.sh' "$TMP/out"
mkdir -p "$TMP/.venv/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/.venv/bin/python"
chmod +x "$TMP/.venv/bin/python"
if bash "$TMP/start.sh" >"$TMP/out" 2>&1; then
  echo "Falha: start aceitou motor ausente" >&2; exit 1
fi
grep -q 'Motor 3D ausente' "$TMP/out"
mkdir -p "$TMP/models/stable-fast-3d"
touch "$TMP/models/stable-fast-3d/run.py"
printf '#!/bin/sh\nexit 1\n' > "$TMP/.venv/bin/python"
if bash "$TMP/start.sh" >"$TMP/out" 2>&1; then
  echo "Falha: start aceitou uvicorn ausente" >&2; exit 1
fi
grep -q 'Uvicorn ausente' "$TMP/out"
echo "Regressão de pré-requisitos: OK"
