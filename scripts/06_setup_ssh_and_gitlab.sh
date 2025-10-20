#!/bin/bash
# 06_setup_ssh_and_gitlab.sh - GitLab Integration (Manual Setup)
# FIXED: Permission errors beim SSH Key Generation

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
echo "06 - GitLab Integration Setup"
echo "=========================================="

cd "${INSTALL_DIR}"

# ============================================================================
# STEP 1: Verify Containers are Running
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Verifying Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! docker ps | grep -q "oxidized"; then
    echo "Starting Oxidized..."
    docker compose up -d oxidized
    sleep 20
else
    echo "✅ Oxidized is running"
fi

if ! docker ps | grep -q "gitlab-ce"; then
    echo "❌ GitLab container is not running!"
    echo "Run: docker compose up -d gitlab-ce"
    exit 1
else
    echo "✅ GitLab is running"
fi

# ============================================================================
# STEP 2: Generate SSH Keys - FIXED VERSION
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Generating SSH Keys (Fixed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create keys directory on host FIRST
mkdir -p "${INSTALL_DIR}/oxidized/keys"
chmod 755 "${INSTALL_DIR}/oxidized/keys"

# Generate keys on HOST, not in container
if [ ! -f "${INSTALL_DIR}/oxidized/keys/gitlab" ]; then
    echo "Generating SSH key pair on host..."
    
    # Generate on host
    ssh-keygen -t ${SSH_KEY_TYPE} \
        -f "${INSTALL_DIR}/oxidized/keys/gitlab" \
        -N '' \
        -C "${OXIDIZED_GIT_EMAIL}"
    
    # Set correct permissions
    chmod 600 "${INSTALL_DIR}/oxidized/keys/gitlab"
    chmod 644 "${INSTALL_DIR}/oxidized/keys/gitlab.pub"
    
    echo "✅ SSH key pair generated on host"
else
    echo "✅ SSH key pair already exists"
fi

# Now copy to container volume
echo "Copying keys to container..."
docker cp "${INSTALL_DIR}/oxidized/keys/gitlab" oxidized:/etc/oxidized/keys/gitlab
docker cp "${INSTALL_DIR}/oxidized/keys/gitlab.pub" oxidized:/etc/oxidized/keys/gitlab.pub

# Set permissions in container
docker exec oxidized bash -c "
chmod 700 /etc/oxidized/keys
chmod 600 /etc/oxidized/keys/gitlab
chmod 644 /etc/oxidized/keys/gitlab.pub
chown -R oxidized:oxidized /etc/oxidized/keys
"

echo "✅ Keys copied to container"

PUBLIC_KEY=$(cat "${INSTALL_DIR}/oxidized/keys/gitlab.pub")

echo ""
echo "✅ SSH keys generated and configured"
echo ""

# ============================================================================
# STEP 3: Manual GitLab Configuration Instructions
# ============================================================================
clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║           MANUAL GITLAB CONFIGURATION REQUIRED                   ║"
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
echo "  1. Click the menu icon (☰) in the top left"
echo "  2. Go to: Admin → Users"
echo "  3. Click the blue 'New user' button (top right)"
echo "  4. Fill in the form:"
echo ""
echo "     Name: Oxidized Backup Service"
echo "     Username: ${GITLAB_OXIDIZED_USER}"
echo "     Email: ${GITLAB_OXIDIZED_EMAIL}"
echo ""
echo "  5. IMPORTANT: Uncheck 'Send password reset email'"
echo "  6. Click 'Create user'"
echo "  7. You'll see a success message"
echo "  8. Click 'Edit' on the newly created user"
echo "  9. Scroll down to 'Password' section"
echo "  10. Enter password: ${GITLAB_OXIDIZED_PASSWORD}"
echo "  11. Confirm password: ${GITLAB_OXIDIZED_PASSWORD}"
echo "  12. Click 'Save changes'"
echo ""
read -p "Press ENTER when the user is created and password is set..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚪 STEP 3: Logout and Login as Oxidized User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Click on your avatar (top right) → Sign out"
echo "  2. Login with the new credentials:"
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
echo "     ✅ Initialize repository with a README (MUST be checked!)"
echo ""
echo "  4. Click 'Create project'"
echo "  5. You should see the project page with a README.md file"
echo ""
read -p "Press ENTER when the project is created..."
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
# STEP 4: Setup SSH Known Hosts
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring SSH Connection..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec oxidized bash -c "
mkdir -p /opt/oxidized/.ssh
chmod 700 /opt/oxidized/.ssh

ssh-keyscan -p 22 -H gitlab-ce > /opt/oxidized/.ssh/known_hosts 2>/dev/null

if [ -s /opt/oxidized/.ssh/known_hosts ]; then
    echo '✅ SSH known_hosts configured'
fi
"

# ============================================================================
# STEP 5: Initialize Git Remote
# ============================================================================
echo ""
echo "Configuring Git repository..."

docker exec oxidized bash -c "
# Initialize repository if needed
if [ ! -d '/opt/oxidized/devices.git' ]; then
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    echo '# Network Device Configurations' > README.md
    git add README.md
    git config user.name '${OXIDIZED_GIT_USER}'
    git config user.email '${OXIDIZED_GIT_EMAIL}'
    git commit -m 'Initial commit'
fi

cd /opt/oxidized/devices.git

# Configure remote
git config user.name '${OXIDIZED_GIT_USER}'
git config user.email '${OXIDIZED_GIT_EMAIL}'
git remote remove origin 2>/dev/null || true
git remote add origin 'git@gitlab-ce:${GITLAB_PROJECT_PATH}.git'
"

echo "✅ Git remote configured"

# ============================================================================
# STEP 6: Test Push
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing Push to GitLab..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PUSH_OUTPUT=$(docker exec oxidized bash -c "
cd /opt/oxidized/devices.git
export GIT_SSH_COMMAND='ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes'
git push -u origin main 2>&1
" || true)

echo "$PUSH_OUTPUT"
echo ""

if echo "$PUSH_OUTPUT" | grep -qE "(main -> main|Everything up-to-date|branch 'main' set up)"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SUCCESS! Push to GitLab was successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 GitLab integration is working correctly!"
    echo ""
    echo "Your network device backups will now be automatically"
    echo "pushed to GitLab every time Oxidized runs."
    echo ""
    SETUP_SUCCESS=true
elif echo "$PUSH_OUTPUT" | grep -q "Permission denied"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ FAILED: Permission Denied"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Please check:"
    echo "  • Deploy key was added correctly"
    echo "  • 'Grant write permissions' was checked"
    echo "  • The key matches: ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
    echo ""
    SETUP_SUCCESS=false
elif echo "$PUSH_OUTPUT" | grep -q "repository not found"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ FAILED: Repository Not Found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Please check:"
    echo "  • Project exists at: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  • You are logged in as '${GITLAB_OXIDIZED_USER}'"
    echo "  • Project was initialized with README"
    echo ""
    SETUP_SUCCESS=false
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  WARNING: Unexpected Result"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Please verify manually at:"
    echo "  https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo ""
    SETUP_SUCCESS=false
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                  GitLab Integration Summary                      ║"
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
echo "🔐 SSH Key:"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
    echo "🎯 Next Steps:"
    echo "  • Device backups will automatically push to GitLab"
    echo "  • View backups at: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  • Check Oxidized logs: docker logs oxidized"
else
    echo "⚠️  Status: NEEDS ATTENTION"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  1. Verify all steps were completed correctly"
    echo "  2. Check GitLab project: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  3. Test SSH manually:"
    echo "     docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce"
    echo "  4. Re-run this script if needed"
fi

echo ""
echo "📋 Log saved to: $LOG_FILE"
echo ""
echo "Setup completed: $(date)"
echo ""