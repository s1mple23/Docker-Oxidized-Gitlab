# ============================================================================
# FILE: 05_verify_certificates.sh
# ============================================================================
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
LOG_FILE="${LOG_DIR}/05_cert_verify_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "05 - Certificate Verification"
echo "=========================================="

CERT_DIR="$SCRIPT_DIR/../certificates/ssl"
all_ok=true

DOMAINS=()
[ "${INSTALL_OXIDIZED}" = "true" ] && DOMAINS+=("${OXIDIZED_DOMAIN}")
[ "${INSTALL_GITLAB}" = "true" ] && DOMAINS+=("${GITLAB_DOMAIN}")

for domain in "${DOMAINS[@]}"; do
    echo "Checking: $domain"
    if [ -f "$CERT_DIR/$domain.crt" ] && [ -f "$CERT_DIR/$domain.key" ]; then
        CERT_MD5=$(openssl x509 -noout -modulus -in "$CERT_DIR/$domain.crt" 2>/dev/null | openssl md5)
        KEY_MD5=$(openssl rsa -noout -modulus -in "$CERT_DIR/$domain.key" 2>/dev/null | openssl md5)
        [ "$CERT_MD5" = "$KEY_MD5" ] && echo "  ✅ Match" || echo "  ❌ Mismatch"
    else
        echo "  ❌ Missing files"
        all_ok=false
    fi
done

[ "$all_ok" = true ] && echo "✅ All checks passed" || echo "❌ Some checks failed"
echo "📋 Log: $LOG_FILE"