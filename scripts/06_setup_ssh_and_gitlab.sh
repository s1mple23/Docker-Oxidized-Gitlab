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

# Check if GitLab is running
if ! docker ps | grep -q "gitlab-ce"; then
    echo "❌ GitLab container is not running!"
    echo "Please start GitLab first: docker compose up -d gitlab-ce"
    exit 1
else
    echo "✅ GitLab is running"
fi

# Check if Oxidized is configured (doesn't need to be running yet)
if [ ! -f "oxidized/config/config" ]; then
    echo "❌ Oxidized config not found!"
    echo "Please run master_setup.sh first"
    exit 1
else
    echo "✅ Oxidized is configured"
fi

OXIDIZED_RUNNING=false
if docker ps | grep -q "oxidized"; then
    echo "✅ Oxidized is running"
    OXIDIZED_RUNNING=true
else
    echo "ℹ️  Oxidized not yet started (will be started after token setup)"
fi

# ============================================================================
# STEP 2: Generate SSH Keys - WORKING VERSION
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

# Set permissions on host (the directory is mounted as volume)
chmod 700 "${INSTALL_DIR}/oxidized/keys" 2>/dev/null || true
chmod 600 "${INSTALL_DIR}/oxidized/keys/gitlab" 2>/dev/null || true
chmod 644 "${INSTALL_DIR}/oxidized/keys/gitlab.pub" 2>/dev/null || true

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

# Check if repo already exists
REPO_EXISTS=$(docker exec oxidized bash -c "[ -d '/opt/oxidized/devices.git' ] && echo 'yes' || echo 'no'")

if [ "$REPO_EXISTS" = "no" ]; then
    echo "Initializing new Git repository..."
    docker exec oxidized bash -c "
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    echo '# Network Device Configurations - ${ORG_NAME}' > README.md
    echo '' >> README.md
    echo 'This repository contains automated backups of network device configurations.' >> README.md
    echo '' >> README.md
    echo '## Automated by Oxidized' >> README.md
    echo '- Backup interval: Every 10 minutes' >> README.md
    echo '- Commits show only actual configuration changes' >> README.md
    echo '- Each commit message includes device name and timestamp' >> README.md
    git add README.md
    git config user.name '${OXIDIZED_GIT_USER}'
    git config user.email '${OXIDIZED_GIT_EMAIL}'
    git commit -m 'Initial repository setup by Oxidized'
    "
    echo "✅ Git repository initialized"
else
    echo "✅ Git repository already exists"
fi

# Configure remote
docker exec oxidized bash -c "
cd /opt/oxidized/devices.git
git config user.name '${OXIDIZED_GIT_USER}'
git config user.email '${OXIDIZED_GIT_EMAIL}'
git remote remove origin 2>/dev/null || true
git remote add origin 'git@gitlab-ce:${GITLAB_PROJECT_PATH}.git'
"

echo "✅ Git remote configured"

