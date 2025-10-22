# ============================================================================
# FILE: 07_setup_firewall.sh
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
LOG_FILE="${LOG_DIR}/07_firewall_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "07 - Firewall Configuration"
echo "=========================================="

[ "$UFW_ENABLED" != "true" ] && echo "⏭️  Skipped" && exit 0

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ${SSH_PORT}/tcp comment "SSH"
sudo ufw allow ${NGINX_HTTP_PORT}/tcp comment "HTTP"
sudo ufw allow ${NGINX_HTTPS_PORT}/tcp comment "HTTPS"
[ "${INSTALL_GITLAB}" = "true" ] && sudo ufw allow ${GITLAB_SSH_PORT}/tcp comment "GitLab SSH"
sudo ufw --force enable

echo "✅ Firewall configured"
sudo ufw status verbose
echo "📋 Log: $LOG_FILE"