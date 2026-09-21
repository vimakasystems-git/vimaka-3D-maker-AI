# Vimaka Mesh Studio Local

Gerador real de modelo 3D em GLB a partir de uma imagem, usando Stable Fast 3D.

## Requisitos

- Ubuntu 22.04 ou 24.04
- GPU NVIDIA com aproximadamente 6 GB de VRAM disponível
- 16 GB de RAM e 25 GB livres recomendados
- Driver NVIDIA funcional
- Conta Hugging Face com acesso a stabilityai/stable-fast-3d

## Instalação

    chmod +x setup-ubuntu-one-go.sh start.sh
    ./setup-ubuntu-one-go.sh
    ./start.sh

Abra http://localhost:7860. Em outro computador da mesma rede, use
http://IP-DO-SERVIDOR:7860. Libere a porta 7860 somente na rede local.

O instalador detecta Ubuntu, arquitetura, GPU e VRAM; cria o ambiente Python;
instala PyTorch/CUDA; baixa o Stable Fast 3D; autentica no Hugging Face e valida
o acesso CUDA. O primeiro uso baixa os pesos. A fila executa uma geração por vez para
evitar falta de memória. Comece com textura 1024 e remesh none.
Não exponha esta versão diretamente à internet: ela não inclui autenticação.
