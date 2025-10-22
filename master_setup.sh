#!/bin/bash
# master_setup.sh - Complete SSH-Only Infrastructure Setup
# Version: 11.0 - Pure SSH with Deploy Key (NO TOKEN)
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

trap 'echo -e "${RED}Error on line $LINENO${NC}"; exit 1' ERR

# ============================================================================
# PASSWORD GENERATION
# ============================================================================
generate_password() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9!%&()_+=' < /dev/urandom | head -c "$length"
}

escape_for_sed() {
    echo "$1" | sed 's/[&/\]/\\&/g'
}

clear
echo "╔══════════════════════════════════════════════╗"
echo "║  Docker Infrastructure Master Setup          ║"
echo "║  Version 11.0 - SSH ONLY (No Token)          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Started: $(date)"
echo ""

SCRIPT_START_DIR="$(pwd)"
declare -A GENERATED_PASSWORDS

# ============================================================================
# INTERACTIVE CONFIG GENERATION
# ============================================================================
if [ ! -f "config.env" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Configuration Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ ! -f "config.env.example" ]; then
        echo -e "${RED}ERROR: config.env.example not found!${NC}"
        exit 1
    fi
    
    echo "No config.env found. Let's create one!"
    echo ""
    echo -e "${YELLOW}Note: Passwords will be auto-generated and shown at the end.${NC}"
    echo ""
    
    # Organization
    echo -e "${CYAN}=== Organization Settings ===${NC}"
    read -p "Organization Name [ORGNAME]: " ORG_NAME
    ORG_NAME=${ORG_NAME:-ORGNAME}
    
    read -p "Domain [example.com]: " DOMAIN
    DOMAIN=${DOMAIN:-example.com}
    
    # Installation Options
    echo ""
    echo -e "${CYAN}=== Installation Options ===${NC}"
    read -p "Install Oxidized? [Y/n]: " INSTALL_OXI
    INSTALL_OXI=${INSTALL_OXI:-Y}
    [[ "$INSTALL_OXI" =~ ^[Yy]$ ]] && INSTALL_OXIDIZED="true" || INSTALL_OXIDIZED="false"
    
    read -p "Install GitLab? [Y/n]: " INSTALL_GIT
    INSTALL_GIT=${INSTALL_GIT:-Y}
    [[ "$INSTALL_GIT" =~ ^[Yy]$ ]] && INSTALL_GITLAB="true" || INSTALL_GITLAB="false"
    
    # Certificate Mode
    echo ""
    echo -e "${CYAN}=== Certificate Mode ===${NC}"
    echo "1) Self-signed (automatic, for testing)"
    echo "2) Existing (from Windows CA or other)"
    read -p "Choose [1]: " CERT_CHOICE
    CERT_CHOICE=${CERT_CHOICE:-1}
    [[ "$CERT_CHOICE" == "2" ]] && CERT_MODE="existing" || CERT_MODE="selfsigned"
    
    # System Users
    echo ""
    echo -e "${CYAN}=== System Users ===${NC}"
    read -p "Admin username [administrator]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-administrator}
    
    # Generate passwords
    echo ""
    echo -e "${YELLOW}Generating secure passwords...${NC}"
    
    
    if [ "$INSTALL_GITLAB" = "true" ]; then
        GITLAB_ROOT_PASSWORD=$(generate_password 20)
        GENERATED_PASSWORDS["GitLab Root"]="$GITLAB_ROOT_PASSWORD"
        
        GITLAB_OXIDIZED_PASSWORD=$(generate_password 20)
        GENERATED_PASSWORDS["GitLab Oxidized User"]="$GITLAB_OXIDIZED_PASSWORD"
    fi
    
    if [ "$INSTALL_OXIDIZED" = "true" ]; then
        echo ""
        echo -e "${CYAN}=== Device Credentials ===${NC}"
        read -p "Default device username [backup]: " DEVICE_DEFAULT_USERNAME
        DEVICE_DEFAULT_USERNAME=${DEVICE_DEFAULT_USERNAME:-backup}
        
        echo -e "${YELLOW}Auto-generating device password...${NC}"
        DEVICE_DEFAULT_PASSWORD=$(generate_password 16)
        GENERATED_PASSWORDS["Device Default ($DEVICE_DEFAULT_USERNAME)"]="$DEVICE_DEFAULT_PASSWORD"
        
        # Device List
        echo ""
        echo -e "${CYAN}=== Network Devices ===${NC}"
        echo "Enter devices in format: IP:MODEL[:USERNAME[:PASSWORD]]"
        echo "Example: 10.99.99.50:panos"
        echo "         10.99.99.51:panos:admin"
        echo "         10.99.99.52:ios:admin:custompass"
        echo ""
        echo "Username and password are optional (will use defaults if not provided)"
        echo "Leave empty when done."
        echo ""
        
        DEVICE_COUNT=1
        DEVICE_LINES=""
        while true; do
            read -p "Device $DEVICE_COUNT: " DEVICE_INPUT
            [ -z "$DEVICE_INPUT" ] && break
            
            IFS=':' read -r ip model user pass <<< "$DEVICE_INPUT"
            
            [ -z "$user" ] && user="$DEVICE_DEFAULT_USERNAME"
            if [ -z "$pass" ]; then
                pass=$(generate_password 16)
                GENERATED_PASSWORDS["Device $ip ($user)"]="$pass"
            fi
            
            DEVICE_LINES="${DEVICE_LINES}DEVICE_${DEVICE_COUNT}=\"${ip}:${model}:${user}:${pass}:\"\n"
            DEVICE_COUNT=$((DEVICE_COUNT + 1))
        done
    fi
    
    # Generate config.env
    echo ""
    echo "Generating config.env..."
    
    cp config.env.example config.env
    
    # Replace values
    sed -i "s/^ORG_NAME=.*/ORG_NAME=\"${ORG_NAME}\"/" config.env
    sed -i "s/^DOMAIN=.*/DOMAIN=\"${DOMAIN}\"/" config.env
    sed -i "s/^INSTALL_OXIDIZED=.*/INSTALL_OXIDIZED=\"${INSTALL_OXIDIZED}\"/" config.env
    sed -i "s/^INSTALL_GITLAB=.*/INSTALL_GITLAB=\"${INSTALL_GITLAB}\"/" config.env
    sed -i "s/^CERT_MODE=.*/CERT_MODE=\"${CERT_MODE}\"/" config.env
    sed -i "s/^ADMIN_USER=.*/ADMIN_USER=\"${ADMIN_USER}\"/" config.env
    
    if [ "$INSTALL_GITLAB" = "true" ]; then
        GITLAB_ROOT_PASSWORD_ESC=$(escape_for_sed "$GITLAB_ROOT_PASSWORD")
        GITLAB_OXIDIZED_PASSWORD_ESC=$(escape_for_sed "$GITLAB_OXIDIZED_PASSWORD")
        
        sed -i "s|^GITLAB_ROOT_PASSWORD=.*|GITLAB_ROOT_PASSWORD=\"${GITLAB_ROOT_PASSWORD_ESC}\"|" config.env
        sed -i "s|^GITLAB_OXIDIZED_PASSWORD=.*|GITLAB_OXIDIZED_PASSWORD=\"${GITLAB_OXIDIZED_PASSWORD_ESC}\"|" config.env
    fi
    
    if [ "$INSTALL_OXIDIZED" = "true" ]; then
        DEVICE_DEFAULT_PASSWORD_ESC=$(escape_for_sed "$DEVICE_DEFAULT_PASSWORD")
        sed -i "s/^DEVICE_DEFAULT_USERNAME=.*/DEVICE_DEFAULT_USERNAME=\"${DEVICE_DEFAULT_USERNAME}\"/" config.env
        sed -i "s|^DEVICE_DEFAULT_PASSWORD=.*|DEVICE_DEFAULT_PASSWORD=\"${DEVICE_DEFAULT_PASSWORD_ESC}\"|" config.env
        
        sed -i '/^DEVICE_1=/d' config.env
        if [ -n "$DEVICE_LINES" ]; then
            echo "" >> config.env
            echo "# Network Devices" >> config.env
            echo -e "$DEVICE_LINES" >> config.env
        fi
    fi
    
    echo -e "${GREEN}✅ config.env created${NC}"
    echo ""
    
    # Save passwords
    PASSWORD_FILE="/tmp/infrastructure_passwords_$(date +%Y%m%d_%H%M%S).txt"
    echo "# GENERATED PASSWORDS - $(date)" > "$PASSWORD_FILE"
    echo "# ============================================" >> "$PASSWORD_FILE"
    echo "" >> "$PASSWORD_FILE"
    for key in "${!GENERATED_PASSWORDS[@]}"; do
        echo "$key: ${GENERATED_PASSWORDS[$key]}" >> "$PASSWORD_FILE"
    done
    chmod 600 "$PASSWORD_FILE"
    
