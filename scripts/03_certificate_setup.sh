# ============================================================================
# FILE: 03_certificate_setup.sh
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
LOG_FILE="${LOG_DIR}/03_certificates_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "03 - Certificate Setup"
echo "Mode: ${CERT_MODE}"
echo "=========================================="

CERT_DIR="$SCRIPT_DIR/../certificates/ssl"
CA_DIR="$SCRIPT_DIR/../certificates/ca"
SELFSIGNED_DIR="$SCRIPT_DIR/../certificates/selfsigned"

case "${CERT_MODE}" in
    selfsigned)
        echo "Generating self-signed certificates..."
        
        if [ ! -f "$SELFSIGNED_DIR/ca.key" ]; then
            mkdir -p "$SELFSIGNED_DIR"
            openssl genrsa -out "$SELFSIGNED_DIR/ca.key" 4096
            chmod 600 "$SELFSIGNED_DIR/ca.key"
            openssl req -new -x509 -days 3650 -key "$SELFSIGNED_DIR/ca.key" \
                -out "$SELFSIGNED_DIR/ca.crt" \
                -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/CN=${ORG_NAME} Root CA"
            cp "$SELFSIGNED_DIR/ca.crt" "$CA_DIR/${ORG_NAME}-SelfSigned-CA.crt"
            echo "✅ Root CA created"
        fi
        
        DOMAINS=()
        [ "${INSTALL_OXIDIZED}" = "true" ] && DOMAINS+=("${OXIDIZED_DOMAIN}")
        [ "${INSTALL_GITLAB}" = "true" ] && DOMAINS+=("${GITLAB_DOMAIN}")
        
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "Generating certificate for: $DOMAIN_NAME"
            openssl genrsa -out "$CERT_DIR/$DOMAIN_NAME.key" ${CERT_KEY_SIZE}
            chmod 600 "$CERT_DIR/$DOMAIN_NAME.key"
            openssl req -new -key "$CERT_DIR/$DOMAIN_NAME.key" \
                -out "$SELFSIGNED_DIR/$DOMAIN_NAME.csr" \
                -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/CN=$DOMAIN_NAME"
            openssl x509 -req -days 365 \
                -in "$SELFSIGNED_DIR/$DOMAIN_NAME.csr" \
                -CA "$SELFSIGNED_DIR/ca.crt" \
                -CAkey "$SELFSIGNED_DIR/ca.key" \
                -CAcreateserial \
                -out "$CERT_DIR/$DOMAIN_NAME.crt" \
                -extfile <(echo "subjectAltName=DNS:$DOMAIN_NAME")
            chmod 644 "$CERT_DIR/$DOMAIN_NAME.crt"
            echo "✅ Certificate created for $DOMAIN_NAME"
        done
        
        echo "⚠️  CA Location: $CA_DIR/${ORG_NAME}-SelfSigned-CA.crt"
        ;;
        
    existing)
        echo "Mode: Existing Certificates"
        DOMAINS=()
        [ "${INSTALL_OXIDIZED}" = "true" ] && DOMAINS+=("${OXIDIZED_DOMAIN}")
        [ "${INSTALL_GITLAB}" = "true" ] && DOMAINS+=("${GITLAB_DOMAIN}")
        
        MISSING=0
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "Checking: $DOMAIN_NAME"
            [ -f "$CERT_DIR/$DOMAIN_NAME.cer" ] && [ ! -f "$CERT_DIR/$DOMAIN_NAME.crt" ] && cp "$CERT_DIR/$DOMAIN_NAME.cer" "$CERT_DIR/$DOMAIN_NAME.crt"
            [ ! -f "$CERT_DIR/$DOMAIN_NAME.crt" ] && echo "  ❌ Certificate missing" && MISSING=1 || echo "  ✅ Certificate found"
            [ ! -f "$CERT_DIR/$DOMAIN_NAME.key" ] && echo "  ❌ Key missing" && MISSING=1 || echo "  ✅ Key found"
        done
        
        [ $MISSING -eq 1 ] && echo "❌ Missing certificates!" && exit 1
        ;;
esac

echo "Installing CA certificates..."
if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
    sudo cp "$CA_DIR"/*.crt /usr/local/share/ca-certificates/
    sudo chmod 644 /usr/local/share/ca-certificates/*.crt
    sudo update-ca-certificates --fresh
    echo "✅ CA certificates installed"
fi

echo "✅ Certificate setup completed"
echo "📋 Log: $LOG_FILE"