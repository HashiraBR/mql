#!/bin/bash

# Define diretórios e URLs
BASE_DIR="$HOME/Downloads/EAS"
BASE_URL="https://raw.githubusercontent.com/HashiraBR/mql/main/MyExperts"
BASE_URL_CONFIGS="https://raw.githubusercontent.com/HashiraBR/mql/main/Analysis"
LAST_CONFIG="out24-mar25"

# Cria o diretório MyExperts, se não existir
mkdir -p "$BASE_DIR"

# Define um array com os nomes dos EAs
EAs=("CandleWaveEA" "PullbackMaster" "PrismEA" "TrendPulseEA")

# Função para baixar e organizar arquivos
download_and_organize() {
    local EA_NAME="$1"
    local EA_FILE_URL="$BASE_URL/$EA_NAME/$EA_NAME.ex5"
    local EA_CONFIG_URL="$BASE_URL_CONFIGS/$EA_NAME/$LAST_CONFIG/Configs/${EA_NAME}_${LAST_CONFIG}.set"
    local EA_DIR="$BASE_DIR/$EA_NAME"

    # Cria o diretório do EA, se não existir
    mkdir -p "$EA_DIR"

    # Baixa o arquivo EA
    wget -q "$EA_FILE_URL" -O "$EA_DIR/$EA_NAME.ex5"

    # Baixa o arquivo de configuração do EA
    wget -q "$EA_CONFIG_URL" -O "$EA_DIR/${EA_NAME}_Config.set"
}

# Percorre o array e baixa os arquivos
for EA in "${EAs[@]}"; do
    download_and_organize "$EA"
done

echo "Download concluído!"
