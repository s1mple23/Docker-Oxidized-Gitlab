#!/bin/bash
# 06_setup_ssh_and_gitlab.sh - GitLab SSH Integration (NO TOKEN)
# Pure SSH with Deploy Key authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# Expand variables
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
GITLAB_PROJECT_PATH=$(eval echo "${GITLAB_PROJECT_PATH}")
OXIDIZED_GIT_EMAIL=$(eval echo "${OXIDIZED_GIT_EMAIL}")

LOG_FILE="${LOG_DIR}/06_ssh_gitlab_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "06 - GitLab SSH Integration (Deploy Key)"
echo "=========================================="

cd "${INSTALL_DIR}"

# ============================================================================
# STEP 1: Verify Containers are Running
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Verifying Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if GitLab is running
if ! docker ps | grep -q "gitlab-ce"; then
    echo "❌ GitLab container is not running!"
    echo "Please start GitLab first: docker compose up -d gitlab-ce"
    exit 1
else
    echo "✅ GitLab is running"
fi

# Check if Oxidized is configured
if [ ! -f "oxidized/config/config" ]; then
    echo "❌ Oxidized config not found!"
    echo "Please run master_setup.sh first"
    exit 1
else
    echo "✅ Oxidized is configured"
fi

# ============================================================================
# STEP 2: Generate SSH Keys on Host
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Generating SSH Keys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create keys directory on host
mkdir -p "${INSTALL_DIR}/oxidized/keys"

# Generate keys directly on host (they will be mounted into container)
if [ ! -f "${INSTALL_DIR}/oxidized/keys/gitlab" ]; then
    echo "Generating SSH key pair..."
    
    ssh-keygen -t ${SSH_KEY_TYPE} \
        -f "${INSTALL_DIR}/oxidized/keys/gitlab" \
        -N '' \
        -C "${OXIDIZED_GIT_EMAIL}"
    
    echo "✅ SSH key pair generated"
else
    echo "✅ SSH key pair already exists"
fi

# Set permissions on host
chmod 700 "${INSTALL_DIR}/oxidized/keys" 2>/dev/null || true
chmod 600 "${INSTALL_DIR}/oxidized/keys/gitlab" 2>/dev/null || true
chmod 644 "${INSTALL_DIR}/oxidized/keys/gitlab.pub" 2>/dev/null || true

PUBLIC_KEY=$(cat "${INSTALL_DIR}/oxidized/keys/gitlab.pub")

echo ""
echo "✅ SSH keys ready"
echo ""

