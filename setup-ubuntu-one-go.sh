#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
VENV="$APP_DIR/.venv"
MODEL_DIR="$APP_DIR/models/stable-fast-3d"
PORT="${VIMAKA_PORT:-7860}"

die(){ echo "ERRO: $*" >&2; exit 1; }
log(){ echo; echo "==> $*"; }

[[ "$(uname -s)" == "Linux" ]] || die "Este instalador requer Linux."
[[ -f /etc/os-release ]] || die "Não foi possível identificar a distribuição."
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Distribuição detectada: ${PRETTY_NAME:-desconhecida}. Use Ubuntu 22.04/24.04."
[[ "$(uname -m)" == "x86_64" ]] || die "Arquitetura suportada nesta versão: x86_64."

log "Verificando GPU NVIDIA"
command -v nvidia-smi >/dev/null || die "Instale o driver NVIDIA recomendado, reinicie e execute novamente."
nvidia-smi >/dev/null || die "O driver NVIDIA existe, mas a GPU não respondeu."
VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')"
echo "VRAM detectada: $VRAM_MB MB"
(( VRAM_MB >= 5800 )) || echo "AVISO: menos de 6 GB de VRAM; pode ocorrer falta de memória."

log "Instalando dependências do Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git python3 python3-venv python3-dev build-essential ninja-build \
  libgl1 libglib2.0-0 libegl1 libxrender1 curl

log "Criando ambiente Python isolado"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip wheel setuptools==69.5.1

log "Instalando PyTorch com CUDA"
"$VENV/bin/pip" install torch torchvision --index-url https://download.pytorch.org/whl/cu121

log "Baixando o motor Stable Fast 3D"
mkdir -p "$APP_DIR/models"
if [[ ! -d "$MODEL_DIR/.git" ]]; then
  git clone --depth 1 https://github.com/Stability-AI/stable-fast-3d.git "$MODEL_DIR"
else
  git -C "$MODEL_DIR" pull --ff-only
fi

log "Instalando o motor e a API"
"$VENV/bin/pip" install -r "$MODEL_DIR/requirements.txt"
"$VENV/bin/pip" install -r "$APP_DIR/server/requirements.txt"

log "Autorizando download do modelo"
if [[ -n "${HF_TOKEN:-}" ]]; then
  "$VENV/bin/huggingface-cli" login --token "$HF_TOKEN" --add-to-git-credential false
else
  echo "O token não será salvo no projeto nem enviado ao GitHub."
  "$VENV/bin/huggingface-cli" login
fi

log "Validando CUDA"
"$VENV/bin/python" -c 'import torch; assert torch.cuda.is_available(), "CUDA não disponível no PyTorch"; print("CUDA OK:", torch.cuda.get_device_name(0))'

chmod +x "$APP_DIR/start.sh"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
echo
echo "Ambiente pronto."
echo "Inicie com: ./start.sh"
echo "Nesta máquina: http://localhost:$PORT"
echo "Na rede local: http://$LOCAL_IP:$PORT"
