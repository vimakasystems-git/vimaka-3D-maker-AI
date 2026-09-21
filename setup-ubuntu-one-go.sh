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

log "Detectando modo de processamento"
COMPUTE_MODE="cpu"
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
  COMPUTE_MODE="cuda"
  VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')"
  echo "GPU NVIDIA detectada com $VRAM_MB MB de VRAM."
  (( VRAM_MB >= 5800 )) || echo "AVISO: menos de 6 GB de VRAM; pode ocorrer falta de memória."
else
  echo "GPU NVIDIA não encontrada. O Stable Fast 3D será instalado em modo CPU."
  echo "Intel UHD e Radeon 530 não executam CUDA; a geração será significativamente mais lenta."
fi

log "Instalando dependências do Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git python3 python3-venv python3-dev build-essential ninja-build \
  libgl1 libglib2.0-0 libegl1 libxrender1 libomp-dev curl

log "Criando ambiente Python isolado"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip wheel setuptools==69.5.1

if [[ "$COMPUTE_MODE" == "cuda" ]]; then
  log "Instalando PyTorch com CUDA"
  "$VENV/bin/pip" install --upgrade --force-reinstall \
    torch==2.4.1 torchvision==0.19.1 \
    --index-url https://download.pytorch.org/whl/cu121
  printf 'VIMAKA_COMPUTE_MODE=cuda\n' > "$APP_DIR/runtime.env"
else
  log "Instalando PyTorch para CPU"
  "$VENV/bin/pip" install --upgrade --force-reinstall \
    torch==2.4.1 torchvision==0.19.1 \
    --index-url https://download.pytorch.org/whl/cpu
  printf 'VIMAKA_COMPUTE_MODE=cpu\nSF3D_USE_CPU=1\n' > "$APP_DIR/runtime.env"
fi

log "Baixando o motor Stable Fast 3D"
mkdir -p "$APP_DIR/models"
if [[ -d "$MODEL_DIR/.git" ]] && \
   { [[ ! -f "$MODEL_DIR/texture_baker/setup.py" ]] || [[ ! -f "$MODEL_DIR/uv_unwrapper/setup.py" ]]; }; then
  BROKEN_BACKUP="$APP_DIR/models/stable-fast-3d.incomplete.$(date +%Y%m%d-%H%M%S)"
  echo "Clone incompleto detectado. Movendo para: $BROKEN_BACKUP"
  mv "$MODEL_DIR" "$BROKEN_BACKUP"
fi
if [[ -d "$MODEL_DIR/.git" ]]; then
  git -C "$MODEL_DIR" pull --ff-only
else
  git clone --depth 1 https://github.com/Stability-AI/stable-fast-3d.git "$MODEL_DIR"
fi

[[ -f "$MODEL_DIR/texture_baker/setup.py" ]] || die "O clone não contém texture_baker/setup.py."
[[ -f "$MODEL_DIR/uv_unwrapper/setup.py" ]] || die "O clone não contém uv_unwrapper/setup.py."

log "Instalando o motor e a API"
(
  cd "$MODEL_DIR"
  "$VENV/bin/pip" install -r requirements.txt
)
"$VENV/bin/pip" install -r "$APP_DIR/server/requirements.txt"

log "Autorizando download do modelo"
if [[ -n "${HF_TOKEN:-}" ]]; then
  "$VENV/bin/huggingface-cli" login --token "$HF_TOKEN" --add-to-git-credential false
else
  echo "O token não será salvo no projeto nem enviado ao GitHub."
  "$VENV/bin/huggingface-cli" login
fi

log "Validando o ambiente"
if [[ "$COMPUTE_MODE" == "cuda" ]]; then
  "$VENV/bin/python" -c 'import torch; assert torch.cuda.is_available(), "CUDA não disponível no PyTorch"; print("CUDA OK:", torch.cuda.get_device_name(0))'
else
  "$VENV/bin/python" -c 'import torch; print("PyTorch CPU OK:", torch.__version__)'
fi

chmod +x "$APP_DIR/start.sh"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
echo
echo "Ambiente pronto."
echo "Modo de processamento: $COMPUTE_MODE"
echo "Inicie com: ./start.sh"
echo "Nesta máquina: http://localhost:$PORT"
echo "Na rede local: http://$LOCAL_IP:$PORT"