else
    echo -e "${GREEN}✅ Using existing config.env${NC}"
    echo ""
fi

# ============================================================================
# LOAD AND VALIDATE CONFIG
# ============================================================================
echo "Loading configuration..."
source config.env

OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
GITLAB_PROJECT_PATH=$(eval echo "${GITLAB_PROJECT_PATH}")
OXIDIZED_GIT_EMAIL=$(eval echo "${OXIDIZED_GIT_EMAIL}")
GITLAB_OXIDIZED_EMAIL=$(eval echo "${GITLAB_OXIDIZED_EMAIL}")

REQUIRED_VARS=("ORG_NAME" "DOMAIN" "ADMIN_USER" )
[ "${INSTALL_OXIDIZED}" = "true" ] && REQUIRED_VARS+=("DEVICE_DEFAULT_PASSWORD")
[ "${INSTALL_GITLAB}" = "true" ] && REQUIRED_VARS+=("GITLAB_ROOT_PASSWORD")

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

# ============================================================================
# SETUP DIRECTORIES
# ============================================================================
INSTALL_DIR="${INSTALL_DIR:-/opt/docker-infrastructure}"

echo ""
echo "Installation directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$(whoami):$(whoami)" "$INSTALL_DIR" 2>/dev/null || sudo chown "${ADMIN_USER}:${ADMIN_USER}" "$INSTALL_DIR"

