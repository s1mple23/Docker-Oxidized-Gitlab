#!/bin/bash
# master_setup.sh - Modular Infrastructure Setup
# Version: 9.0 - Loads scripts from external directory
# Scripts are loaded from ./scripts/ folder or GitHub

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

trap 'echo -e "${RED}Error on line $LINENO${NC}"; exit 1' ERR

echo "=========================================="
echo "Docker Infrastructure Master Setup"
echo "Version 9.0 - Modular"
echo "Started: $(date)"
echo "=========================================="

# Check for config.env
if [ ! -f "config.env" ]; then
    echo -e "${RED}ERROR: config.env not found!${NC}"
    exit 1
fi

echo "Loading configuration..."
source config.env

# Expand variables
OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
GITLAB_PROJECT_PATH=$(eval echo "${GITLAB_PROJECT_PATH}")
OXIDIZED_GIT_EMAIL=$(eval echo "${OXIDIZED_GIT_EMAIL}")
GITLAB_OXIDIZED_EMAIL=$(eval echo "${GITLAB_OXIDIZED_EMAIL}")

# Validate
REQUIRED_VARS=("ORG_NAME" "DOMAIN" "ADMIN_USER" "DOCKER_USER" "DOCKER_USER_PASSWORD")
[ "${INSTALL_OXIDIZED}" = "true" ] && REQUIRED_VARS+=("OXIDIZED_DOMAIN" "DEVICE_DEFAULT_PASSWORD")
[ "${INSTALL_GITLAB}" = "true" ] && REQUIRED_VARS+=("GITLAB_DOMAIN" "GITLAB_ROOT_PASSWORD")

echo ""
echo "Validating configuration..."
MISSING_VARS=0
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}✗ $var is not set${NC}"
        MISSING_VARS=$((MISSING_VARS + 1))
    else
        echo -e "${GREEN}✓ $var${NC}"
    fi
done

if [ $MISSING_VARS -gt 0 ]; then
    echo -e "${RED}ERROR: $MISSING_VARS required variable(s) missing${NC}"
    exit 1
fi

if [ "${INSTALL_OXIDIZED}" != "true" ] && [ "${INSTALL_GITLAB}" != "true" ]; then
    echo -e "${RED}ERROR: At least one service must be enabled${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validated${NC}"

SCRIPT_START_DIR="$(pwd)"
INSTALL_DIR="${INSTALL_DIR:-/opt/docker-infrastructure}"

echo ""
echo "Installation directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo chown "${ADMIN_USER}:${ADMIN_USER}" "$INSTALL_DIR"

echo "Creating directory structure..."
sudo mkdir -p "$INSTALL_DIR"/{nginx,oxidized,gitlab,certificates,scripts,logs,backups}
sudo mkdir -p "$INSTALL_DIR"/nginx/{conf.d,ssl}
sudo mkdir -p "$INSTALL_DIR"/oxidized/{config,data,keys}
sudo mkdir -p "$INSTALL_DIR"/gitlab/{config,logs,data}
sudo mkdir -p "$INSTALL_DIR"/certificates/{ca,ssl,csr,selfsigned}

sudo chown -R "${ADMIN_USER}:${ADMIN_USER}" "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

SETUP_LOG="$INSTALL_DIR/logs/master_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "Copying config.env..."
cp "$SCRIPT_START_DIR/config.env" "$INSTALL_DIR/config.env"
chmod 600 "$INSTALL_DIR/config.env"

cd "$INSTALL_DIR"

# ============================================================================
# COPY SCRIPTS FROM SOURCE DIRECTORY
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Copying setup scripts..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCRIPTS_SOURCE="$SCRIPT_START_DIR/scripts"

if [ ! -d "$SCRIPTS_SOURCE" ]; then
    echo -e "${RED}ERROR: Scripts directory not found: $SCRIPTS_SOURCE${NC}"
    echo "Expected directory structure:"
    echo "  ."
    echo "  ├── master_setup.sh"
    echo "  ├── config.env"
    echo "  ├── README.md"
    echo "  └── scripts/"
    echo "      ├── 01_initial_setup.sh"
    echo "      ├── 02_setup_networks.sh"
    echo "      └── ..."
    exit 1
fi

