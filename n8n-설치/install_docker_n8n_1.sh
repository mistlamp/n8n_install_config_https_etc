#!/bin/bash

# --- 기본 설정 ---
N8N_DATA_PATH="/home/ubuntu/n8n"
CONTAINER_NAME="n8n-container"
IMAGE_NAME="docker.n8n.io/n8nio/n8n"
HOST_PORT="5678"

# --- [유지보수 설정] 자동 업데이트 명시 ---
# 설명: 'container-auto-updater'가 이 라벨을 감지하면,
#       새 이미지가 배포되었을 때 자동으로 이 컨테이너를 재시작하여 업데이트합니다.
#       (이 변수를 주석 처리하면 자동 업데이트 대상에서 제외됩니다.)
LABEL_ENABLE_AUTO_UPDATE="com.centurylinklabs.watchtower.enable=true"

# --- [유지보수 설정] 컨테이너 설명 ---
# 설명: 'docker inspect' 명령어로 컨테이너를 조회할 때 관리자가 볼 수 있는 설명입니다.
LABEL_DESCRIPTION="n8n 워크플로우 자동화 도구 (매일 자동 업데이트 설정됨)"

# --- 데이터 삭제 옵션 변수 ---
DELETE_DATA=${DELETE_DATA:-false}

# --- 스크립트 시작 ---
echo "=== n8n 컨테이너 설정을 시작합니다 ==="

# 1. 기존 컨테이너 중지 및 삭제
if [ $(docker ps -a -q -f name=^/${CONTAINER_NAME}$) ]; then
    echo "기존 '${CONTAINER_NAME}' 컨테이너를 중지하고 삭제합니다."
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
    echo "기존 컨테이너 삭제 완료."
    echo ""
fi

# 1-1. 최신 이미지 수동 업데이트 (스크립트 실행 시점 기준)
# 자동 업데이트 도구가 있어도, 이 스크립트를 실행할 때 즉시 최신 버전을 받기 위함입니다.
echo "Docker 이미지를 최신 버전으로 다운로드합니다: ${IMAGE_NAME}"
docker pull ${IMAGE_NAME}
echo "이미지 준비 완료."
echo ""

# 2. 데이터 삭제 확인 및 실행
if [ "${DELETE_DATA}" != "true" ]; then
    echo "🚨 경고: 기존 n8n 데이터 디렉토리(${N8N_DATA_PATH})를 삭제하시겠습니까? (y/N) [N이 기본값입니다.]"
    read -r USER_CONFIRMATION
    if [[ "$USER_CONFIRMATION" =~ ^[Yy]$ ]]; then
        DELETE_DATA="true"
    fi
fi

if [ "${DELETE_DATA}" = "true" ]; then
    echo "🚨 경고: 요청에 따라 기존 n8n 데이터를 삭제합니다. (스크립트 파일 제외)"
    SCRIPT_NAME=$(basename $0)
    find ${N8N_DATA_PATH} -mindepth 1 -not -name "$SCRIPT_NAME" -exec rm -rf {} +
    echo "기존 데이터 삭제 완료."
    echo ""
else
    echo "기존 n8n 데이터를 보존합니다."
    mkdir -p ${N8N_DATA_PATH}
    echo "데이터 디렉토리 확인 완료."
    echo ""
fi

# 3. n8n 컨테이너 실행 (라벨 포함)
echo "'${CONTAINER_NAME}' 이름으로 새 n8n 컨테이너를 시작합니다."

docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  -p ${HOST_PORT}:5678 \
  -v ${N8N_DATA_PATH}:/home/node/.n8n \
  -e TZ=Asia/Seoul \
  -e N8N_SECURE_COOKIE=false \
  -e N8N_PROTOCOL=https \
  -e N8N_HOST=n8n-cho.ddns.net \
  -e WEBHOOK_URL=https://n8n-cho.ddns.net \
  -e N8N_ENABLED_MODULES=chat-hub \
  \
  -l "$LABEL_ENABLE_AUTO_UPDATE" \
  -l description="$LABEL_DESCRIPTION" \
  \
  ${IMAGE_NAME}

echo "n8n 컨테이너 시작 완료. ${HOST_PORT} 포트를 확인하세요."

# 4. 실행 결과 확인 및 명시적 정보 출력
echo ""
echo "=== 설정 완료 ==="
echo "1. 컨테이너 상태 확인: sudo docker ps"
echo "2. 업데이트 설정 확인: sudo docker inspect ${CONTAINER_NAME} | grep description"
echo "   (설명: ${LABEL_DESCRIPTION})"
echo "3. 접속 주소: http://<서버_IP_주소>:${HOST_PORT}"