# ============================================================================
# STEP 6: Test SSH Connection and Initial Push
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing SSH Connection and Initial Push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# First, test SSH connection
echo "Step 6.1: Testing SSH connection to GitLab..."
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
elif echo "$SSH_TEST" | grep -q "Permission denied"; then
    echo ""
    echo "❌ SSH connection failed: Permission denied"
    echo ""
    echo "Please check:"
    echo "  • Deploy key was added in GitLab"
    echo "  • 'Grant write permissions' was checked"
    echo "  • The correct public key was used"
    echo ""
    echo "Public key location:"
    echo "  In container: /etc/oxidized/keys/gitlab.pub"
    echo "  On host: ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
    echo ""
    echo "Public key content:"
    echo "${PUBLIC_KEY}"
    echo ""
    read -p "Fix the issue in GitLab and press ENTER to retry..."
    
    # Retry SSH test
    SSH_TEST=$(docker exec oxidized bash -c "
    ssh -p 22 -i /etc/oxidized/keys/gitlab \
        -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts \
        -o StrictHostKeyChecking=yes \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -T git@gitlab-ce 2>&1
    " || true)
    
    if ! echo "$SSH_TEST" | grep -qE "(Welcome to GitLab|successfully authenticated)"; then
        echo "❌ SSH still not working. Please check the configuration manually."
        SETUP_SUCCESS=false
    fi
else
    echo ""
    echo "⚠️  SSH connection test inconclusive (this can be normal)"
    echo "    Proceeding with push test..."
    echo ""
fi

# Now attempt the initial push
echo "Step 6.2: Performing initial push to GitLab..."
echo ""

PUSH_OUTPUT=$(docker exec oxidized bash -c "
cd /opt/oxidized/devices.git

# Set SSH command
export GIT_SSH_COMMAND='ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=30'

# Check if we have commits to push
if [ -z \"\$(git log 2>/dev/null)\" ]; then
    echo 'ERROR: No commits in local repository'
    exit 1
fi

# Check current remote
echo 'Current remote:'
git remote -v

# Try to push
echo ''
echo 'Attempting push...'
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
    echo "🎉 GitLab integration is fully working!"
    echo ""
    echo "Verification:"
    echo "  • Local commits were pushed to GitLab"
    echo "  • Branch 'main' is tracking 'origin/main'"
    echo "  • SSH authentication working"
    echo ""
    echo "Check in GitLab: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo ""
    SETUP_SUCCESS=true
    
elif echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
    echo "✅ Push successful (repository was already up-to-date)"
    echo ""
    echo "🎉 GitLab integration is working!"
    echo ""
    SETUP_SUCCESS=true
    
elif echo "$PUSH_OUTPUT" | grep -q "Permission denied"; then
    echo "❌ FAILED: Permission Denied"
    echo ""
    echo "The SSH key is not authorized or doesn't have write permissions."
    echo ""
    echo "Please verify in GitLab:"
    echo "  1. Go to: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}/-/settings/repository"
    echo "  2. Expand 'Deploy Keys'"
    echo "  3. Check that 'Oxidized Backup Key' is listed"
    echo "  4. Verify that 'Write access allowed' is checked"
    echo ""
    echo "Public key (should match):"
    echo "${PUBLIC_KEY}"
    echo ""
    echo "Debugging:"
    echo "  • Check key in container: docker exec oxidized cat /etc/oxidized/keys/gitlab.pub"
    echo "  • Check permissions: docker exec oxidized ls -la /etc/oxidized/keys/"
    echo ""
    SETUP_SUCCESS=false
    
elif echo "$PUSH_OUTPUT" | grep -qE "(repository not found|does not appear to be a git repository|Could not read from remote)"; then
    echo "❌ FAILED: Repository Not Found or Not Accessible"
    echo ""
    echo "The GitLab project might not exist or isn't configured correctly."
    echo ""
    echo "Please verify:"
    echo "  1. Project exists: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  2. You're logged in as: ${GITLAB_OXIDIZED_USER}"
    echo "  3. Project was initialized with README"
    echo "  4. Project visibility is set (Private recommended)"
    echo ""
    SETUP_SUCCESS=false
    
elif echo "$PUSH_OUTPUT" | grep -q "Connection refused\|timed out\|Could not resolve hostname"; then
    echo "❌ FAILED: Network/Connection Error"
    echo ""
    echo "Cannot reach GitLab container."
    echo ""
    echo "Please check:"
    echo "  • GitLab container is running: docker ps | grep gitlab"
    echo "  • Docker network is working: docker network ls | grep gitlabnet"
    echo "  • Containers can communicate:"
    echo "    docker exec oxidized ping -c 3 gitlab-ce"
    echo ""
    SETUP_SUCCESS=false
    
elif echo "$PUSH_OUTPUT" | grep -q "rejected\|failed to push"; then
    echo "❌ FAILED: Push Rejected"
    echo ""
    echo "The push was rejected by GitLab."
    echo ""
    echo "Common causes:"
    echo "  • Remote has commits that aren't in local repo"
    echo "  • Branch protection rules enabled"
    echo ""
    echo "Try manually:"
    echo "  docker exec oxidized bash"
    echo "  cd /opt/oxidized/devices.git"
    echo "  git pull origin main"
    echo "  git push origin main"
    echo ""
    SETUP_SUCCESS=false
    
else
    echo "⚠️  Push completed with unexpected output"
    echo ""
    echo "Please verify manually:"
    echo "  1. Go to: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    echo "  2. Check if you can see commits"
    echo "  3. Look for 'Initial repository setup by Oxidized' commit"
    echo ""
    echo "If you see the commit, everything is working!"
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