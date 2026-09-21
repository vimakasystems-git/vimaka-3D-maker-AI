# Vimaka Mesh Studio Local

Gerador real de modelo 3D em GLB a partir de uma imagem, usando Stable Fast 3D.

## Requisitos

- Ubuntu 22.04 ou 24.04
- GPU NVIDIA com aproximadamente 6 GB de VRAM, ou modo CPU
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
instala PyTorch com CUDA quando existe uma GPU NVIDIA compatível e seleciona
automaticamente o modo CPU quando só existem Intel/AMD incompatíveis. Depois,
baixa o Stable Fast 3D e autentica no Hugging Face.

No Dell Inspiron 5570 com Intel UHD 620 e Radeon 530, o modo selecionado será
CPU. Ele funciona, mas a geração pode levar vários minutos ou mais.

O primeiro uso baixa os pesos. A fila executa uma geração por vez para
evitar falta de memória. Comece com textura 1024 e remesh none.
Não exponha esta versão diretamente à internet: ela não inclui autenticação.
