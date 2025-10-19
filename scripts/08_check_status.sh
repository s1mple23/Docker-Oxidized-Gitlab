# ============================================================================
# FILE: 08_check_status.sh
# ============================================================================
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env" 2>/dev/null || true

echo "=========================================="
echo "Infrastructure Status"
echo "=========================================="

echo "📦 Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null

echo ""
echo "🏥 Health:"
for c in $(docker ps --format "{{.Names}}" 2>/dev/null); do
    printf "%-20s %s\n" "$c:" "$(docker inspect --format='{{.State.Health.Status}}' $c 2>/dev/null || echo 'no check')"
done

echo ""
echo "🌐 Networks:"
docker network ls 2>/dev/null | grep -E "NETWORK|oxinet|gitlabnet|nginxnet"

echo ""
echo "📁 Recent backups:"
docker exec oxidized bash -c "cd /opt/oxidized/devices.git 2>/dev/null && git log --oneline -5" 2>/dev/null || echo "No backups yet"