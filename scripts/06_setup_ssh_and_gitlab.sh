#!/bin/bash
# 06_setup_ssh_and_gitlab.sh - Complete GitLab Integration
# This script does EVERYTHING:
# - Generates SSH keys
# - Waits for GitLab to be ready
# - Creates Oxidized user in GitLab
# - Creates network project
# - Creates access token
# - Configures SSH connection
# This replaces the old script 08!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# Expand variables
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
GITLAB_PROJECT_PATH=$(eval echo "${GITLAB_PROJECT_PATH}")
OXIDIZED_GIT_EMAIL=$(eval echo "${OXIDIZED_GIT_EMAIL}")
GITLAB_OXIDIZED_EMAIL=$(eval echo "${GITLAB_OXIDIZED_EMAIL}")

LOG_FILE="${LOG_DIR}/06_ssh_gitlab_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "06 - Complete GitLab Integration"
echo "SSH Keys + User + Project + Token"
echo "=========================================="

cd "${INSTALL_DIR}"

# ============================================================================
# STEP 1: Start Oxidized Container
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Starting Oxidized Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! docker ps | grep -q "${OXIDIZED_CONTAINER_NAME}"; then
    echo "Starting Oxidized..."
    docker compose up -d ${OXIDIZED_CONTAINER_NAME}
    echo "Waiting 20s for container to start..."
    sleep 20
else
    echo "✅ Oxidized already running"
fi

# ============================================================================
# STEP 2: Generate SSH Keys
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Generating SSH Keys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec ${OXIDIZED_CONTAINER_NAME} bash -c "
mkdir -p /etc/oxidized/keys
chmod 700 /etc/oxidized/keys

if [ ! -f /etc/oxidized/keys/gitlab ]; then
    echo 'Generating SSH key pair...'
    ssh-keygen -t ${SSH_KEY_TYPE} -f /etc/oxidized/keys/gitlab -N '' -C '${OXIDIZED_GIT_EMAIL}'
    echo '✅ SSH key pair generated'
else
    echo '✅ SSH key pair already exists'
fi

echo 'Key fingerprint:'
ssh-keygen -lf /etc/oxidized/keys/gitlab.pub
"

# Copy keys to host
mkdir -p "${INSTALL_DIR}/oxidized/keys"
docker cp ${OXIDIZED_CONTAINER_NAME}:/etc/oxidized/keys/gitlab "${INSTALL_DIR}/oxidized/keys/"
docker cp ${OXIDIZED_CONTAINER_NAME}:/etc/oxidized/keys/gitlab.pub "${INSTALL_DIR}/oxidized/keys/"
chmod 600 "${INSTALL_DIR}/oxidized/keys/gitlab"
chmod 644 "${INSTALL_DIR}/oxidized/keys/gitlab.pub"

PUBLIC_KEY=$(cat "${INSTALL_DIR}/oxidized/keys/gitlab.pub")

echo "✅ SSH keys generated and copied to host"

# ============================================================================
# STEP 3: Wait for GitLab to be Ready
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Waiting for GitLab"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "GitLab needs 3-5 minutes to fully initialize..."
echo "Waiting 180 seconds..."
sleep 180

echo "Checking GitLab services..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec gitlab-ce gitlab-ctl status 2>/dev/null | grep -q "run:"; then
        echo "✅ GitLab services are running"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting... attempt $attempt/$max_attempts"
    sleep 10
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ GitLab did not start properly"
    echo "Check logs: docker logs gitlab-ce"
    exit 1
fi

echo "Waiting additional 30s for web interface..."
sleep 30

# ============================================================================
# STEP 4: Get GitLab Root Password
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: GitLab Root Password"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker exec gitlab-ce test -f /etc/gitlab/initial_root_password; then
    echo "Root password (save this!):"
    docker exec gitlab-ce cat /etc/gitlab/initial_root_password | grep "Password:"
else
    echo "⚠️  Initial root password file not found"
    echo "   Password may have been reset or file removed"
fi

# ============================================================================
# STEP 5: Create Oxidized User, Project, and Token
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Creating GitLab User, Project, Token"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse project path
IFS='/' read -r NAMESPACE PROJECT <<< "${GITLAB_PROJECT_PATH}"

