#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --name <node_name>     설정할 노드 이름"
    echo "  --mnemonic <mnemonic>  설정할 니모닉"
    echo "  --api-key <api_key>    설정할 CGC API 키"
    echo "  --help                 이 도움말 메시지 표시"
    echo
    echo "Example:"
    echo "  $0 --name my-node --mnemonic 'my seed phrase' --api-key abc123"
}

# 매개변수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NODE_NAME="$2"
            shift 2
            ;;
        --mnemonic)
            MNEMONIC="$2"
            shift 2
            ;;
        --api-key)
            CGC_API_KEY="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ ! -f config.json ]; then
    echo "Error: config.json 파일을 찾을 수 없습니다."
    exit 1
fi

# worker-data 디렉토리 생성
mkdir -p ./worker-data

# 제공된 값으로 파일 업데이트
if [ ! -z "$NODE_NAME" ]; then
    sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"$NODE_NAME\"/" config.json
    echo "노드 이름이 '$NODE_NAME'으로 업데이트되었습니다."
fi

if [ ! -z "$MNEMONIC" ]; then
    sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$MNEMONIC\"/" config.json
    echo "니모닉이 업데이트되었습니다."
fi

if [ ! -z "$CGC_API_KEY" ]; then
    sed -i "s/CGC_API_KEY=.*/CGC_API_KEY=$CGC_API_KEY/" docker-compose.yaml
    sed -i "s/ALLORA_CGI_API=.*/ALLORA_CGI_API=$CGC_API_KEY/" docker-compose.yaml
    echo "CGC API 키가 업데이트되었습니다."
fi

nodeName=$(jq -r '.wallet.addressKeyName' config.json)
if [ -z "$nodeName" ]; then
    echo "노드의 지갑 이름이 제공되지 않았습니다. config.json >> wallet.addressKeyName에서 원하는 지갑 이름을 제공해주세요."
    exit 1
fi

json_content=$(cat ./config.json)
stringified_json=$(echo "$json_content" | jq -c .)

mnemonic=$(jq -r '.wallet.addressRestoreMnemonic' config.json)
if [ -n "$mnemonic" ]; then
    echo "ALLORA_OFFCHAIN_NODE_CONFIG_JSON='$stringified_json'" > ./worker-data/env_file
    echo "NAME=$nodeName" >> ./worker-data/env_file
    echo "ENV_LOADED=true" >> ./worker-data/env_file
    echo "지갑 니모닉이 이미 제공되었습니다. config.json을 로딩합니다. docker compose를 실행해주세요."
    exit 0
fi

if [ ! -f ./worker-data/env_file ]; then
    echo "ENV_LOADED=false" > ./worker-data/env_file
fi

ENV_LOADED=$(grep '^ENV_LOADED=' ./worker-data/env_file | cut -d '=' -f 2)
if [ "$ENV_LOADED" = "false" ]; then
    json_content=$(cat ./config.json)
    stringified_json=$(echo "$json_content" | jq -c .)
    docker run -it --entrypoint=bash -v $(pwd)/worker-data:/data -v $(pwd)/scripts:/scripts -e NAME="${nodeName}" -e ALLORA_OFFCHAIN_NODE_CONFIG_JSON="${stringified_json}" alloranetwork/allora-chain:latest -c "bash /scripts/init.sh"
    echo "config.json가 ./worker-data/env_file에 저장되었습니다."
else
    echo "config.json이 이미 로드되었습니다. config.json을 다시 로드하려면 ./worker-data/env_file의 ENV_LOADED 변수를 false로 설정하세요."
fi 