echo "Creating directory structure..."
sudo mkdir -p "$INSTALL_DIR"/{nginx,oxidized,gitlab,certificates,scripts,logs,backups}
sudo mkdir -p "$INSTALL_DIR"/nginx/{conf.d,ssl}
sudo mkdir -p "$INSTALL_DIR"/oxidized/{config,data,keys}
sudo mkdir -p "$INSTALL_DIR"/gitlab/{config,logs,data}
sudo mkdir -p "$INSTALL_DIR"/certificates/{ca,ssl,csr,selfsigned}

sudo chown -R "$(whoami):$(whoami)" "$INSTALL_DIR" 2>/dev/null || sudo chown -R "${ADMIN_USER}:${ADMIN_USER}" "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

SETUP_LOG="$INSTALL_DIR/logs/master_setup_$(date +%Y%m%d_%H%M%S).log"
CONFIG_SUMMARY="$INSTALL_DIR/INSTALLATION_CONFIG.txt"

# Create config summary
cat > "$CONFIG_SUMMARY" << EOF
# ============================================================================
# INSTALLATION CONFIGURATION SUMMARY
# ============================================================================
# Generated: $(date)
# Installation Directory: $INSTALL_DIR
# Authentication Method: SSH with Deploy Key (NO TOKEN)
# ============================================================================

[ORGANIZATION]
Name: $ORG_NAME
Domain: $DOMAIN

[SERVICES]
Oxidized: $INSTALL_OXIDIZED
GitLab: $INSTALL_GITLAB

[CERTIFICATE]
Mode: $CERT_MODE

[USERS]
Admin User: $ADMIN_USER

[DOMAINS]
EOF

[ "${INSTALL_OXIDIZED}" = "true" ] && echo "Oxidized: $OXIDIZED_DOMAIN" >> "$CONFIG_SUMMARY"
[ "${INSTALL_GITLAB}" = "true" ] && echo "GitLab: $GITLAB_DOMAIN" >> "$CONFIG_SUMMARY"

cat >> "$CONFIG_SUMMARY" << EOF

[NETWORK]
EOF

if [ "${INSTALL_OXIDIZED}" = "true" ]; then
    DEVICE_COUNT=$(compgen -v | grep '^DEVICE_[0-9]\+$' | wc -l)
    cat >> "$CONFIG_SUMMARY" << EOF

[OXIDIZED]
Device Username: $DEVICE_DEFAULT_USERNAME
Devices Configured: $DEVICE_COUNT
Interval: 300 seconds (5 minutes)
Push Method: SSH with Deploy Key
EOF
fi

if [ "${INSTALL_GITLAB}" = "true" ]; then
    cat >> "$CONFIG_SUMMARY" << EOF

[GITLAB]
SSH Port: $GITLAB_SSH_PORT
Oxidized User: $GITLAB_OXIDIZED_USER
Project: $GITLAB_PROJECT_PATH
Authentication: SSH Deploy Key (Write permissions)
EOF
fi

