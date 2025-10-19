# ============================================================================
# FILE: 01_initial_setup.sh
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
LOG_FILE="${LOG_DIR}/01_initial_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "01 - Initial System Setup"
echo "=========================================="

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing base dependencies..."
sudo apt install -y ${BASE_PACKAGES} ${ADDITIONAL_PACKAGES}

echo "Creating Docker user..."
if ! id "$DOCKER_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$DOCKER_USER"
    echo "$DOCKER_USER:$DOCKER_USER_PASSWORD" | sudo chpasswd
    echo "✅ Created $DOCKER_USER"
else
    echo "✅ $DOCKER_USER already exists"
fi
sudo usermod -aG sudo "$DOCKER_USER"

if [ "$SKIP_DOCKER_INSTALL" = "false" ]; then
    echo "Installing Docker..."
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL "${DOCKER_GPG_URL}" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO_URL} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    sudo apt update
    sudo apt install -y ${DOCKER_PACKAGES}
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$DOCKER_USER"
    sudo usermod -aG docker "$ADMIN_USER"
    echo "✅ Docker installed"
    echo ""
    echo "⚠️  IMPORTANT: REBOOT REQUIRED!"
    echo "   Run: sudo reboot"
else
    echo "⏭️  Skipping Docker installation"
fi

sudo chown -R "${ADMIN_USER}:docker" "${INSTALL_DIR}"
sudo chmod -R 775 "${INSTALL_DIR}"

echo "✅ Initial setup completed!"
echo "📋 Log: $LOG_FILE"