docker exec gitlab-ce gitlab-rails runner - <<RUBY_SCRIPT
begin
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts 'Creating Oxidized User'
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  
  user = User.find_by(username: '${GITLAB_OXIDIZED_USER}')
  
  if user.nil?
    user = User.new(
      username: '${GITLAB_OXIDIZED_USER}',
      email: '${GITLAB_OXIDIZED_EMAIL}',
      name: 'Oxidized Backup Service',
      password: '${GITLAB_OXIDIZED_PASSWORD}',
      password_confirmation: '${GITLAB_OXIDIZED_PASSWORD}',
      admin: false
    )
    user.skip_confirmation!
    user.confirmed_at = Time.now
    
    if user.save
      puts '✅ Oxidized user created successfully'
      puts "   Username: ${GITLAB_OXIDIZED_USER}"
      puts "   Email: ${GITLAB_OXIDIZED_EMAIL}"
    else
      puts "❌ Failed to create user: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
  else
    puts '✅ Oxidized user already exists'
  end
  
  # Ensure user is confirmed
  unless user.confirmed?
    user.confirm
    puts '✅ User confirmed'
  end
  
  puts ''
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts 'Creating Personal Access Token'
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  
  # Find or create token
  token = user.personal_access_tokens.find_by(name: 'oxidized-backup')
  
  if token.nil?
    token = user.personal_access_tokens.create!(
      name: 'oxidized-backup',
      scopes: ['api', 'read_api', 'read_repository', 'write_repository'],
      expires_at: 2.years.from_now
    )
    puts "✅ Token created: #{token.token}"
    
    # Save token to file
    File.write('/var/opt/gitlab/oxidized_token.txt', token.token)
    puts '✅ Token saved to /var/opt/gitlab/oxidized_token.txt'
  else
    puts '✅ Token already exists'
    if File.exist?('/var/opt/gitlab/oxidized_token.txt')
      saved_token = File.read('/var/opt/gitlab/oxidized_token.txt').strip
      puts "   Token: #{saved_token}"
    end
  end
  
  puts ''
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts 'Creating Network Project'
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  
  # Create project
  project = user.projects.find_by(path: '${PROJECT}')
  
  if project.nil?
    project = ::Projects::CreateService.new(
      user,
      name: '${PROJECT}'.capitalize,
      path: '${PROJECT}',
      description: 'Network device configurations managed by Oxidized',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE,
      initialize_with_readme: true
    ).execute
    
    if project.is_a?(Project) && project.persisted?
      puts "✅ Project created: #{project.web_url}"
    else
      error_msg = project.is_a?(Project) ? project.errors.full_messages.join(', ') : 'Unknown error'
      puts "❌ Failed to create project: #{error_msg}"
      exit 1
    end
  else
    puts "✅ Project already exists: #{project.web_url}"
  end
  
  puts ''
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts 'Adding Deploy Key'
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  
  # Add deploy key
  public_key = "${PUBLIC_KEY}"
  
  deploy_key = project.deploy_keys.find_by(title: 'Oxidized Backup Key')
  
  if deploy_key.nil?
    deploy_key = DeployKey.create!(
      title: 'Oxidized Backup Key',
      key: public_key,
      can_push: true
    )
    
    project.deploy_keys_projects.create!(
      deploy_key: deploy_key,
      can_push: true
    )
    
    puts '✅ Deploy key added with write access'
  else
    puts '✅ Deploy key already exists'
    
    # Ensure write access
    deploy_keys_project = project.deploy_keys_projects.find_by(deploy_key: deploy_key)
    if deploy_keys_project && !deploy_keys_project.can_push
      deploy_keys_project.update!(can_push: true)
      puts '✅ Write access enabled'
    end
  end
  
  puts ''
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts '✅ GitLab Setup Complete!'
  puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  puts ''
  puts '📊 Summary:'
  puts "   🌐 URL: https://${GITLAB_DOMAIN}"
  puts "   👤 Username: ${GITLAB_OXIDIZED_USER}"
  puts "   🔑 Password: ${GITLAB_OXIDIZED_PASSWORD}"
  puts "   📧 Email: ${GITLAB_OXIDIZED_EMAIL}"
  puts "   📁 Project: ${GITLAB_PROJECT_PATH}"
  puts "   🔐 Deploy Key: Added with write access"
  puts "   🎫 Token: Saved to file"
  
rescue StandardError => e
  puts "❌ Error occurred: #{e.message}"
  puts "Stack trace:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
RUBY_SCRIPT

GITLAB_EXIT=$?
if [ $GITLAB_EXIT -ne 0 ]; then
    echo "❌ GitLab setup failed!"
    echo "Check GitLab logs: docker logs gitlab-ce"
    exit 1
fi

