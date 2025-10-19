#!/bin/bash
# ============================================================================
# FILE: 01_initial_setup.sh (OPTIMIZED)
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

DOCKER_WAS_INSTALLED=false
USER_NEEDS_GROUP=false

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

# Check if Docker needs to be installed
if [ "$SKIP_DOCKER_INSTALL" = "false" ]; then
    if ! command -v docker &> /dev/null; then
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
        
        DOCKER_WAS_INSTALLED=true
        echo "✅ Docker installed"
    else
        echo "✅ Docker already installed"
    fi
    
    # Check if current user needs to be added to docker group
    if ! groups "$ADMIN_USER" | grep -q docker; then
        sudo usermod -aG docker "$ADMIN_USER"
        USER_NEEDS_GROUP=true
    fi
    
    if ! groups "$DOCKER_USER" | grep -q docker; then
        sudo usermod -aG docker "$DOCKER_USER"
    fi
else
    echo "⏭️  Skipping Docker installation"
fi

sudo chown -R "${ADMIN_USER}:docker" "${INSTALL_DIR}"
sudo chmod -R 775 "${INSTALL_DIR}"

echo "✅ Initial setup completed!"
echo "📋 Log: $LOG_FILE"

# Determine if reboot is needed
NEEDS_REBOOT=false

if [ "$DOCKER_WAS_INSTALLED" = true ]; then
    echo ""
    echo "⚠️  Docker was newly installed"
    NEEDS_REBOOT=true
fi

if [ "$USER_NEEDS_GROUP" = true ]; then
    echo ""
    echo "⚠️  User $ADMIN_USER was added to docker group"
    NEEDS_REBOOT=true
fi

if [ "$NEEDS_REBOOT" = true ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     ⚠️  REBOOT REQUIRED                     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Changes require a system reboot to take effect."
    echo ""
    # Create marker file so master_setup.sh knows to continue
    touch "${INSTALL_DIR}/.reboot_required"
    exit 99  # Special exit code to signal reboot needed
else
    echo ""
    echo "✅ No reboot required, can continue immediately"
    exit 0
fi