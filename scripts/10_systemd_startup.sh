#!/bin/bash
# scripts/10_systemd_startup.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# Only create systemd service if BOTH services are installed
if [ "${INSTALL_OXIDIZED}" != "true" ] || [ "${INSTALL_GITLAB}" != "true" ]; then
    echo "⏭️  Systemd startup service skipped"
    echo "   (only needed when both Oxidized AND GitLab are installed)"
    exit 0
fi

echo "Creating systemd service for Docker Compose startup order..."

sudo tee /etc/systemd/system/docker-infrastructure.service > /dev/null << EOF
[Unit]
Description=Docker Infrastructure Startup (Oxidized + GitLab)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStartPre=/usr/bin/sleep 10
# Start GitLab and Nginx first
ExecStart=/usr/bin/docker compose up -d gitlab-ce nginx
# Wait for GitLab to be healthy
ExecStart=/usr/bin/sleep 120
# Then start Oxidized
ExecStart=/usr/bin/docker compose up -d oxidized

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable docker-infrastructure.service

echo "✅ Systemd service created and enabled"
echo "   Ensures proper startup order: GitLab → Oxidized"