# ============================================================================
# FILE: 04_generate_csr.sh (optional - only for existing cert mode)
# ============================================================================
#!/bin/bash
DOMAIN=$1
[ -z "$DOMAIN" ] && echo "Usage: $0 <domain>" && exit 1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
LOG_FILE="${LOG_DIR}/04_csr_${DOMAIN}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "04 - Generate CSR for $DOMAIN"
echo "=========================================="

CERT_DIR="$SCRIPT_DIR/../certificates/ssl"
CSR_DIR="$SCRIPT_DIR/../certificates/csr"
mkdir -p "$CERT_DIR" "$CSR_DIR"

openssl genrsa -out "$CERT_DIR/$DOMAIN.key" ${CERT_KEY_SIZE}
chmod 600 "$CERT_DIR/$DOMAIN.key"

openssl req -new -key "$CERT_DIR/$DOMAIN.key" -out "$CSR_DIR/$DOMAIN.csr" \
    -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/CN=$DOMAIN"

echo "📋 CSR created:"
cat "$CSR_DIR/$DOMAIN.csr"
echo ""
echo "Submit to your CA for signing"
echo "📋 Log: $LOG_FILE"