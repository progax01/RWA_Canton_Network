#!/bin/bash

# Canton Certificate Verification Script
# This script verifies TLS certificates are properly configured and accessible
# for Canton participant and domain nodes.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TLS_DIR="${TLS_DIR:-config/tls}"
CONFIG_FILE="${CONFIG_FILE:-config/canton-single-participant.conf}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verifies TLS certificates for Canton deployment.

Environment Variables:
  TLS_DIR          Directory containing TLS certificates (default: config/tls)
  CONFIG_FILE      Canton configuration file (default: config/canton-single-participant.conf)

Options:
  -h, --help       Show this help message
  -g, --generate   Generate test certificates if missing
  -v, --verbose    Show detailed certificate information
  --check-expiry   Check certificate expiration dates

Examples:
  # Basic certificate verification
  ./verify-certificates.sh

  # Generate test certificates if missing
  ./verify-certificates.sh --generate

  # Verbose output with expiration check
  ./verify-certificates.sh --verbose --check-expiry
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if openssl is installed
    if ! command -v openssl &> /dev/null; then
        log_error "openssl is not installed. Please install OpenSSL."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

extract_cert_paths() {
    log_info "Extracting certificate paths from configuration..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Extract certificate paths from HOCON config using basic text processing
    # This is a simplified approach - in production you might want to use a proper HOCON parser
    
    PARTICIPANT_CERT=""
    PARTICIPANT_KEY=""
    DOMAIN_CERT=""
    DOMAIN_KEY=""
    ROOT_CA=""
    
    # Look for certificate files in config
    while IFS= read -r line; do
        # Remove comments and trim whitespace
        clean_line=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        if [[ "$clean_line" == *"participant-cert-chain.crt"* ]]; then
            PARTICIPANT_CERT="$TLS_DIR/participant-cert-chain.crt"
        elif [[ "$clean_line" == *"participant-key.pem"* ]]; then
            PARTICIPANT_KEY="$TLS_DIR/participant-key.pem"
        elif [[ "$clean_line" == *"domain-cert-chain.crt"* ]]; then
            DOMAIN_CERT="$TLS_DIR/domain-cert-chain.crt"
        elif [[ "$clean_line" == *"domain-key.pem"* ]]; then
            DOMAIN_KEY="$TLS_DIR/domain-key.pem"
        elif [[ "$clean_line" == *"root-ca.crt"* ]]; then
            ROOT_CA="$TLS_DIR/root-ca.crt"
        fi
    done < "$CONFIG_FILE"
    
    # Set default paths if not found in config
    PARTICIPANT_CERT="${PARTICIPANT_CERT:-$TLS_DIR/participant-cert-chain.crt}"
    PARTICIPANT_KEY="${PARTICIPANT_KEY:-$TLS_DIR/participant-key.pem}"
    DOMAIN_CERT="${DOMAIN_CERT:-$TLS_DIR/domain-cert-chain.crt}"
    DOMAIN_KEY="${DOMAIN_KEY:-$TLS_DIR/domain-key.pem}"
    ROOT_CA="${ROOT_CA:-$TLS_DIR/root-ca.crt}"
    
    log_success "Certificate paths extracted"
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "  Participant Cert: $PARTICIPANT_CERT"
        echo "  Participant Key:  $PARTICIPANT_KEY"
        echo "  Domain Cert:      $DOMAIN_CERT"
        echo "  Domain Key:       $DOMAIN_KEY"
        echo "  Root CA:          $ROOT_CA"
    fi
}

check_file_exists() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_success "$description found: $file"
        return 0
    else
        log_error "$description not found: $file"
        return 1
    fi
}

check_file_permissions() {
    local file="$1"
    local description="$2"
    
    if [[ ! -r "$file" ]]; then
        log_error "$description is not readable: $file"
        return 1
    fi
    
    # Check if private key files have appropriate permissions (should not be world-readable)
    if [[ "$file" == *"key.pem" ]]; then
        local perms=$(stat -c "%a" "$file")
        if [[ "$perms" != "600" && "$perms" != "400" ]]; then
            log_warn "$description has permissive permissions ($perms). Recommended: 600 or 400"
        else
            log_success "$description has appropriate permissions ($perms)"
        fi
    fi
    
    return 0
}