# ============================================================================
# STEP 3: Manual GitLab Configuration Instructions
# ============================================================================
clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║           MANUAL GITLAB CONFIGURATION REQUIRED                   ║"
echo "║           SSH Authentication with Deploy Key                     ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Please follow these steps carefully to configure GitLab."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 STEP 1: Login to GitLab as Root"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Open your browser and go to:"
echo "  🌐 URL: https://${GITLAB_DOMAIN}"
echo ""
echo "  Login with:"
echo "  👤 Username: root"
echo "  🔑 Password: ${GITLAB_ROOT_PASSWORD}"
echo ""
read -p "Press ENTER when you are logged in..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 STEP 2: Create Oxidized User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Go to: Admin → Users"
echo "  3. Click the blue 'New user' button (top right)"
echo "  4. Fill in the form:"
echo ""
echo "     Name: Oxidized Backup Service"
echo "     Username: ${GITLAB_OXIDIZED_USER}"
echo "     Email: ${GITLAB_OXIDIZED_EMAIL}"
echo ""
echo "  5. Click 'Create user'"
echo "  6. Click 'Edit' on the newly created user"
echo "  7. Scroll down to 'Password' section"
echo "  8. Enter password: ${GITLAB_OXIDIZED_PASSWORD}"
echo "  9. Confirm password: ${GITLAB_OXIDIZED_PASSWORD}"
echo "  10. Click 'Save changes'"
echo ""
read -p "Press ENTER when the user is created and password is set..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚪 STEP 3: Logout and Login as Oxidized User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Click on your avatar (top right) → Sign out"
echo "  2. Login with the new credentials and change password:"
echo "  3. Login with the new password:"
echo ""
echo "     Username: ${GITLAB_OXIDIZED_USER}"
echo "     Password: ${GITLAB_OXIDIZED_PASSWORD}"
echo ""
read -p "Press ENTER when you are logged in as oxidized user..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 STEP 4: Create Network Project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Click 'New project' (blue button)"
echo "  2. Click 'Create blank project'"
echo "  3. Fill in:"
echo ""
echo "     Project name: Network"
echo "     Project slug: network"
echo "     Visibility Level: Private"
echo "     ⚠️  Initialize repository with a README: LEAVE UNCHECKED!"
echo ""
echo "  4. Click 'Create project'"
echo "  5. You should see an empty project (no files yet)"
echo ""
echo "  ℹ️  The project will be populated automatically by Oxidized's first backup"
echo ""
read -p "Press ENTER when the empty project is created..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 STEP 5: Add SSH Deploy Key"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. In the project, go to: Settings → Repository"
echo "     (Settings is in the left sidebar, near the bottom)"
echo "  2. Find the section 'Deploy keys' and click 'Expand'"
echo "  3. Fill in:"
echo ""
echo "     Title: Oxidized Backup Key"
echo ""
echo "     Key: (copy the text below)"
echo ""
echo "     ✅ Grant write permissions (MUST be checked!)"
echo ""
echo "  4. Click 'Add key'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Copy this SSH Public Key:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "${PUBLIC_KEY}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The key is also saved in: ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
echo ""
read -p "Press ENTER when the deploy key is added..."
echo ""

# ============================================================================
# STEP 4: Setup SSH Known Hosts in Container
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring SSH Connection in Container..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec oxidized bash -c "
mkdir -p /opt/oxidized/.ssh
chmod 700 /opt/oxidized/.ssh

# Add GitLab to known_hosts
ssh-keyscan -p 22 -H gitlab-ce > /opt/oxidized/.ssh/known_hosts 2>/dev/null

if [ -s /opt/oxidized/.ssh/known_hosts ]; then
    echo '✅ SSH known_hosts configured'
else
    echo '❌ Failed to get GitLab host key'
fi
"

echo "✅ SSH configuration complete"

# ============================================================================
# STEP 5: Initialize Git Repository and Remote
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring Git Repository..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if repo already exists
REPO_EXISTS=$(docker exec oxidized bash -c "[ -d '/opt/oxidized/devices.git' ] && echo 'yes' || echo 'no'")

if [ "$REPO_EXISTS" = "no" ]; then
    echo "Initializing new Git repository..."
    docker exec oxidized bash -c "
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    git config user.name '${OXIDIZED_GIT_USER}'
    git config user.email '${OXIDIZED_GIT_EMAIL}'
    
    # Create initial README to establish main branch
    echo '# Network Device Configurations - ${ORG_NAME}' > README.md
    echo '' >> README.md
    echo 'This repository contains automated backups of network device configurations.' >> README.md
    echo '' >> README.md
    echo '## Automated by Oxidized' >> README.md
    echo '- Backup interval: Every 5 minutes' >> README.md
    echo '- Push method: SSH with Deploy Key' >> README.md
    echo '- Each commit shows actual configuration changes' >> README.md
    
    git add README.md
    git commit -m 'Initial commit by Oxidized'
    "
    echo "✅ Git repository initialized with initial commit"
else
    echo "✅ Git repository already exists"
fi

# Configure remote with SSH
echo ""
echo "Setting up SSH remote..."
docker exec oxidized bash -c "
cd /opt/oxidized/devices.git
git config user.name '${OXIDIZED_GIT_USER}'
git config user.email '${OXIDIZED_GIT_EMAIL}'
git remote remove origin 2>/dev/null || true
git remote add origin 'git@gitlab-ce:${GITLAB_PROJECT_PATH}.git'
"

echo "✅ Git remote configured (SSH)"

