# ============================================================================
# FILE: 04_existing_certificates.sh (Complete handler for existing cert mode)
# ============================================================================
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
OXIDIZED_DOMAIN=$(eval echo "${OXIDIZED_DOMAIN}")
GITLAB_DOMAIN=$(eval echo "${GITLAB_DOMAIN}")
LOG_FILE="${LOG_DIR}/04_existing_certs_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "04 - Existing Certificates Handler"
echo "=========================================="

CERT_DIR="$SCRIPT_DIR/../certificates/ssl"
CA_DIR="$SCRIPT_DIR/../certificates/ca"
CSR_DIR="$SCRIPT_DIR/../certificates/csr"

# Build domain list
DOMAINS=()
[ "${INSTALL_OXIDIZED}" = "true" ] && DOMAINS+=("${OXIDIZED_DOMAIN}")
[ "${INSTALL_GITLAB}" = "true" ] && DOMAINS+=("${GITLAB_DOMAIN}")

echo ""
echo "Domains to configure:"
for DOMAIN_NAME in "${DOMAINS[@]}"; do
    echo "  • $DOMAIN_NAME"
done
echo ""

# ============================================================================
# STEP 1: Check if CSR generation is needed
# ============================================================================
NEED_CSR=false
for DOMAIN_NAME in "${DOMAINS[@]}"; do
    if [ ! -f "$CERT_DIR/$DOMAIN_NAME.crt" ] && [ ! -f "$CERT_DIR/$DOMAIN_NAME.cer" ]; then
        NEED_CSR=true
        break
    fi
done