verify_certificate() {
    local cert_file="$1"
    local key_file="$2"
    local description="$3"
    
    log_info "Verifying $description..."
    
    # Check if certificate file is valid
    if ! openssl x509 -in "$cert_file" -noout -text > /dev/null 2>&1; then
        log_error "$description certificate is not valid: $cert_file"
        return 1
    fi
    
    # Check if private key is valid
    if ! openssl rsa -in "$key_file" -check -noout > /dev/null 2>&1; then
        log_error "$description private key is not valid: $key_file"
        return 1
    fi
    
    # Check if certificate and private key match
    cert_modulus=$(openssl x509 -noout -modulus -in "$cert_file" 2>/dev/null | openssl md5 2>/dev/null)
    key_modulus=$(openssl rsa -noout -modulus -in "$key_file" 2>/dev/null | openssl md5 2>/dev/null)
    
    if [[ "$cert_modulus" != "$key_modulus" ]]; then
        log_error "$description certificate and private key do not match"
        return 1
    fi
    
    log_success "$description certificate and key are valid and match"
    
    # Show certificate details if verbose
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "  Subject: $(openssl x509 -noout -subject -in "$cert_file" | sed 's/subject=//')"
        echo "  Issuer:  $(openssl x509 -noout -issuer -in "$cert_file" | sed 's/issuer=//')"
        echo "  Serial:  $(openssl x509 -noout -serial -in "$cert_file" | sed 's/serial=//')"
        
        # Show SAN (Subject Alternative Names)
        local san=$(openssl x509 -noout -ext subjectAltName -in "$cert_file" 2>/dev/null | grep -v "X509v3 Subject Alternative Name" || true)
        if [[ -n "$san" ]]; then
            echo "  SAN:     $(echo "$san" | tr -d ' ')"
        fi
    fi
    
    return 0
}

check_certificate_expiry() {
    local cert_file="$1"
    local description="$2"
    
    if [[ "${CHECK_EXPIRY:-false}" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking expiry for $description..."
    
    # Get certificate expiry date
    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | sed 's/notAfter=//')
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $expiry_epoch -eq 0 ]]; then
        log_warn "Could not parse expiry date for $description"
        return 0
    fi
    
    if [[ $days_until_expiry -lt 0 ]]; then
        log_error "$description certificate has expired ($expiry_date)"
        return 1
    elif [[ $days_until_expiry -lt 30 ]]; then
        log_warn "$description certificate expires soon: $expiry_date ($days_until_expiry days)"
    else
        log_success "$description certificate expires in $days_until_expiry days ($expiry_date)"
    fi
    
    return 0
}

verify_ca_certificate() {
    log_info "Verifying Root CA certificate..."
    
    if ! openssl x509 -in "$ROOT_CA" -noout -text > /dev/null 2>&1; then
        log_error "Root CA certificate is not valid: $ROOT_CA"
        return 1
    fi
    
    log_success "Root CA certificate is valid"
    
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "  Subject: $(openssl x509 -noout -subject -in "$ROOT_CA" | sed 's/subject=//')"
        echo "  Issuer:  $(openssl x509 -noout -issuer -in "$ROOT_CA" | sed 's/issuer=//')"
    fi
    
    check_certificate_expiry "$ROOT_CA" "Root CA"
    
    return 0
}

verify_certificate_chain() {
    local cert_file="$1"
    local description="$2"
    
    log_info "Verifying certificate chain for $description..."
    
    # Try to verify the certificate against the CA
    if openssl verify -CAfile "$ROOT_CA" "$cert_file" > /dev/null 2>&1; then
        log_success "$description certificate chain is valid"
    else
        log_warn "$description certificate chain verification failed (might be self-signed for testing)"
    fi
}