# ============================================================================
# STEP 6: Test SSH Connection and Initial Push
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing SSH Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Testing SSH connection to GitLab..."
SSH_TEST=$(docker exec oxidized bash -c "
ssh -p 22 -i /etc/oxidized/keys/gitlab \
    -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts \
    -o StrictHostKeyChecking=yes \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -T git@gitlab-ce 2>&1
" || true)

echo "$SSH_TEST"

if echo "$SSH_TEST" | grep -qE "(Welcome to GitLab|successfully authenticated)"; then
    echo ""
    echo "✅ SSH connection successful!"
    echo ""
else
    echo ""
    echo "❌ SSH connection failed"
    echo ""
    echo "Please verify:"
    echo "  • Deploy key was added in GitLab"
    echo "  • 'Grant write permissions' was checked"
    echo "  • The correct public key was used"
    echo ""
    echo "Public key:"
    echo "${PUBLIC_KEY}"
    echo ""
    read -p "Fix the issue and press ENTER to retry..."
    exit 1
fi

# ============================================================================
# STEP 7: Initial Push
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Performing Initial Push to GitLab"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PUSH_OUTPUT=$(docker exec oxidized bash -c "
cd /opt/oxidized/devices.git

# Set SSH command
export GIT_SSH_COMMAND='ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=30'

# Show remote
echo 'Current remote:'
git remote -v
echo ''

# Try to push
echo 'Attempting initial push to empty GitLab project...'
git push -u origin main 2>&1
" || true)

echo "Push output:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$PUSH_OUTPUT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Analyze push result
if echo "$PUSH_OUTPUT" | grep -qE "(main -> main|branch 'main' set up|new branch)"; then
    echo "✅ SUCCESS! Initial push completed successfully!"
    echo ""
    echo "🎉 GitLab SSH integration is fully working!"
    echo ""
    SETUP_SUCCESS=true
    
elif echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
    echo "✅ Push successful (repository was already up-to-date)"
    echo ""
    SETUP_SUCCESS=true
    
else
    echo "❌ Push failed or had unexpected output"
    echo ""
    echo "Please check manually:"
    echo "  1. Go to: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  2. Verify the project is completely empty (no README)"
    echo "  3. Check Deploy Key has write permissions"
    echo ""
    SETUP_SUCCESS=false
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              GitLab SSH Integration Summary                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Configuration Details:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GitLab URL:       https://${GITLAB_DOMAIN}"
echo "  Oxidized User:    ${GITLAB_OXIDIZED_USER}"
echo "  Password:         ${GITLAB_OXIDIZED_PASSWORD}"
echo "  Project:          ${GITLAB_PROJECT_PATH}"
echo "  Project URL:      https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
echo ""
echo "🔐 SSH Authentication:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Method:  Deploy Key (SSH)"
echo "  Public:  ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
echo "  Private: ${INSTALL_DIR}/oxidized/keys/gitlab"
echo ""
echo "📁 Git Repository:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Local:  /opt/oxidized/devices.git (in container)"
echo "  Remote: git@gitlab-ce:${GITLAB_PROJECT_PATH}.git"
echo ""

if [ "$SETUP_SUCCESS" = true ]; then
    echo "✅ Status: WORKING"
    echo ""
    echo "🎯 How it works:"
    echo "  • Device backup triggers Oxidized"
    echo "  • Oxidized commits changes to local git"
    echo "  • Hook executes: git push via SSH"
    echo "  • SSH uses Deploy Key for authentication"
    echo "  • Changes appear in GitLab"
    echo ""
    echo "🎯 Next Steps:"
    echo "  • Device backups will automatically push to GitLab"
    echo "  • View backups at: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  • Check logs: docker logs oxidized"
    echo "  • Trigger manual backup: docker exec oxidized curl -X GET http://localhost:8888/reload"
else
    echo "⚠️  Status: NEEDS ATTENTION"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  1. Verify Deploy Key has write permissions"
    echo "  2. Test SSH: docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce"
    echo "  3. Check logs: docker logs oxidized"
    echo "  4. Re-run this script if needed"
fi

echo ""
echo "📋 Log saved to: $LOG_FILE"
echo ""
echo "Setup completed: $(date)"
echo ""