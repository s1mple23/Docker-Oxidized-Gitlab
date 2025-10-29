#!/bin/bash
# 06_setup_ssh_and_gitlab.sh - GitLab SSH Integration (NO TOKEN)
# FIXED: Maintains output to master_setup.sh log while creating own log
# Pure SSH with Deploy Key authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# Expand variables
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
GITLAB_PROJECT_PATH=$(eval echo "${GITLAB_PROJECT_PATH}")
OXIDIZED_GIT_EMAIL=$(eval echo "${OXIDIZED_GIT_EMAIL}")

LOG_FILE="${LOG_DIR}/06_ssh_gitlab_$(date +%Y%m%d_%H%M%S).log"

# ============================================================================
# CRITICAL FIX: Don't use exec - it breaks master_setup.sh logging!
# Instead, use a function that writes to both stdout AND our log
# ============================================================================

# Create log file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Function to output to both stdout (for master_setup.sh) and our log
log_both() {
    echo "$@"
    echo "$@" >> "$LOG_FILE"
}

# Wrapper to execute commands and log to both outputs
run_logged() {
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

# ============================================================================
# Use log_both for all echo statements from now on
# Use run_logged for commands that should be logged
# ============================================================================

log_both "=========================================="
log_both "06 - GitLab SSH Integration (Deploy Key)"
log_both "=========================================="

cd "${INSTALL_DIR}"

# ============================================================================
# STEP 1: Verify Containers are Running
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 1: Verifying Containers"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if GitLab is running
if ! docker ps | grep -q "gitlab-ce"; then
    log_both "❌ GitLab container is not running!"
    log_both "Please start GitLab first: docker compose up -d gitlab-ce"
    exit 1
else
    log_both "✅ GitLab is running"
fi

# Check if Oxidized is configured
if [ ! -f "oxidized/config/config" ]; then
    log_both "❌ Oxidized config not found!"
    log_both "Please run master_setup.sh first"
    exit 1
else
    log_both "✅ Oxidized is configured"
fi

# ============================================================================
# STEP 2: Generate SSH Keys on Host
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 2: Generating SSH Keys"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create keys directory on host
mkdir -p "${INSTALL_DIR}/oxidized/keys"

# Generate keys directly on host (they will be mounted into container)
if [ ! -f "${INSTALL_DIR}/oxidized/keys/gitlab" ]; then
    log_both "Generating SSH key pair..."
    
    ssh-keygen -t ${SSH_KEY_TYPE} \
        -f "${INSTALL_DIR}/oxidized/keys/gitlab" \
        -N '' \
        -C "${OXIDIZED_GIT_EMAIL}" 2>&1 | tee -a "$LOG_FILE"
    
    log_both "✅ SSH key pair generated"
else
    log_both "✅ SSH key pair already exists"
fi

# Set permissions on host
chmod 700 "${INSTALL_DIR}/oxidized/keys" 2>/dev/null || true
chmod 600 "${INSTALL_DIR}/oxidized/keys/gitlab" 2>/dev/null || true
chmod 644 "${INSTALL_DIR}/oxidized/keys/gitlab.pub" 2>/dev/null || true

PUBLIC_KEY=$(cat "${INSTALL_DIR}/oxidized/keys/gitlab.pub")

log_both ""
log_both "✅ SSH keys ready"
log_both ""

# ============================================================================
# STEP 3: Manual GitLab Configuration Instructions
# ============================================================================
clear
log_both ""
log_both "╔══════════════════════════════════════════════════════════════════╗"
log_both "║                                                                  ║"
log_both "║           MANUAL GITLAB CONFIGURATION REQUIRED                   ║"
log_both "║           SSH Authentication with Deploy Key                     ║"
log_both "║                                                                  ║"
log_both "╚══════════════════════════════════════════════════════════════════╝"
log_both ""
log_both "Please follow these steps carefully to configure GitLab."
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "📋 STEP 1: Login to GitLab as Root"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "  Open your browser and go to:"
log_both "  🌐 URL: https://${GITLAB_DOMAIN}"
log_both ""
log_both "  Login with:"
log_both "  👤 Username: root"
log_both "  🔑 Password: ${GITLAB_ROOT_PASSWORD}"
log_both ""
read -p "Press ENTER when you are logged in..."
log_both ""

log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "👤 STEP 2: Create Oxidized User"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "  1. Go to: Admin → Users"
log_both "  3. Click the blue 'New user' button (top right)"
log_both "  4. Fill in the form:"
log_both ""
log_both "     Name: Oxidized Backup Service"
log_both "     Username: ${GITLAB_OXIDIZED_USER}"
log_both "     Email: ${GITLAB_OXIDIZED_EMAIL}"
log_both ""
log_both "  5. Click 'Create user'"
log_both "  6. Click 'Edit' on the newly created user"
log_both "  7. Scroll down to 'Password' section"
log_both "  8. Enter password: ${GITLAB_OXIDIZED_PASSWORD}"
log_both "  9. Confirm password: ${GITLAB_OXIDIZED_PASSWORD}"
log_both "  10. Click 'Save changes'"
log_both ""
read -p "Press ENTER when the user is created and password is set..."
log_both ""

log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "🚪 STEP 3: Logout and Login as Oxidized User"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "  1. Click on your avatar (top right) → Sign out"
log_both "  2. Login with the new credentials and change password:"
log_both "  3. Login with the new password:"
log_both ""
log_both "     Username: ${GITLAB_OXIDIZED_USER}"
log_both "     Password: ${GITLAB_OXIDIZED_PASSWORD}"
log_both ""
read -p "Press ENTER when you are logged in as oxidized user..."
log_both ""

log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "📁 STEP 4: Create Network Project"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "  1. Click 'New project' (blue button)"
log_both "  2. Click 'Create blank project'"
log_both "  3. Fill in:"
log_both ""
log_both "     Project name: Network"
log_both "     Project slug: network"
log_both "     Visibility Level: Private"
log_both "     ⚠️  Initialize repository with a README: LEAVE UNCHECKED!"
log_both ""
log_both "  4. Click 'Create project'"
log_both "  5. You should see an empty project (no files yet)"
log_both ""
log_both "  ℹ️  The project will be populated automatically by Oxidized's first backup"
log_both ""
read -p "Press ENTER when the empty project is created..."
log_both ""

log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "🔐 STEP 5: Add SSH Deploy Key"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "  1. In the project, go to: Settings → Repository"
log_both "     (Settings is in the left sidebar, near the bottom)"
log_both "  2. Find the section 'Deploy keys' and click 'Expand'"
log_both "  3. Fill in:"
log_both ""
log_both "     Title: Oxidized Backup Key"
log_both ""
log_both "     Key: (copy the text below)"
log_both ""
log_both "     ✅ Grant write permissions (MUST be checked!)"
log_both ""
log_both "  4. Click 'Add key'"
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Copy this SSH Public Key:"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "${PUBLIC_KEY}"
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "The key is also saved in: ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
log_both ""
read -p "Press ENTER when the deploy key is added..."
log_both ""

# ============================================================================
# STEP 4: Setup SSH Known Hosts in Container
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Configuring SSH Connection in Container..."
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_logged docker exec oxidized bash -c "
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

log_both "✅ SSH configuration complete"

# ============================================================================
# STEP 5: Initialize Git Repository and Remote
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Configuring Git Repository..."
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if repo already exists
REPO_EXISTS=$(docker exec oxidized bash -c "[ -d '/opt/oxidized/devices.git' ] && echo 'yes' || echo 'no'")
echo "REPO_EXISTS=$REPO_EXISTS" >> "$LOG_FILE"

if [ "$REPO_EXISTS" = "no" ]; then
    log_both "Initializing new Git repository..."
    run_logged docker exec oxidized bash -c "
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
    log_both "✅ Git repository initialized with initial commit"
else
    log_both "✅ Git repository already exists"
fi

# Configure remote with SSH
log_both ""
log_both "Setting up SSH remote..."
run_logged docker exec oxidized bash -c "
cd /opt/oxidized/devices.git
git config user.name '${OXIDIZED_GIT_USER}'
git config user.email '${OXIDIZED_GIT_EMAIL}'
git remote remove origin 2>/dev/null || true
git remote add origin 'git@gitlab-ce:${GITLAB_PROJECT_PATH}.git'
"

log_both "✅ Git remote configured (SSH)"

# ============================================================================
# STEP 6: Test SSH Connection and Initial Push
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Testing SSH Connection"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

log_both "Testing SSH connection to GitLab..."
SSH_TEST=$(docker exec oxidized bash -c "
ssh -p 22 -i /etc/oxidized/keys/gitlab \
    -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts \
    -o StrictHostKeyChecking=yes \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -T git@gitlab-ce 2>&1
" || true)

log_both "$SSH_TEST"

if echo "$SSH_TEST" | grep -qE "(Welcome to GitLab|successfully authenticated)"; then
    log_both ""
    log_both "✅ SSH connection successful!"
    log_both ""
else
    log_both ""
    log_both "❌ SSH connection failed"
    log_both ""
    log_both "Please verify:"
    log_both "  • Deploy key was added in GitLab"
    log_both "  • 'Grant write permissions' was checked"
    log_both "  • The correct public key was used"
    log_both ""
    log_both "Public key:"
    log_both "${PUBLIC_KEY}"
    log_both ""
    read -p "Fix the issue and press ENTER to retry..."
    exit 1
fi

# ============================================================================
# STEP 7: Initial Push
# ============================================================================
log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Performing Initial Push to GitLab"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

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

log_both "Push output:"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "$PUSH_OUTPUT"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

# Analyze push result
if echo "$PUSH_OUTPUT" | grep -qE "(main -> main|branch 'main' set up|new branch)"; then
    log_both "✅ SUCCESS! Initial push completed successfully!"
    log_both ""
    log_both "🎉 GitLab SSH integration is fully working!"
    log_both ""
    SETUP_SUCCESS=true
    
elif echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
    log_both "✅ Push successful (repository was already up-to-date)"
    log_both ""
    SETUP_SUCCESS=true
    
else
    log_both "❌ Push failed or had unexpected output"
    log_both ""
    log_both "Please check manually:"
    log_both "  1. Go to: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    log_both "  2. Verify the project is completely empty (no README)"
    log_both "  3. Check Deploy Key has write permissions"
    log_both ""
    SETUP_SUCCESS=false
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
log_both ""
log_both "╔══════════════════════════════════════════════════════════════════╗"
log_both "║              GitLab SSH Integration Summary                      ║"
log_both "╚══════════════════════════════════════════════════════════════════╝"
log_both ""
log_both "📋 Configuration Details:"
log_both "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "  GitLab URL:       https://${GITLAB_DOMAIN}"
log_both "  Oxidized User:    ${GITLAB_OXIDIZED_USER}"
log_both "  Password:         ${GITLAB_OXIDIZED_PASSWORD}"
log_both "  Project:          ${GITLAB_PROJECT_PATH}"
log_both "  Project URL:      https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
log_both ""
log_both "🔐 SSH Authentication:"
log_both "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "  Method:  Deploy Key (SSH)"
log_both "  Public:  ${INSTALL_DIR}/oxidized/keys/gitlab.pub"
log_both "  Private: ${INSTALL_DIR}/oxidized/keys/gitlab"
log_both ""
log_both "📁 Git Repository:"
log_both "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "  Local:  /opt/oxidized/devices.git (in container)"
log_both "  Remote: git@gitlab-ce:${GITLAB_PROJECT_PATH}.git"
log_both ""

if [ "$SETUP_SUCCESS" = true ]; then
    log_both "✅ Status: WORKING"
    log_both ""
    log_both "🎯 How it works:"
    log_both "  • Device backup triggers Oxidized"
    log_both "  • Oxidized commits changes to local git"
    log_both "  • Hook executes: git push via SSH"
    log_both "  • SSH uses Deploy Key for authentication"
    log_both "  • Changes appear in GitLab"
    log_both ""
    log_both "🎯 Next Steps:"
    log_both "  • Device backups will automatically push to GitLab"
    log_both "  • View backups at: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
    log_both "  • Check logs: docker logs oxidized"
    log_both "  • Trigger manual backup: docker exec oxidized curl -X GET http://localhost:8888/reload"
else
    log_both "⚠️  Status: NEEDS ATTENTION"
    log_both ""
    log_both "🔧 Troubleshooting:"
    log_both "  1. Verify Deploy Key has write permissions"
    log_both "  2. Test SSH: docker exec oxidized ssh -p 22 -i /etc/oxidized/keys/gitlab -T git@gitlab-ce"
    log_both "  3. Check logs: docker logs oxidized"
    log_both "  4. Re-run this script if needed"
fi

log_both ""
log_both "📋 Log saved to: $LOG_FILE"
log_both ""
log_both "Setup completed: $(date)"
log_both ""