generate_test_certificates() {
    log_info "Generating test certificates..."
    log_warn "These certificates are for TESTING ONLY and should not be used in production!"
    
    mkdir -p "$TLS_DIR"
    cd "$TLS_DIR"
    
    # Check if the gen-test-certs.sh script exists
    if [[ -f "gen-test-certs.sh" ]]; then
        log_info "Using existing certificate generation script"
        bash gen-test-certs.sh
    else
        # Create a basic certificate generation script
        log_info "Creating basic test certificates"
        
        # Generate CA private key
        openssl genrsa -out ca-key.pem 4096
        
        # Generate CA certificate
        openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out root-ca.crt -subj "/C=US/ST=Test/L=Test/O=Canton Test/CN=Canton Test CA"
        
        # Generate participant private key
        openssl genrsa -out participant-key.pem 4096
        
        # Generate participant certificate request
        openssl req -subj "/C=US/ST=Test/L=Test/O=Canton Test/CN=participant1" -sha256 -new -key participant-key.pem -out participant.csr
        
        # Generate participant certificate
        echo "subjectAltName = DNS:localhost,DNS:participant1,IP:127.0.0.1,IP:0.0.0.0" > participant-extensions.txt
        openssl x509 -req -days 365 -sha256 -in participant.csr -CA root-ca.crt -CAkey ca-key.pem -out participant-cert-chain.crt -extensions SAN -extfile participant-extensions.txt -CAcreateserial
        
        # Generate domain private key
        openssl genrsa -out domain-key.pem 4096
        
        # Generate domain certificate request
        openssl req -subj "/C=US/ST=Test/L=Test/O=Canton Test/CN=mydomain" -sha256 -new -key domain-key.pem -out domain.csr
        
        # Generate domain certificate
        echo "subjectAltName = DNS:localhost,DNS:mydomain,IP:127.0.0.1,IP:0.0.0.0" > domain-extensions.txt
        openssl x509 -req -days 365 -sha256 -in domain.csr -CA root-ca.crt -CAkey ca-key.pem -out domain-cert-chain.crt -extensions SAN -extfile domain-extensions.txt -CAcreateserial
        
        # Set appropriate permissions
        chmod 600 *-key.pem
        chmod 644 *.crt
        
        # Clean up temporary files
        rm -f *.csr *.txt ca-key.pem *.srl
        
        cd - > /dev/null
    fi
    
    log_success "Test certificates generated in $TLS_DIR"
}

main() {
    local GENERATE=false
    local VERBOSE=false
    local CHECK_EXPIRY=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -g|--generate)
                GENERATE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --check-expiry)
                CHECK_EXPIRY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "Canton Certificate Verification Script"
    log_info "======================================"
    
    check_prerequisites
    extract_cert_paths
    
    local all_good=true
    
    # Create TLS directory if it doesn't exist
    mkdir -p "$TLS_DIR"
    
    # Check if certificates exist
    local missing_certs=false
    
    if ! check_file_exists "$PARTICIPANT_CERT" "Participant certificate"; then missing_certs=true; fi
    if ! check_file_exists "$PARTICIPANT_KEY" "Participant private key"; then missing_certs=true; fi
    if ! check_file_exists "$DOMAIN_CERT" "Domain certificate"; then missing_certs=true; fi
    if ! check_file_exists "$DOMAIN_KEY" "Domain private key"; then missing_certs=true; fi
    if ! check_file_exists "$ROOT_CA" "Root CA certificate"; then missing_certs=true; fi
    
    if [[ "$missing_certs" == "true" ]]; then
        if [[ "$GENERATE" == "true" ]]; then
            generate_test_certificates
        else
            log_error "Some certificates are missing. Use --generate to create test certificates."
            exit 1
        fi
    fi
    
    # Check file permissions
    check_file_permissions "$PARTICIPANT_CERT" "Participant certificate" || all_good=false
    check_file_permissions "$PARTICIPANT_KEY" "Participant private key" || all_good=false
    check_file_permissions "$DOMAIN_CERT" "Domain certificate" || all_good=false
    check_file_permissions "$DOMAIN_KEY" "Domain private key" || all_good=false
    check_file_permissions "$ROOT_CA" "Root CA certificate" || all_good=false
    
    # Verify certificates
    verify_certificate "$PARTICIPANT_CERT" "$PARTICIPANT_KEY" "participant" || all_good=false
    verify_certificate "$DOMAIN_CERT" "$DOMAIN_KEY" "domain" || all_good=false
    verify_ca_certificate || all_good=false
    
    # Check certificate expiry
    check_certificate_expiry "$PARTICIPANT_CERT" "participant" || all_good=false
    check_certificate_expiry "$DOMAIN_CERT" "domain" || all_good=false
    
    # Verify certificate chains
    verify_certificate_chain "$PARTICIPANT_CERT" "participant"
    verify_certificate_chain "$DOMAIN_CERT" "domain"
    
    if [[ "$all_good" == "true" ]]; then
        log_success "All certificate checks passed!"
        log_info "Certificates are ready for Canton deployment"
    else
        log_error "Some certificate checks failed. Please review and fix the issues above."
        exit 1
    fi
}

# Export variables for use in script
export VERBOSE CHECK_EXPIRY

main "$@"