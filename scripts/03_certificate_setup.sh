#!/bin/bash
# ============================================================================
# FILE: 03_certificate_setup.sh (FIXED - Uses ORG_NAME)
# ============================================================================
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
            # FIXED: Use ORG_NAME instead of CERT_ORG
            openssl req -new -x509 -days 3650 -key "$SELFSIGNED_DIR/ca.key" \
                -out "$SELFSIGNED_DIR/ca.crt" \
                -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${ORG_NAME}/CN=${ORG_NAME} Root CA"
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
            # FIXED: Use ORG_NAME instead of CERT_ORG
            openssl req -new -key "$CERT_DIR/$DOMAIN_NAME.key" \
                -out "$SELFSIGNED_DIR/$DOMAIN_NAME.csr" \
                -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${ORG_NAME}/CN=$DOMAIN_NAME"
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
        
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                                                                  ║"
        echo "║           SELF-SIGNED ROOT CA CERTIFICATE                        ║"
        echo "║                                                                  ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "⚠️  IMPORTANT: To avoid browser security warnings, you must install"
        echo "    the Root CA certificate on all client machines."
        echo ""
        echo "📁 Root CA Certificate Location:"
        echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "   File: $CA_DIR/${ORG_NAME}-SelfSigned-CA.crt"
        echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📋 How to install the Root CA on different systems:"
        echo ""
        echo "   Windows:"
        echo "   ────────"
        echo "   1. Copy ${ORG_NAME}-SelfSigned-CA.crt to your Windows PC"
        echo "   2. Double-click the .crt file"
        echo "   3. Click 'Install Certificate...'"
        echo "   4. Select 'Local Machine' → Next"
        echo "   5. Select 'Place all certificates in the following store'"
        echo "   6. Click 'Browse' → Select 'Trusted Root Certification Authorities'"
        echo "   7. Click 'Next' → 'Finish'"
        echo ""
        echo "   Linux (Ubuntu/Debian):"
        echo "   ──────────────────────"
        echo "   sudo cp ${ORG_NAME}-SelfSigned-CA.crt /usr/local/share/ca-certificates/"
        echo "   sudo update-ca-certificates"
        echo ""
        echo "   macOS:"
        echo "   ──────"
        echo "   1. Double-click the .crt file"
        echo "   2. Keychain Access opens"
        echo "   3. Select 'System' keychain"
        echo "   4. Double-click the imported certificate"
        echo "   5. Expand 'Trust' section"
        echo "   6. Set 'When using this certificate' to 'Always Trust'"
        echo ""
        echo "   Firefox (all platforms):"
        echo "   ────────────────────────"
        echo "   1. Settings → Privacy & Security → Certificates → View Certificates"
        echo "   2. Authorities tab → Import"
        echo "   3. Select ${ORG_NAME}-SelfSigned-CA.crt"
        echo "   4. Check 'Trust this CA to identify websites'"
        echo ""
        echo "   Chrome/Edge use system certificate store (Windows/macOS method)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "💡 Tip: You can copy the CA certificate using:"
        echo "   scp $CA_DIR/${ORG_NAME}-SelfSigned-CA.crt user@client-pc:~/"
        echo ""
        ;;
        
    existing)
        echo "Mode: Existing Certificates"
        echo ""
        echo "⏭️  Delegating to Script 04 for existing certificate handling..."
        echo ""
        
        # Script 04 will handle:
        # - CSR generation (if needed)
        # - Certificate placement instructions
        # - Verification
        # - CA certificate handling
        
        exit 0
        ;;
esac

echo ""
echo "Installing CA certificates..."
if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
    sudo cp "$CA_DIR"/*.crt /usr/local/share/ca-certificates/
    sudo chmod 644 /usr/local/share/ca-certificates/*.crt
    sudo update-ca-certificates --fresh
    echo "✅ CA certificates installed on this server"
fi

echo ""
echo "✅ Certificate setup completed"
echo "📋 Log: $LOG_FILE"