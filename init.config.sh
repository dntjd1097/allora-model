#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 [--i] <node_name> <mnemonic> <cgc_api_key>"
    echo
    echo "Options:"
    echo "  --i          Skip the argument check and use default values"
    echo "  --help       Show this help message and exit"
    echo
    echo "Arguments:"
    echo "  <node_name>      Node name for config.json"
    echo "  <mnemonic>       Mnemonic phrase for config.json"
    echo "  <cgc_api_key>    CoinGecko API key"
}

# Help 메시지 체크
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ ! -f config.json ]; then
    echo "Error: config.json file not found"
    exit 1
fi

# worker-data 디렉토리 생성
mkdir -p ./worker-data

# 인자 체크 및 설정
if [[ "$1" == "--i" ]]; then
    shift
    # --i 옵션이어도 인자가 있다면 업데이트
    if [ $# -eq 3 ]; then
        sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"$1\"/" config.json
        sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$2\"/" config.json
        sed -i "s/CGC_API_KEY=.*/CGC_API_KEY=$3/" docker-compose.yaml
    fi
else
    if [ $# -ne 3 ]; then
        show_help
        exit 1
    fi

    # config.json 업데이트
    sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"$1\"/" config.json
    sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$2\"/" config.json
    
    # docker-compose.yaml 업데이트
    sed -i "s/CGC_API_KEY=.*/CGC_API_KEY=$3/" docker-compose.yaml
fi

nodeName=$(jq -r '.wallet.addressKeyName' config.json)
if [ -z "$nodeName" ]; then
    echo "No wallet name provided for the node, please provide your preferred wallet name. config.json >> wallet.addressKeyName"
    exit 1
fi

json_content=$(cat ./config.json)
stringified_json=$(echo "$json_content" | jq -c .)

mnemonic=$(jq -r '.wallet.addressRestoreMnemonic' config.json)
if [ -n "$mnemonic" ]; then
    echo "ALLORA_OFFCHAIN_NODE_CONFIG_JSON='$stringified_json'" > ./worker-data/env_file
    echo "NAME=$nodeName" >> ./worker-data/env_file
    echo "ENV_LOADED=true" >> ./worker-data/env_file
    echo "wallet mnemonic already provided by you, loading config.json . Please proceed to run docker compose"
    exit 1
fi

if [ ! -f ./worker-data/env_file ]; then
    echo "ENV_LOADED=false" > ./worker-data/env_file
fi

ENV_LOADED=$(grep '^ENV_LOADED=' ./worker-data/env_file | cut -d '=' -f 2)
if [ "$ENV_LOADED" = "false" ]; then
    json_content=$(cat ./config.json)
    stringified_json=$(echo "$json_content" | jq -c .)
    docker run -it --entrypoint=bash -v $(pwd)/worker-data:/data -v $(pwd)/scripts:/scripts -e NAME="${nodeName}" -e ALLORA_OFFCHAIN_NODE_CONFIG_JSON="${stringified_json}" alloranetwork/allora-chain:latest -c "bash /scripts/init.sh"
    echo "config.json saved to ./worker-data/env_file"
else
    echo "config.json is already loaded, skipping the operation. You can set ENV_LOADED variable to false in ./worker-data/env_file to reload the config.json"
fi 