echo "Copying scripts from: $SCRIPTS_SOURCE"
cp -r "$SCRIPTS_SOURCE"/* "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts"/*.sh

SCRIPT_COUNT=$(ls -1 "$INSTALL_DIR/scripts"/*.sh 2>/dev/null | wc -l)
echo -e "${GREEN}✅ Copied $SCRIPT_COUNT scripts${NC}"

# List copied scripts
echo ""
echo "Available scripts:"
ls -1 "$INSTALL_DIR/scripts"/*.sh | xargs -n 1 basename

# ============================================================================
# OXIDIZED CONFIGURATION
# ============================================================================
if [ "${INSTALL_OXIDIZED}" = "true" ]; then
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating Oxidized Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Oxidized config with IMPROVED hook (immediate push)
cat > oxidized/config/config << EOF
---
username: ${DEVICE_DEFAULT_USERNAME}
password: ${DEVICE_DEFAULT_PASSWORD}
model: ${DEVICE_DEFAULT_MODEL}
interval: ${OXIDIZED_INTERVAL}
threads: ${OXIDIZED_THREADS}
timeout: ${OXIDIZED_TIMEOUT}
retries: ${OXIDIZED_RETRIES}
rest: 0.0.0.0:${OXIDIZED_REST_PORT}

input:
  default: ssh, telnet

output:
  default: git
  git:
    user: ${OXIDIZED_GIT_USER}
    email: ${OXIDIZED_GIT_EMAIL}
    repo: "${OXIDIZED_GIT_REPO}"

source:
  default: csv
  csv:
    file: ${OXIDIZED_ROUTER_DB}
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      model: 1

hooks:
  push_to_remote:
    type: exec
    events: [post_store]
    timeout: 120
    async: false
    cmd: ${OXIDIZED_HOOK_CMD}
EOF

# Router database
cat > oxidized/config/router.db << 'ROUTERDB_HEADER'
# Format: IP:MODEL:USERNAME:PASSWORD:ENABLE
ROUTERDB_HEADER

DEVICE_COUNT=0
for var in $(compgen -v | grep '^DEVICE_[0-9]\+$' | sort -V); do
    device_string="${!var}"
    if [ -n "$device_string" ]; then
        IFS=':' read -r ip model user pass enable <<< "$device_string"
        [ -z "$model" ] && model="${DEVICE_DEFAULT_MODEL}"
        [ -z "$user" ] && user="${DEVICE_DEFAULT_USERNAME}"
        [ -z "$pass" ] && pass="${DEVICE_DEFAULT_PASSWORD}"
        echo "${ip}:${model}:${user}:${pass}:${enable}" >> oxidized/config/router.db
        DEVICE_COUNT=$((DEVICE_COUNT + 1))
    fi
done

# Wrapper with Docker networking
if [ "${INSTALL_GITLAB}" = "true" ]; then
cat > oxidized/config/oxidized_wrapper.sh << EOF
#!/bin/bash
set -e
LOG="/var/log/oxidized/wrapper_\$(date +%Y%m%d).log"
mkdir -p /var/log/oxidized
exec > >(tee -a "\$LOG") 2>&1

echo "=========================================="
echo "Oxidized Wrapper (Docker Networking)"
echo "GitLab: gitlab-ce:22"
echo "=========================================="
sleep 30

git config --global user.name "${OXIDIZED_GIT_USER}"
git config --global user.email "${OXIDIZED_GIT_EMAIL}"
git config --global init.defaultBranch main

mkdir -p /opt/oxidized/.ssh
chmod 700 /opt/oxidized/.ssh

if [ ! -f /opt/oxidized/.ssh/known_hosts ]; then
    echo "Adding gitlab-ce to known_hosts..."
    ssh-keyscan -p 22 -H gitlab-ce > /opt/oxidized/.ssh/known_hosts 2>/dev/null
fi

if [ ! -d "/opt/oxidized/devices.git" ]; then
    echo "Initializing Git repository..."
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    echo "# Network Devices - ${ORG_NAME}" > README.md
    git add README.md
    git commit -m "Initial commit"
    echo "✅ Repository initialized"
fi

cd /opt/oxidized/devices.git
git remote remove origin 2>/dev/null || true
git remote add origin "git@gitlab-ce:${GITLAB_PROJECT_PATH}.git"

echo "✅ Remote configured: git@gitlab-ce:${GITLAB_PROJECT_PATH}.git"

cd /opt/oxidized
exec oxidized
EOF
else
cat > oxidized/config/oxidized_wrapper.sh << EOF
#!/bin/bash
set -e
LOG="/var/log/oxidized/wrapper.log"
mkdir -p /var/log/oxidized
exec > >(tee -a "\$LOG") 2>&1
echo "Oxidized Wrapper (Local Mode)"
git config --global user.name "${OXIDIZED_GIT_USER}"
git config --global user.email "${OXIDIZED_GIT_EMAIL}"
[ ! -d "/opt/oxidized/devices.git" ] && git init /opt/oxidized/devices.git
cd /opt/oxidized
exec oxidized
EOF
fi

# IMPROVED Git Push Hook (immediate push)
if [ "${INSTALL_GITLAB}" = "true" ]; then
cat > oxidized/config/git_push_hook.sh << 'HOOK'
#!/bin/bash
# Git Push Hook - Immediate push after backup
LOG_DIR="/var/log/oxidized"
LOG="$LOG_DIR/git_push_hook.log"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

log "=========================================="
log "Hook triggered by Oxidized"

cd /opt/oxidized/devices.git || {
    log "ERROR: Repository not found"
    exit 1
}

# Check for changes
if [ -z "$(git status --porcelain)" ]; then
    log "No changes to commit"
    exit 0
fi

# Commit changes
log "Committing changes..."
git add -A
git commit -m "Backup $(date '+%Y-%m-%d %H:%M:%S')" 2>&1 | tee -a "$LOG"

# Push immediately
log "Pushing to GitLab..."
export GIT_SSH_COMMAND="ssh -p 22 -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes"

if timeout 30 git push origin main 2>&1 | tee -a "$LOG"; then
    log "✅ Push successful"
    exit 0
else
    EXIT_CODE=$?
    log "❌ Push failed (exit $EXIT_CODE)"
    log "Remote: $(git remote get-url origin 2>/dev/null || echo 'not configured')"
    exit $EXIT_CODE
fi
HOOK
else
cat > oxidized/config/git_push_hook.sh << 'HOOK'
#!/bin/bash
echo "[$(date)] Local backup only" >> /var/log/oxidized/git_push_hook.log
HOOK
fi

chmod +x oxidized/config/*.sh

# Dockerfile
cat > oxidized/Dockerfile << 'DOCKERFILE'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    ruby ruby-dev libsqlite3-dev libssl-dev libssh2-1-dev libicu-dev \
    pkg-config cmake make gcc g++ git openssh-client ca-certificates curl sudo \
    && apt-get clean
RUN gem install --no-document oxidized oxidized-script oxidized-web
RUN groupadd -g 1000 oxidized && useradd -u 1000 -g 1000 -m oxidized && \
    echo "oxidized ALL=(ALL) NOPASSWD: /usr/sbin/update-ca-certificates" >> /etc/sudoers && \
    mkdir -p /opt/oxidized /etc/oxidized /etc/oxidized/keys /var/log/oxidized && \
    chown -R oxidized:oxidized /opt/oxidized /etc/oxidized /var/log/oxidized
COPY --chown=oxidized:oxidized config/config /etc/oxidized/config
COPY --chown=oxidized:oxidized config/router.db /opt/oxidized/router.db
COPY --chown=oxidized:oxidized config/git_push_hook.sh /opt/oxidized/git_push_hook.sh
COPY --chown=oxidized:oxidized config/oxidized_wrapper.sh /opt/oxidized/oxidized_wrapper.sh
RUN chmod +x /opt/oxidized/*.sh
VOLUME ["/opt/oxidized", "/var/log/oxidized", "/etc/oxidized/keys"]
USER oxidized
WORKDIR /opt/oxidized
EXPOSE 8888
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s CMD curl -f http://localhost:8888 || exit 1
CMD ["/opt/oxidized/oxidized_wrapper.sh"]
DOCKERFILE

echo -e "${GREEN}✅ Oxidized configured ($DEVICE_COUNT devices)${NC}"
fi

# ============================================================================
# GITLAB CONFIGURATION
# ============================================================================
if [ "${INSTALL_GITLAB}" = "true" ]; then
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating GitLab Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > gitlab/config/gitlab.rb << EOF
external_url 'https://${GITLAB_DOMAIN}'
nginx['ssl_certificate'] = "/etc/gitlab/ssl/${GITLAB_DOMAIN}.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/${GITLAB_DOMAIN}.key"
letsencrypt['enable'] = false
gitlab_rails['initial_root_password'] = '${GITLAB_ROOT_PASSWORD}'
gitlab_rails['gitlab_shell_ssh_port'] = ${GITLAB_SSH_PORT}
EOF

chmod 600 gitlab/config/gitlab.rb
echo -e "${GREEN}✅ GitLab configured${NC}"
fi

# ============================================================================
# NGINX CONFIGURATION
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating Nginx Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > nginx/nginx.conf << 'NGINX_MAIN'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" $status';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
}
NGINX_MAIN

if [ "${INSTALL_OXIDIZED}" = "true" ]; then
cat > nginx/conf.d/oxidized.conf << EOF
upstream oxidized_backend {
    server ${OXINET_OXIDIZED_IP}:8888;
}
server {
    listen 443 ssl http2;
    server_name ${OXIDIZED_DOMAIN};
    ssl_certificate /etc/nginx/ssl/${OXIDIZED_DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${OXIDIZED_DOMAIN}.key;
    location / {
        proxy_pass http://oxidized_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
server {
    listen 80;
    server_name ${OXIDIZED_DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOF
fi

if [ "${INSTALL_GITLAB}" = "true" ]; then
cat > nginx/conf.d/gitlab.conf << EOF
upstream gitlab_backend {
    server ${GITLABNET_GITLAB_IP}:443;
}
server {
    listen 443 ssl http2;
    server_name ${GITLAB_DOMAIN};
    ssl_certificate /etc/nginx/ssl/${GITLAB_DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${GITLAB_DOMAIN}.key;
    location / {
        proxy_pass https://gitlab_backend;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
server {
    listen 80;
    server_name ${GITLAB_DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOF
fi

echo -e "${GREEN}✅ Nginx configured${NC}"

# ============================================================================
# DOCKER COMPOSE
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating Docker Compose"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "${INSTALL_OXIDIZED}" = "true" ] && [ "${INSTALL_GITLAB}" = "true" ]; then
cat > docker-compose.yml << EOF
services:
  gitlab-ce:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-ce
    hostname: ${GITLAB_DOMAIN}
    ports:
      - "${GITLAB_SSH_PORT}:22"
    volumes:
      - ./gitlab/config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
      - ./certificates/ssl:/etc/gitlab/ssl:ro
    networks:
      gitlabnet:
        ipv4_address: ${GITLABNET_GITLAB_IP}
    restart: unless-stopped
    environment:
      GITLAB_OMNIBUS_CONFIG: "from_file '/etc/gitlab/gitlab.rb'"
    shm_size: '256m'
    healthcheck:
      test: ["CMD", "/opt/gitlab/bin/gitlab-healthcheck", "--fail"]
      interval: 60s
      timeout: 30s
      retries: 5
      start_period: 300s

  oxidized:
    build: ./oxidized
    container_name: oxidized
    volumes:
      - oxidized_data:/opt/oxidized
      - oxidized_logs:/var/log/oxidized
      - ./oxidized/keys:/etc/oxidized/keys
    networks:
      oxinet:
        ipv4_address: ${OXINET_OXIDIZED_IP}
      gitlabnet:
    restart: unless-stopped
    depends_on:
      gitlab-ce:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888"]
      interval: 30s
      timeout: 10s
      start_period: 120s

  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certificates/ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    networks:
      nginxnet:
        ipv4_address: ${NGINXNET_NGINX_IP}
      oxinet:
      gitlabnet:
    restart: unless-stopped
    depends_on:
      oxidized:
        condition: service_healthy
      gitlab-ce:
        condition: service_healthy

volumes:
  oxidized_data:
  oxidized_logs:
  gitlab_logs:
  gitlab_data:
  nginx_logs:

networks:
  oxinet:
    external: true
  gitlabnet:
    external: true
  nginxnet:
    external: true
EOF
elif [ "${INSTALL_OXIDIZED}" = "true" ]; then
cat > docker-compose.yml << EOF
services:
  oxidized:
    build: ./oxidized
    container_name: oxidized
    volumes:
      - oxidized_data:/opt/oxidized
      - oxidized_logs:/var/log/oxidized
    networks:
      oxinet:
        ipv4_address: ${OXINET_OXIDIZED_IP}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888"]
      interval: 30s

  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certificates/ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    networks:
      nginxnet:
        ipv4_address: ${NGINXNET_NGINX_IP}
      oxinet:
    restart: unless-stopped
    depends_on:
      oxidized:
        condition: service_healthy

volumes:
  oxidized_data:
  oxidized_logs:
  nginx_logs:

networks:
  oxinet:
    external: true
  nginxnet:
    external: true
EOF
else
cat > docker-compose.yml << EOF
services:
  gitlab-ce:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-ce
    hostname: ${GITLAB_DOMAIN}
    ports:
      - "${GITLAB_SSH_PORT}:22"
    volumes:
      - ./gitlab/config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
      - ./certificates/ssl:/etc/gitlab/ssl:ro
    networks:
      gitlabnet:
        ipv4_address: ${GITLABNET_GITLAB_IP}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "/opt/gitlab/bin/gitlab-healthcheck", "--fail"]
      interval: 60s

  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certificates/ssl:/etc/nginx/ssl:ro
    networks:
      nginxnet:
        ipv4_address: ${NGINXNET_NGINX_IP}
      gitlabnet:
    restart: unless-stopped
    depends_on:
      gitlab-ce:
        condition: service_healthy

volumes:
  gitlab_logs:
  gitlab_data:
  nginx_logs:

networks:
  gitlabnet:
    external: true
  nginxnet:
    external: true
EOF
fi

echo -e "${GREEN}✅ Docker Compose created${NC}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     ✅ SETUP COMPLETE - v9.0 MODULAR        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📁 Location: $INSTALL_DIR"
echo "📋 Log: $SETUP_LOG"
echo "📜 Scripts: $SCRIPT_COUNT copied"
echo ""
echo "Next steps:"
echo "1. cd $INSTALL_DIR"
echo "2. sudo ./scripts/01_initial_setup.sh"
echo "3. sudo reboot"
echo "4. Continue with scripts 02, 03, etc."
echo ""
echo "Completed: $(date)"