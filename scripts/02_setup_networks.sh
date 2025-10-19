# ============================================================================
# FILE: 02_setup_networks.sh
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
LOG_FILE="${LOG_DIR}/02_networks_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "02 - Docker Network Setup"
echo "=========================================="

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker not running or user not in docker group"
    exit 1
fi

echo "Cleaning up existing networks..."
for net in ${DOCKER_NETWORK_OXIDIZED} ${DOCKER_NETWORK_GITLAB} ${DOCKER_NETWORK_NGINX}; do
    docker network inspect "$net" >/dev/null 2>&1 && docker network rm "$net" || true
done

echo "Creating Docker networks..."

if [ "${INSTALL_OXIDIZED}" = "true" ]; then
    docker network create --driver bridge \
        --subnet="${OXINET_SUBNET}" --gateway="${OXINET_GATEWAY}" \
        --opt com.docker.network.bridge.name="${DOCKER_BRIDGE_OXIDIZED}" ${DOCKER_NETWORK_OXIDIZED}
    echo "✅ Oxidized network created"
fi

if [ "${INSTALL_GITLAB}" = "true" ]; then
    docker network create --driver bridge \
        --subnet="${GITLABNET_SUBNET}" --gateway="${GITLABNET_GATEWAY}" \
        --opt com.docker.network.bridge.name="${DOCKER_BRIDGE_GITLAB}" ${DOCKER_NETWORK_GITLAB}
    echo "✅ GitLab network created"
fi

docker network create --driver bridge \
    --subnet="${NGINXNET_SUBNET}" --gateway="${NGINXNET_GATEWAY}" \
    --opt com.docker.network.bridge.name="${DOCKER_BRIDGE_NGINX}" ${DOCKER_NETWORK_NGINX}
echo "✅ Nginx network created"

echo "✅ Networks created successfully"
docker network ls | grep -E "NETWORK|oxinet|gitlabnet|nginxnet"
echo "📋 Log: $LOG_FILE"