if [ "$NEED_CSR" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "No certificates found. CSR generation recommended."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Would you like to generate Certificate Signing Requests (CSRs)?"
    echo "You can then submit these to your Certificate Authority."
    echo ""
    read -p "Generate CSRs now? [Y/n]: " GENERATE_CSR
    GENERATE_CSR=${GENERATE_CSR:-Y}
    
    if [[ "$GENERATE_CSR" =~ ^[Yy]$ ]]; then
        # ============================================================================
        # STEP 2: Generate CSRs
        # ============================================================================
        echo ""
        echo "Generating CSRs for all domains..."
        mkdir -p "$CSR_DIR"
        
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Generating CSR for: $DOMAIN_NAME"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Generate private key if not exists
            if [ ! -f "$CERT_DIR/$DOMAIN_NAME.key" ]; then
                openssl genrsa -out "$CERT_DIR/$DOMAIN_NAME.key" ${CERT_KEY_SIZE}
                chmod 600 "$CERT_DIR/$DOMAIN_NAME.key"
                echo "✅ Private key generated: $CERT_DIR/$DOMAIN_NAME.key"
            else
                echo "✅ Private key already exists: $CERT_DIR/$DOMAIN_NAME.key"
            fi
            
            # Generate SAN configuration file
            echo "Creating SAN configuration..."
            cat > "/tmp/san_${DOMAIN_NAME}.cnf" << 'SANEOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CERT_COUNTRY_PLACEHOLDER
ST = CERT_STATE_PLACEHOLDER
L = CERT_CITY_PLACEHOLDER
O = ORG_NAME_PLACEHOLDER
CN = DOMAIN_NAME_PLACEHOLDER

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = DOMAIN_NAME_PLACEHOLDER
SANEOF

            # Replace placeholders
            sed -i "s/CERT_COUNTRY_PLACEHOLDER/${CERT_COUNTRY}/g" "/tmp/san_${DOMAIN_NAME}.cnf"
            sed -i "s/CERT_STATE_PLACEHOLDER/${CERT_STATE}/g" "/tmp/san_${DOMAIN_NAME}.cnf"
            sed -i "s/CERT_CITY_PLACEHOLDER/${CERT_CITY}/g" "/tmp/san_${DOMAIN_NAME}.cnf"
            sed -i "s/ORG_NAME_PLACEHOLDER/${ORG_NAME}/g" "/tmp/san_${DOMAIN_NAME}.cnf"
            sed -i "s/DOMAIN_NAME_PLACEHOLDER/${DOMAIN_NAME}/g" "/tmp/san_${DOMAIN_NAME}.cnf"

            # Generate CSR with SAN
            openssl req -new -key "$CERT_DIR/$DOMAIN_NAME.key" \
                -out "$CSR_DIR/$DOMAIN_NAME.csr" \
                -config "/tmp/san_${DOMAIN_NAME}.cnf"
            
            # Cleanup temp file
            rm "/tmp/san_${DOMAIN_NAME}.cnf"
            
            echo "✅ CSR with SAN generated: $CSR_DIR/$DOMAIN_NAME.csr"
            
            # Verify SAN in CSR
            echo ""
            echo "Verifying SAN in CSR:"
            openssl req -in "$CSR_DIR/$DOMAIN_NAME.csr" -noout -text | grep -A 2 "Subject Alternative Name" || echo "  ⚠️  No SAN found in CSR"
            
            echo ""
            echo "CSR Content (submit this to your CA):"
            echo "────────────────────────────────────────────────────────────────"
            cat "$CSR_DIR/$DOMAIN_NAME.csr"
            echo "────────────────────────────────────────────────────────────────"
            echo ""
        done
        
        # ============================================================================
        # STEP 3: Show instructions
        # ============================================================================
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                                                                  ║"
        echo "║              CSR GENERATION COMPLETE                             ║"
        echo "║                                                                  ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "📁 CSR Files Location:"
        echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "   Directory: $CSR_DIR"
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "   - $DOMAIN_NAME.csr"
        done
        echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📋 Next Steps:"
        echo ""
        echo "   1️⃣  Submit CSRs to your Certificate Authority (CA)"
        echo ""
        echo "      Windows CA Web Interface:"
        echo "      ──────────────────────────"
        echo "      • Open: https://your-ca-server/certsrv"
        echo "      • Select: Request a certificate → Advanced certificate request"
        echo "      • Paste CSR content from above"
        echo "      • Select template: Web Server"
        echo "      • Submit and download certificate"
        echo ""
        echo "      Windows CA Command Line:"
        echo "      ────────────────────────"
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "      • certreq -submit -attrib \"CertificateTemplate:WebServer\" $CSR_DIR/$DOMAIN_NAME.csr"
        done
        echo ""
        echo "   2️⃣  Save signed DOMAIN certificates to:"
        echo ""
        echo "      Directory: $CERT_DIR/"
        echo "      ──────────────────────────────────────────"
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "      • $DOMAIN_NAME.crt (or .cer - will be auto-converted)"
        done
        echo ""
        echo "   3️⃣  IMPORTANT: Copy CA certificate(s):"
        echo ""
        echo "      Directory: $CA_DIR/"
        echo "      ──────────────────────────────────────────"
        echo "      • YourCompany-Root-CA.crt (your CA's root certificate)"
        echo "      • Intermediate-CA.crt (if you have intermediate CA)"
        echo ""
        echo "      📌 Why CA certificates are needed:"
        echo "         • SSL/TLS chain validation"
        echo "         • Installed on this server automatically"
        echo "         • Can be distributed to client machines"
        echo "         • Required for proper trust establishment"
        echo ""
        echo "      💡 How to get CA certificate from Windows CA:"
        echo "         • Open: https://your-ca-server/certsrv"
        echo "         • Click: Download a CA certificate"
        echo "         • Save as: YourCompany-Root-CA.cer"
        echo "         • Copy to: $CA_DIR/"
        echo ""
        echo "   4️⃣  (Optional) Concatenate intermediate certificate if needed:"
        echo ""
        echo "      If your CA provides an intermediate certificate:"
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "      cat $DOMAIN_NAME.crt intermediate.crt > $DOMAIN_NAME.crt"
        done
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 Summary - Files needed:"
        echo ""
        echo "   Domain Certificates: $CERT_DIR/"
        for DOMAIN_NAME in "${DOMAINS[@]}"; do
            echo "      ✓ $DOMAIN_NAME.key (already generated)"
            echo "      ⚠ $DOMAIN_NAME.crt (waiting for CA)"
        done
        echo ""
        echo "   CA Certificates: $CA_DIR/"
        echo "      ⚠ YourCompany-Root-CA.crt (get from CA)"
        echo "      ⚠ Intermediate-CA.crt (if applicable)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "Press ENTER when you have placed ALL certificates (domain + CA) in their directories..."
        echo ""
    else
        echo ""
        echo "⏭️  Skipping CSR generation."
        echo ""
        echo "Please ensure certificates are already placed in:"
        echo "  • Domain certificates: $CERT_DIR/"
        echo "  • CA certificates: $CA_DIR/"
        echo ""
        read -p "Press ENTER when certificates are ready..."
    fi
fi

# ============================================================================
# STEP 4: Verify domain certificates exist
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verifying Domain Certificates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MISSING=0
for DOMAIN_NAME in "${DOMAINS[@]}"; do
    echo ""
    echo "Checking: $DOMAIN_NAME"
    
    # Auto-convert .cer to .crt if needed
    if [ -f "$CERT_DIR/$DOMAIN_NAME.cer" ] && [ ! -f "$CERT_DIR/$DOMAIN_NAME.crt" ]; then
        cp "$CERT_DIR/$DOMAIN_NAME.cer" "$CERT_DIR/$DOMAIN_NAME.crt"
        echo "  ℹ️  Converted .cer to .crt"
    fi
    
    if [ ! -f "$CERT_DIR/$DOMAIN_NAME.crt" ]; then
        echo "  ❌ Certificate missing: $CERT_DIR/$DOMAIN_NAME.crt"
        MISSING=1
    else
        echo "  ✅ Certificate found"
    fi
    
    if [ ! -f "$CERT_DIR/$DOMAIN_NAME.key" ]; then
        echo "  ❌ Key missing: $CERT_DIR/$DOMAIN_NAME.key"
        MISSING=1
    else
        echo "  ✅ Key found"
    fi
done

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "❌ Missing certificates or keys!"
    echo ""
    echo "Required files:"
    for DOMAIN_NAME in "${DOMAINS[@]}"; do
        echo "  • $CERT_DIR/$DOMAIN_NAME.crt"
        echo "  • $CERT_DIR/$DOMAIN_NAME.key"
    done
    echo ""
    exit 1
fi

# ============================================================================
# STEP 5: Verify certificate-key pairs match
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verifying Certificate-Key Pairs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MISMATCH=0
for DOMAIN_NAME in "${DOMAINS[@]}"; do
    CERT_MD5=$(openssl x509 -noout -modulus -in "$CERT_DIR/$DOMAIN_NAME.crt" 2>/dev/null | openssl md5)
    KEY_MD5=$(openssl rsa -noout -modulus -in "$CERT_DIR/$DOMAIN_NAME.key" 2>/dev/null | openssl md5)
    
    if [ "$CERT_MD5" = "$KEY_MD5" ]; then
        echo "  ✅ $DOMAIN_NAME: Certificate and key match"
    else
        echo "  ❌ $DOMAIN_NAME: Certificate and key DO NOT match!"
        MISMATCH=1
    fi
done

if [ $MISMATCH -eq 1 ]; then
    echo ""
    echo "❌ Certificate-key mismatch detected!"
    echo "   The certificate was not signed from the generated CSR,"
    echo "   or you're using a different private key."
    echo ""
    echo "   Solutions:"
    echo "   1. Request a new certificate using the generated CSR"
    echo "   2. Or provide both certificate AND matching private key"
    echo ""
    exit 1
fi

echo ""
echo "✅ All domain certificates verified successfully"

# ============================================================================
# STEP 6: Check CA certificates
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CA Certificates Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
    echo ""
    echo "✅ CA certificates found in: $CA_DIR/"
    ls -1 "$CA_DIR"/*.crt 2>/dev/null | while read ca_file; do
        echo "   • $(basename "$ca_file")"
    done
    echo ""
    echo "These will be:"
    echo "  • Installed on this server automatically (by script 03)"
    echo "  • Available for distribution to client machines"
    echo "  • Used for SSL/TLS chain validation"
    echo ""
else
    echo ""
    echo "⚠️  WARNING: No CA certificates found in: $CA_DIR/"
    echo ""
    echo "If your certificates were issued by an internal CA,"
    echo "you should copy the CA certificate(s) now."
    echo ""
    echo "Benefits of CA certificates:"
    echo "  • Proper SSL/TLS chain validation"
    echo "  • Distribution to client machines to avoid browser warnings"
    echo "  • Trust establishment for internal certificates"
    echo ""
    echo "How to add CA certificates:"
    echo "  • Copy YourCompany-Root-CA.crt to: $CA_DIR/"
    echo "  • Then re-run script 03: ./scripts/03_certificate_setup.sh"
    echo ""
    read -p "Continue without CA certificates? [y/N]: " CONTINUE_NO_CA
    CONTINUE_NO_CA=${CONTINUE_NO_CA:-N}
    
    if [[ ! "$CONTINUE_NO_CA" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Please add CA certificates and re-run this script."
        exit 1
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║         EXISTING CERTIFICATES SETUP COMPLETE                     ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Domain certificates: Ready"
echo "✅ Certificate-key pairs: Verified"
if [ -n "$(ls -A $CA_DIR/*.crt 2>/dev/null)" ]; then
    echo "✅ CA certificates: Ready"
else
    echo "⚠️  CA certificates: Not provided"
fi
echo ""
echo "📋 Log: $LOG_FILE"
echo ""