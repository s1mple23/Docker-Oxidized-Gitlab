# ============================================================================
# FILE: backup.sh
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
BACKUP_DIR="${BACKUP_DIR}/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/backup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "Backup Started"
echo "=========================================="

mkdir -p "$BACKUP_DIR"

[ "${INSTALL_OXIDIZED}" = "true" ] && docker run --rm -v oxidized_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/oxidized_data.tar.gz -C /data .
[ "${INSTALL_GITLAB}" = "true" ] && docker run --rm -v gitlab_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/gitlab_data.tar.gz -C /data .

cp -r "${INSTALL_DIR}/nginx" "$BACKUP_DIR/"
cp "${INSTALL_DIR}/docker-compose.yml" "$BACKUP_DIR/"

echo "✅ Backup complete: $BACKUP_DIR"
echo "📋 Log: $LOG_FILE"