# ============================================================================
# STEP 6: Configure Token in Oxidized
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Configuring Token in Oxidized"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker exec gitlab-ce test -f /var/opt/gitlab/oxidized_token.txt; then
    TOKEN=$(docker exec gitlab-ce cat /var/opt/gitlab/oxidized_token.txt | tr -d '\n\r ')
    echo "✅ Retrieved token from GitLab"
    
    # Copy token to Oxidized
    echo "$TOKEN" | docker exec -i oxidized tee /opt/oxidized/gitlab_token > /dev/null
    echo "✅ Token configured in Oxidized container"
else
    echo "⚠️  Token file not found in GitLab container"
    echo "   Token may need to be configured manually"
fi

# ============================================================================
# STEP 7: Setup SSH Known Hosts
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Configuring SSH Known Hosts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec ${OXIDIZED_CONTAINER_NAME} bash -c "
mkdir -p /opt/oxidized/.ssh
chmod 700 /opt/oxidized/.ssh

echo 'Scanning gitlab-ce SSH host key...'
ssh-keyscan -p 22 -H gitlab-ce > /opt/oxidized/.ssh/known_hosts 2>/dev/null

if [ -s /opt/oxidized/.ssh/known_hosts ]; then
    echo '✅ Known hosts configured'
    echo 'Content:'
    cat /opt/oxidized/.ssh/known_hosts
else
    echo '⚠️  Known hosts scan failed, trying GitLab IP...'
    ssh-keyscan -p 22 -H ${GITLABNET_GITLAB_IP} > /opt/oxidized/.ssh/known_hosts 2>/dev/null
fi
"

# ============================================================================
# STEP 8: Test SSH Connection
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Testing SSH Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Testing: ssh -p 22 -T git@gitlab-ce"
SSH_OUTPUT=$(docker exec ${OXIDIZED_CONTAINER_NAME} ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes -T git@gitlab-ce 2>&1 || true)

echo "Response:"
echo "$SSH_OUTPUT"

if echo "$SSH_OUTPUT" | grep -q "Welcome to GitLab"; then
    echo "✅ SSH authentication successful!"
elif echo "$SSH_OUTPUT" | grep -q "Permission denied"; then
    echo "❌ SSH authentication failed"
    echo "   This shouldn't happen as we just added the deploy key"
    echo "   Check GitLab deploy keys: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}/-/settings/repository"
else
    echo "⚠️  Unexpected response (might still work)"
fi

# ============================================================================
# STEP 9: Initialize Git Remote
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Configuring Git Remote"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec ${OXIDIZED_CONTAINER_NAME} bash -c "
cd /opt/oxidized/devices.git 2>/dev/null || {
    echo 'Initializing repository...'
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    echo '# Network Device Configurations' > README.md
    git add README.md
    git commit -m 'Initial commit'
}

cd /opt/oxidized/devices.git

# Remove old remote
git remote remove origin 2>/dev/null || true

# Add new remote with container name
git remote add origin 'git@gitlab-ce:${GITLAB_PROJECT_PATH}.git'

echo '✅ Git remote configured'
echo 'Remote URL:'
git remote -v

# Try initial push
echo ''
echo 'Attempting initial push...'
export GIT_SSH_COMMAND='ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes'

if timeout 30 git push -u origin main 2>&1; then
    echo '✅ Initial push successful!'
else
    echo '⚠️  Initial push failed (will retry automatically)'
    echo '   This is normal if the repository needs initialization'
fi
"

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ COMPLETE GITLAB INTEGRATION FINISHED    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📋 What was done:"
echo "  ✅ SSH keys generated"
echo "  ✅ GitLab user created: ${GITLAB_OXIDIZED_USER}"
echo "  ✅ GitLab project created: ${GITLAB_PROJECT_PATH}"
echo "  ✅ Access token created and configured"
echo "  ✅ Deploy key added with write access"
echo "  ✅ SSH connection configured"
echo "  ✅ Git remote configured"
echo ""
echo "🌐 Access Information:"
echo "  GitLab URL: https://${GITLAB_DOMAIN}"
echo "  Username: ${GITLAB_OXIDIZED_USER}"
echo "  Password: ${GITLAB_OXIDIZED_PASSWORD}"
echo "  Project: https://${GITLAB_DOMAIN}/${GITLAB_PROJECT_PATH}"
echo ""
echo "🔍 Verify:"
echo "  docker exec oxidized git -C /opt/oxidized/devices.git remote -v"
echo "  docker logs oxidized --tail 50"
echo ""
echo "📋 Log: $LOG_FILE"
echo ""
echo "✅ You can now trigger backups and they will auto-push to GitLab!"
echo "   Completed: $(date)"