echo "" >> "$CONFIG_SUMMARY"
echo "See GENERATED_PASSWORDS.txt for passwords (if generated)" >> "$CONFIG_SUMMARY"

exec > >(tee -a "$SETUP_LOG") 2>&1

echo "Copying config.env..."
cp "$SCRIPT_START_DIR/config.env" "$INSTALL_DIR/config.env"
chmod 600 "$INSTALL_DIR/config.env"

if [ -n "$PASSWORD_FILE" ] && [ -f "$PASSWORD_FILE" ]; then
    cp "$PASSWORD_FILE" "$INSTALL_DIR/GENERATED_PASSWORDS.txt"
    chmod 600 "$INSTALL_DIR/GENERATED_PASSWORDS.txt"
fi

cd "$INSTALL_DIR"

# ============================================================================
# COPY SCRIPTS
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Copying setup scripts..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCRIPTS_SOURCE="$SCRIPT_START_DIR/scripts"

if [ ! -d "$SCRIPTS_SOURCE" ]; then
    echo -e "${RED}ERROR: Scripts directory not found: $SCRIPTS_SOURCE${NC}"
    exit 1
fi

echo "Copying scripts from: $SCRIPTS_SOURCE"
cp -r "$SCRIPTS_SOURCE"/* "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts"/*.sh

SCRIPT_COUNT=$(ls -1 "$INSTALL_DIR/scripts"/*.sh 2>/dev/null | wc -l)
echo -e "${GREEN}✅ Copied $SCRIPT_COUNT scripts${NC}"

# ============================================================================
# GENERATE CONFIGURATIONS - SSH ONLY
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Generating Configurations (SSH Only - No Token)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OXIDIZED - SSH ONLY
if [ "${INSTALL_OXIDIZED}" = "true" ]; then
    echo ""
    echo "Creating Oxidized configuration (SSH-based push)..."
    
    cat > oxidized/config/config << EOF
---
username: ${DEVICE_DEFAULT_USERNAME}
password: ${DEVICE_DEFAULT_PASSWORD}
model: ${DEVICE_DEFAULT_MODEL}
resolve_dns: true
interval: 300
use_syslog: false
debug: false
threads: ${OXIDIZED_THREADS}
timeout: ${OXIDIZED_TIMEOUT}
retries: ${OXIDIZED_RETRIES}
prompt: !ruby/regexp /^[\w.@-]+[#>]\s?$/
next_adds_job: false
vars:
  remove_secret: true
groups: {}
rest: 0.0.0.0:${OXIDIZED_REST_PORT}
pid: "/tmp/oxidized.pid"

input:
  default: ssh, telnet
  debug: false
  ssh:
    secure: false
    auth_methods:
      - password
      - keyboard-interactive

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
      username: 2
      password: 3
    vars_map:
      enable: 4

model_map:
  paloalto: panos
  panos: panos
  juniper: junos
  cisco: ios
  arista: eos
EOF

    # Add SSH hook if GitLab is installed
    if [ "${INSTALL_GITLAB}" = "true" ]; then
        cat >> oxidized/config/config << 'EOF'

# SSH-based push hook - NO TOKEN!
hooks:
  push_to_remote:
    type: exec
    events: [post_store]
    cmd: sh -c 'cd /opt/oxidized/devices.git && GIT_SSH_COMMAND="ssh -i /etc/oxidized/keys/gitlab -o UserKnownHostsFile=/opt/oxidized/.ssh/known_hosts -o StrictHostKeyChecking=yes" git push origin main'
EOF
    fi

    cat > oxidized/config/router.db << 'ROUTERDB_HEADER'
# Format: IP:MODEL:USERNAME:PASSWORD:ENABLE
# Per-device credentials override defaults in config file
ROUTERDB_HEADER

    DEVICE_COUNT=0
    for var in $(compgen -v | grep '^DEVICE_[0-9]\+$' | sort -V); do
        device_string="${!var}"
        if [ -n "$device_string" ]; then
            IFS=':' read -r ip model user pass enable <<< "$device_string"
            [ -z "$model" ] && model="${DEVICE_DEFAULT_MODEL}"
            [ -z "$user" ] && user=""
            [ -z "$pass" ] && pass=""
            echo "${ip}:${model}:${user}:${pass}:${enable}" >> oxidized/config/router.db
            DEVICE_COUNT=$((DEVICE_COUNT + 1))
        fi
    done

    # SIMPLIFIED Wrapper script - SSH only
    if [ "${INSTALL_GITLAB}" = "true" ]; then
        cat > oxidized/config/oxidized_wrapper.sh << 'EOF'
#!/bin/bash
set -e
LOG="/var/log/oxidized/wrapper_$(date +%Y%m%d).log"
mkdir -p /var/log/oxidized
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "Oxidized Wrapper - SSH Only"
echo "Started: $(date)"
echo "=========================================="

sleep 10

# Git Config
git config --global user.name "Oxidized"
git config --global user.email "oxidized@localhost"
git config --global init.defaultBranch main

# Init repo if needed
if [ ! -d "/opt/oxidized/devices.git" ]; then
    cd /opt/oxidized
    git init devices.git
    cd devices.git
    echo "# Network Devices" > README.md
    git add README.md
    git commit -m "Initial commit"
    echo "✅ Git repository initialized"
fi

cd /opt/oxidized/devices.git

# Setup SSH known_hosts
mkdir -p /opt/oxidized/.ssh
chmod 700 /opt/oxidized/.ssh
ssh-keyscan -p 22 -H gitlab-ce > /opt/oxidized/.ssh/known_hosts 2>/dev/null

# Setup git remote with SSH
git remote remove origin 2>/dev/null || true
git remote add origin 'git@gitlab-ce:oxidized/network.git'

echo "✅ Git remote configured (SSH)"
echo ""
echo "Starting Oxidized..."
cd /opt/oxidized
exec oxidized
EOF
    else
        cat > oxidized/config/oxidized_wrapper.sh << 'EOF'
#!/bin/bash
set -e
git config --global user.name "Oxidized"
git config --global user.email "oxidized@localhost"
git config --global init.defaultBranch main
[ ! -d "/opt/oxidized/devices.git" ] && git init /opt/oxidized/devices.git
cd /opt/oxidized
exec oxidized
EOF
    fi

    chmod +x oxidized/config/*.sh

    # Dockerfile
    cat > oxidized/Dockerfile << 'DOCKERFILE'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    ruby ruby-dev libsqlite3-dev libssl-dev libssh2-1-dev libicu-dev \
    pkg-config cmake make gcc g++ git openssh-client ca-certificates curl \
    && apt-get clean
RUN gem install --no-document oxidized oxidized-script oxidized-web
RUN groupadd -g 1000 oxidized && useradd -u 1000 -g 1000 -m oxidized && \
    mkdir -p /opt/oxidized /etc/oxidized /etc/oxidized/keys /var/log/oxidized && \
    chown -R oxidized:oxidized /opt/oxidized /etc/oxidized /var/log/oxidized
COPY --chown=oxidized:oxidized config/config /etc/oxidized/config
COPY --chown=oxidized:oxidized config/router.db /opt/oxidized/router.db
COPY --chown=oxidized:oxidized config/oxidized_wrapper.sh /opt/oxidized/oxidized_wrapper.sh
RUN chmod +x /opt/oxidized/*.sh
VOLUME ["/opt/oxidized", "/var/log/oxidized", "/etc/oxidized/keys"]
USER oxidized
WORKDIR /opt/oxidized
EXPOSE 8888
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s CMD curl -f http://localhost:8888 || exit 1
CMD ["/opt/oxidized/oxidized_wrapper.sh"]
DOCKERFILE

    echo -e "${GREEN}✅ Oxidized configured ($DEVICE_COUNT devices) - SSH ONLY${NC}"
fi

# GITLAB
if [ "${INSTALL_GITLAB}" = "true" ]; then
    echo ""
    echo "Creating GitLab configuration..."
    
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

# NGINX
echo ""
echo "Creating Nginx configuration..."

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

# DOCKER COMPOSE
echo ""
echo "Creating Docker Compose file..."

cat > docker-compose.yml << 'COMPOSE_HEADER'
services:
COMPOSE_HEADER

if [ "${INSTALL_GITLAB}" = "true" ]; then
    cat >> docker-compose.yml << EOF
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

EOF
fi

if [ "${INSTALL_OXIDIZED}" = "true" ]; then
    cat >> docker-compose.yml << EOF
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
EOF

    if [ "${INSTALL_GITLAB}" = "true" ]; then
        echo "      gitlabnet:" >> docker-compose.yml
    fi

    cat >> docker-compose.yml << EOF
    restart: unless-stopped
EOF

    if [ "${INSTALL_GITLAB}" = "true" ]; then
        cat >> docker-compose.yml << 'EOF'
    depends_on:
      gitlab-ce:
        condition: service_healthy
EOF
    fi

    cat >> docker-compose.yml << 'EOF'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888"]
      interval: 30s
      timeout: 10s
      start_period: 120s

EOF
fi

cat >> docker-compose.yml << EOF
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
EOF

[ "${INSTALL_OXIDIZED}" = "true" ] && echo "      oxinet:" >> docker-compose.yml
[ "${INSTALL_GITLAB}" = "true" ] && echo "      gitlabnet:" >> docker-compose.yml

cat >> docker-compose.yml << 'EOF'
    restart: unless-stopped
    depends_on:
EOF

[ "${INSTALL_OXIDIZED}" = "true" ] && cat >> docker-compose.yml << 'EOF'
      oxidized:
        condition: service_healthy
EOF

[ "${INSTALL_GITLAB}" = "true" ] && cat >> docker-compose.yml << 'EOF'
      gitlab-ce:
        condition: service_healthy
EOF

cat >> docker-compose.yml << 'EOF'

volumes:
EOF

[ "${INSTALL_OXIDIZED}" = "true" ] && cat >> docker-compose.yml << 'EOF'
  oxidized_data:
  oxidized_logs:
EOF

[ "${INSTALL_GITLAB}" = "true" ] && cat >> docker-compose.yml << 'EOF'
  gitlab_logs:
  gitlab_data:
EOF

cat >> docker-compose.yml << 'EOF'
  nginx_logs:

networks:
EOF

[ "${INSTALL_OXIDIZED}" = "true" ] && cat >> docker-compose.yml << 'EOF'
  oxinet:
    external: true
EOF

[ "${INSTALL_GITLAB}" = "true" ] && cat >> docker-compose.yml << 'EOF'
  gitlabnet:
    external: true
EOF

cat >> docker-compose.yml << 'EOF'
  nginxnet:
    external: true
EOF

echo -e "${GREEN}✅ Docker Compose created${NC}"

# ============================================================================
# CREATE UTILITY SCRIPTS
# ============================================================================
echo ""
echo "Creating utility scripts..."

# Trigger backup script
cat > scripts/trigger_backup.sh << 'TRIGGER'
#!/bin/bash
# Trigger immediate backup for device(s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

DEVICE=$1
OXIDIZED_API="http://localhost:${OXIDIZED_REST_PORT}"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 <device_ip|all>"
    echo ""
    echo "Examples:"
    echo "  $0 10.99.99.50    # Backup single device"
    echo "  $0 all            # Backup all devices"
    exit 1
fi

if [ "$DEVICE" = "all" ]; then
    echo "Triggering backup for ALL devices..."
    curl -X GET "${OXIDIZED_API}/reload?format=json" 2>/dev/null
    echo ""
    echo "✅ Reload triggered"
else
    echo "Triggering backup for: $DEVICE"
    curl -X GET "${OXIDIZED_API}/node/fetch/${DEVICE}?format=json" 2>/dev/null
    echo ""
    echo "✅ Backup triggered"
fi

echo ""
echo "Check logs: docker logs oxidized --tail 20"
TRIGGER

chmod +x scripts/trigger_backup.sh
echo -e "${GREEN}✅ Utility scripts created${NC}"

# ============================================================================
# CHECK IF CONTINUING AFTER REBOOT
# ============================================================================
if [ -f "$INSTALL_DIR/.reboot_required" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Detected reboot completion - continuing setup..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    rm -f "$INSTALL_DIR/.reboot_required"
    
    cd "$INSTALL_DIR"
    source config.env
    
    OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
    GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 2: Docker Network Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/02_setup_networks.sh
    
echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 3: Certificate Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/03_certificate_setup.sh
    
    # If existing mode, script 03 exits early and we call script 04
    if [ "$CERT_MODE" = "existing" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Step 4: Existing Certificate Handler"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ./scripts/04_existing_certificates.sh
        
        # After script 04 completes, install CA certs
        echo ""
        echo "Installing CA certificates on this server..."
        CA_DIR="$INSTALL_DIR/certificates/ca"
        if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
            sudo cp "$CA_DIR"/*.crt /usr/local/share/ca-certificates/
            sudo chmod 644 /usr/local/share/ca-certificates/*.crt
            sudo update-ca-certificates --fresh
            echo "✅ CA certificates installed on this server"
        else
            echo "ℹ️  No CA certificates to install"
        fi
    fi
    
    echo ""
    echo "✅ Certificate setup completed"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 5: Firewall Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/07_setup_firewall.sh
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 6: Building Docker Containers"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    docker compose build --no-cache
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 7: Starting Services"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    docker compose up -d
    
    echo ""
    echo "Waiting for services to start (60 seconds)..."
    sleep 60
    
    if [ "${INSTALL_GITLAB}" = "true" ] && [ "${INSTALL_OXIDIZED}" = "true" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Step 8: GitLab SSH Integration"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ./scripts/06_setup_ssh_and_gitlab.sh
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Final Step: Status Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/08_check_status.sh
    
    if [ -f "GENERATED_PASSWORDS.txt" ]; then
        echo ""
        echo "╔══════════════════════════════════════════════╗"
        echo "║     🔐 GENERATED PASSWORDS                  ║"
        echo "╚══════════════════════════════════════════════╝"
        echo ""
        cat GENERATED_PASSWORDS.txt
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  IMPORTANT SECURITY NOTICE:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 Saved in: $INSTALL_DIR/GENERATED_PASSWORDS.txt"
        echo ""
        echo "⚠️  PLEASE:"
        echo "   1. Save these passwords securely"
        echo "   2. Change them after first login"
        echo "   3. Delete GENERATED_PASSWORDS.txt after saving"
        echo ""
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     ✅ INSTALLATION COMPLETE!               ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "📁 Installation Directory: $INSTALL_DIR"
    echo "📋 Configuration Summary: $CONFIG_SUMMARY"
    echo ""
    echo "🌐 Services:"
    [ "${INSTALL_OXIDIZED}" = "true" ] && echo "  • Oxidized: https://${OXIDIZED_DOMAIN}"
    [ "${INSTALL_GITLAB}" = "true" ] && echo "  • GitLab: https://${GITLAB_DOMAIN}"
    echo ""
    if [ "${INSTALL_OXIDIZED}" = "true" ]; then
        echo "⚡ Oxidized Features:"
        echo "  • Fast backups every 5 minutes"
        echo "  • SSH-based push to GitLab"
        echo "  • Immediate trigger: ./scripts/trigger_backup.sh all"
        echo ""
    fi
    echo "✅ Setup completed: $(date)"
    echo ""
    
    exit 0
fi

# ============================================================================
# RUN AUTOMATED INSTALLATION
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     RUNNING AUTOMATED INSTALLATION           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Initial System Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo ./scripts/01_initial_setup.sh || EXIT_CODE=$?

if [ "${EXIT_CODE:-0}" -eq 99 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     ⚠️  REBOOT REQUIRED!                    ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Docker has been installed. System must reboot."
    echo ""
    echo "⚠️  AFTER REBOOT, simply run:"
    echo ""
    echo "  cd $INSTALL_DIR"
    echo "  sudo bash master_setup.sh"
    echo ""
    echo "The script will automatically continue."
    echo ""
    
    if [ -f "GENERATED_PASSWORDS.txt" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔐 SAVE THESE PASSWORDS BEFORE REBOOTING:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        cat GENERATED_PASSWORDS.txt
        echo ""
        echo "Passwords saved in: $INSTALL_DIR/GENERATED_PASSWORDS.txt"
        echo ""
    fi
    
    read -p "Reboot now? [Y/n]: " REBOOT_NOW
    REBOOT_NOW=${REBOOT_NOW:-Y}
    
    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        echo "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        echo ""
        echo "Please reboot manually, then run:"
        echo "  cd $INSTALL_DIR && sudo bash master_setup.sh"
    fi
    exit 0
fi

# Continue if no reboot needed
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Docker Network Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/02_setup_networks.sh

# ============================================================================
# CERTIFICATE SETUP SECTION - CLEAN FLOW
# Replace the certificate section in master_setup.sh with this
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Certificate Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/03_certificate_setup.sh

# If existing mode, script 03 exits early and we call script 04
if [ "$CERT_MODE" = "existing" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 4: Existing Certificate Handler"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/04_existing_certificates.sh
    
    # After script 04 completes, install CA certs
    echo ""
    echo "Installing CA certificates on this server..."
    CA_DIR="$INSTALL_DIR/certificates/ca"
    if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
        sudo cp "$CA_DIR"/*.crt /usr/local/share/ca-certificates/
        sudo chmod 644 /usr/local/share/ca-certificates/*.crt
        sudo update-ca-certificates --fresh
        echo "✅ CA certificates installed on this server"
    else
        echo "ℹ️  No CA certificates to install"
    fi
fi

echo ""
echo "✅ Certificate setup completed"

# Continue to firewall
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Firewall Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/07_setup_firewall.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Building Docker Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker compose build --no-cache

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Starting Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start GitLab first if both services are installed
if [ "${INSTALL_GITLAB}" = "true" ]; then
    echo "Starting GitLab (will take 3-5 minutes to initialize)..."
    docker compose up -d gitlab-ce nginx
    
    echo ""
    echo "Waiting for GitLab to be ready..."
    MAX_WAIT=300
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if docker inspect gitlab-ce --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            echo "✅ GitLab is healthy!"
            break
        fi
        sleep 10
        WAITED=$((WAITED + 10))
        if [ $((WAITED % 60)) -eq 0 ]; then
            echo "  Still waiting... ($WAITED/$MAX_WAIT seconds)"
        fi
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "⚠️  GitLab took longer than expected"
        echo "   Continuing anyway - you can check status later"
    fi
fi

# Now start Oxidized (or all services if GitLab not installed)
echo ""
echo "Starting all remaining services..."
docker compose up -d

echo ""
echo "Waiting for services to stabilize (30 seconds)..."
sleep 30

if [ "${INSTALL_GITLAB}" = "true" ] && [ "${INSTALL_OXIDIZED}" = "true" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 8: GitLab SSH Integration Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "Now configuring GitLab SSH integration..."
    echo "This requires manual configuration in GitLab web interface."
    echo ""
    
    # Run the GitLab SSH setup script
    ./scripts/06_setup_ssh_and_gitlab.sh
    
    echo ""
    echo "✅ GitLab SSH integration configured!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Final Step: Status Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/08_check_status.sh

# ============================================================================
# DISPLAY GENERATED PASSWORDS
# ============================================================================
if [ -f "GENERATED_PASSWORDS.txt" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     🔐 GENERATED PASSWORDS                  ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    cat GENERATED_PASSWORDS.txt
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  IMPORTANT SECURITY NOTICE:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 Saved in: $INSTALL_DIR/GENERATED_PASSWORDS.txt"
    echo ""
    echo "⚠️  PLEASE:"
    echo "   1. Save these passwords in a secure location"
    echo "   2. Use a password manager (recommended)"
    echo "   3. Change passwords after first login"
    echo "   4. Delete GENERATED_PASSWORDS.txt after saving"
    echo ""
    echo "🔒 To change passwords later:"
    [ "${INSTALL_GITLAB}" = "true" ] && echo "   • GitLab: https://${GITLAB_DOMAIN}/admin"
    [ "${INSTALL_OXIDIZED}" = "true" ] && echo "   • Devices: Edit config.env and rebuild"
    echo ""
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     ✅ INSTALLATION COMPLETE!               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📁 Installation Directory: $INSTALL_DIR"
echo "📋 Setup Log: $SETUP_LOG"
echo "📋 Configuration Summary: $CONFIG_SUMMARY"
echo ""
echo "🌐 Services:"
[ "${INSTALL_OXIDIZED}" = "true" ] && echo "  • Oxidized: https://${OXIDIZED_DOMAIN}"
[ "${INSTALL_GITLAB}" = "true" ] && echo "  • GitLab: https://${GITLAB_DOMAIN}"
echo ""
if [ "${INSTALL_OXIDIZED}" = "true" ]; then
    echo "⚡ Oxidized Features (SSH-based):"
    echo "  • Fast backups every 5 minutes"
    echo "  • SSH Deploy Key authentication"
    echo "  • Immediate trigger: ./scripts/trigger_backup.sh all"
    echo ""
fi
echo "📊 Next Steps:"
echo "  • Check status: ./scripts/08_check_status.sh"
echo "  • View logs: docker compose logs -f"
echo "  • Backup: ./scripts/09_backup.sh"
[ "${INSTALL_OXIDIZED}" = "true" ] && echo "  • Trigger backup: ./scripts/trigger_backup.sh all"
echo ""
if [ -f "GENERATED_PASSWORDS.txt" ]; then
    echo "🔐 Security:"
    echo "  • Review passwords: cat GENERATED_PASSWORDS.txt"
    echo "  • Change them after first login!"
    echo "  • Delete password file after saving securely"
    echo ""
fi
echo "✅ Setup completed: $(date)"
echo ""