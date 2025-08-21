#!/bin/bash

# Canton Environment Validation Script
# This script validates the complete environment setup for Canton deployment
# including system requirements, dependencies, configuration, and connectivity.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANTON_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-config/canton-single-participant.conf}"

# Validation results
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a INFO=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    INFO+=("$1")
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS+=("$1")
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS+=("$1")
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validates the complete Canton environment setup.

Environment Variables:
  CONFIG_FILE     Canton configuration file (default: config/canton-single-participant.conf)

Options:
  -h, --help      Show this help message
  -c, --config    Specify configuration file
  --debug         Enable debug output
  --fix           Attempt to fix some issues automatically
  --report        Generate detailed validation report

Examples:
  # Basic validation
  ./validate-environment.sh

  # Validation with auto-fix
  ./validate-environment.sh --fix

  # Generate detailed report
  ./validate-environment.sh --report
EOF
}

validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check OS
    local os_name=$(uname -s)
    local os_version=$(uname -r)
    log_debug "Operating System: $os_name $os_version"
    
    case "$os_name" in
        Linux)
            log_success "Operating system: Linux (supported)"
            ;;
        Darwin)
            log_success "Operating system: macOS (supported)"
            ;;
        *)
            log_warn "Operating system: $os_name (may not be fully supported)"
            ;;
    esac
    
    # Check architecture
    local arch=$(uname -m)
    log_debug "Architecture: $arch"
    
    case "$arch" in
        x86_64)
            log_success "Architecture: x86_64 (supported)"
            ;;
        aarch64|arm64)
            log_success "Architecture: ARM64 (supported)"
            ;;
        *)
            log_warn "Architecture: $arch (may not be fully supported)"
            ;;
    esac
    
    # Check memory
    local mem_kb=0
    if [[ -f /proc/meminfo ]]; then
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    elif command -v sysctl &> /dev/null; then
        mem_kb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
    fi
    
    local mem_gb=$((mem_kb / 1024 / 1024))
    
    if [[ $mem_gb -ge 8 ]]; then
        log_success "Memory: ${mem_gb}GB (recommended)"
    elif [[ $mem_gb -ge 6 ]]; then
        log_warn "Memory: ${mem_gb}GB (minimum met, 8GB+ recommended)"
    elif [[ $mem_gb -gt 0 ]]; then
        log_error "Memory: ${mem_gb}GB (insufficient, 6GB minimum required)"
    else
        log_warn "Memory: Could not determine available memory"
    fi
    
    # Check CPU cores
    local cpu_cores=0
    if [[ -f /proc/cpuinfo ]]; then
        cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    elif command -v sysctl &> /dev/null; then
        cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "0")
    fi
    
    if [[ $cpu_cores -ge 8 ]]; then
        log_success "CPU cores: $cpu_cores (recommended)"
    elif [[ $cpu_cores -ge 4 ]]; then
        log_warn "CPU cores: $cpu_cores (minimum met, 8+ recommended)"
    elif [[ $cpu_cores -gt 0 ]]; then
        log_error "CPU cores: $cpu_cores (insufficient, 4 minimum required)"
    else
        log_warn "CPU cores: Could not determine CPU count"
    fi
    
    # Check disk space
    local disk_space_gb=0
    if command -v df &> /dev/null; then
        disk_space_gb=$(df -BG "$CANTON_DIR" | awk 'NR==2{print $4}' | sed 's/G//' 2>/dev/null || echo "0")
    fi
    
    if [[ $disk_space_gb -ge 50 ]]; then
        log_success "Disk space: ${disk_space_gb}GB available (good)"
    elif [[ $disk_space_gb -ge 20 ]]; then
        log_warn "Disk space: ${disk_space_gb}GB available (adequate for testing)"
    elif [[ $disk_space_gb -gt 0 ]]; then
        log_error "Disk space: ${disk_space_gb}GB available (insufficient for production)"
    else
        log_warn "Disk space: Could not determine available space"
    fi
}

validate_java_environment() {
    log_info "Validating Java environment..."
    
    # Check Java installation
    if ! command -v java &> /dev/null; then
        log_error "Java is not installed or not in PATH"
        return 1
    fi
    
    # Get Java version
    local java_version_output=$(java -version 2>&1)
    local java_version=$(echo "$java_version_output" | head -1 | grep -oE '".*"' | sed 's/"//g')
    local java_major_version=$(echo "$java_version" | cut -d'.' -f1)
    
    # Handle different Java version formats
    if [[ "$java_major_version" == "1" ]]; then
        java_major_version=$(echo "$java_version" | cut -d'.' -f2)
    fi
    
    log_debug "Java version: $java_version"
    
    if [[ $java_major_version -ge 17 ]]; then
        log_success "Java version: $java_version (supported)"
    elif [[ $java_major_version -ge 11 ]]; then
        log_warn "Java version: $java_version (supported, but Java 17+ recommended)"
    else
        log_error "Java version: $java_version (unsupported, Java 11+ required)"
    fi
    
    # Check for recommended JVM
    if echo "$java_version_output" | grep -q "OpenJDK\|HotSpot"; then
        log_success "JVM: Recommended JVM detected"
    else
        log_warn "JVM: Non-standard JVM detected, OpenJDK or HotSpot recommended"
    fi
    
    # Check JAVA_HOME
    if [[ -n "${JAVA_HOME:-}" ]]; then
        if [[ -d "$JAVA_HOME" && -x "$JAVA_HOME/bin/java" ]]; then
            log_success "JAVA_HOME: Set and valid ($JAVA_HOME)"
        else
            log_warn "JAVA_HOME: Set but invalid ($JAVA_HOME)"
        fi
    else
        log_warn "JAVA_HOME: Not set (recommended for production)"
    fi
    
    # Check JVM heap settings
    local java_opts="${JAVA_OPTS:-}"
    if [[ -n "$java_opts" ]]; then
        if [[ "$java_opts" == *"-Xmx"* && "$java_opts" == *"-Xms"* ]]; then
            log_success "JVM heap: Custom heap settings configured"
            log_debug "JAVA_OPTS: $java_opts"
        else
            log_warn "JVM heap: Partial heap configuration (both -Xms and -Xmx recommended)"
        fi
        
        if [[ "$java_opts" == *"-XX:+UseG1GC"* ]]; then
            log_success "JVM GC: G1GC configured (recommended)"
        else
            log_warn "JVM GC: G1GC not configured (recommended for production)"
        fi
    else
        log_warn "JVM options: Not configured (JAVA_OPTS recommended for production)"
    fi
}

validate_dependencies() {
    log_info "Validating system dependencies..."
    
    # Required dependencies
    local required_deps=("curl" "nc" "ps" "pkill")
    
    # Optional but recommended dependencies
    local optional_deps=("psql" "openssl" "netstat" "lsof")
    
    for dep in "${required_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dependency: $dep (available)"
        else
            log_error "Dependency: $dep (missing - required)"
        fi
    done
    
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dependency: $dep (available)"
        else
            log_warn "Dependency: $dep (missing - recommended)"
        fi
    done
    
    # Check for PostgreSQL client specifically
    if command -v psql &> /dev/null; then
        local psql_version=$(psql --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
        log_success "PostgreSQL client: Version $psql_version available"
    else
        log_warn "PostgreSQL client: Not available (needed for database operations)"
    fi
}

validate_canton_installation() {
    log_info "Validating Canton installation..."
    
    # Change to Canton directory
    cd "$CANTON_DIR"
    
    # Check Canton binary
    if [[ -f "bin/canton" && -x "bin/canton" ]]; then
        log_success "Canton binary: Available and executable"
        
        # Try to get Canton version
        local canton_version=$(timeout 10 ./bin/canton --version 2>/dev/null | head -1 || echo "Unknown")
        log_debug "Canton version: $canton_version"
    else
        log_error "Canton binary: Not found or not executable (bin/canton)"
        return 1
    fi
    
    # Check required directories
    local required_dirs=("config" "log")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directory: $dir exists"
        else
            if [[ "${FIX:-false}" == "true" ]]; then
                mkdir -p "$dir"
                log_success "Directory: $dir created"
            else
                log_warn "Directory: $dir missing (will be created if needed)"
            fi
        fi
    done
    
    # Check configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Configuration: $CONFIG_FILE exists"
        
        # Basic configuration validation
        if grep -q "participants" "$CONFIG_FILE" && grep -q "domains" "$CONFIG_FILE"; then
            log_success "Configuration: Contains participant and domain definitions"
        else
            log_error "Configuration: Missing participant or domain definitions"
        fi
        
        if grep -q "storage.*postgres" "$CONFIG_FILE"; then
            log_success "Configuration: PostgreSQL storage configured"
        else
            log_warn "Configuration: Non-PostgreSQL storage configured"
        fi
    else
        log_error "Configuration: $CONFIG_FILE not found"
    fi
}

validate_network_connectivity() {
    log_info "Validating network connectivity..."
    
    # Check if we can bind to required ports
    local ports=(5011 5012 5018 5019 9000)
    
    for port in "${ports[@]}"; do
        if command -v nc &> /dev/null; then
            if nc -z localhost "$port" 2>/dev/null; then
                log_warn "Port: $port is already in use"
            else
                log_success "Port: $port is available"
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                log_warn "Port: $port is already in use"
            else
                log_success "Port: $port is available"
            fi
        else
            log_warn "Port: Cannot check port $port availability (nc/netstat not available)"
        fi
    done
    
    # Test basic network connectivity
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 http://google.com > /dev/null 2>&1; then
            log_success "Network: Internet connectivity available"
        else
            log_warn "Network: Limited internet connectivity (may affect downloads)"
        fi
    fi
}

validate_database_setup() {
    log_info "Validating database setup..."
    
    # Check database environment variables
    local db_host="${POSTGRES_HOST:-localhost}"
    local db_port="${POSTGRES_PORT:-5432}"
    local db_user="${POSTGRES_USER:-canton}"
    local db_password="${POSTGRES_PASSWORD:-}"
    
    if [[ -n "$db_password" ]]; then
        log_success "Database: POSTGRES_PASSWORD is set"
    else
        log_warn "Database: POSTGRES_PASSWORD not set (may be in config file)"
    fi
    
    # Test database connectivity if psql is available
    if command -v psql &> /dev/null && [[ -n "$db_password" ]]; then
        export PGPASSWORD="$db_password"
        
        if timeout 5 psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
            log_success "Database: Connection to PostgreSQL successful"
            
            # Check if Canton databases exist
            for db in canton_participant canton_domain; do
                if psql -h "$db_host" -p "$db_port" -U "$db_user" -lqt | cut -d \| -f 1 | grep -qw "$db"; then
                    log_success "Database: $db exists"
                else
                    log_warn "Database: $db does not exist (run setup-database.sh)"
                fi
            done
        else
            log_warn "Database: Cannot connect to PostgreSQL (check credentials and connectivity)"
        fi
    else
        log_warn "Database: Cannot test connectivity (psql not available or no password set)"
    fi
}

validate_certificates() {
    log_info "Validating certificates..."
    
    # Run certificate verification if script exists
    if [[ -x "$SCRIPT_DIR/verify-certificates.sh" ]]; then
        if "$SCRIPT_DIR/verify-certificates.sh" > /dev/null 2>&1; then
            log_success "Certificates: All certificates valid"
        else
            log_warn "Certificates: Some certificate issues found (run verify-certificates.sh for details)"
        fi
    else
        # Basic certificate check
        local tls_dir="config/tls"
        local cert_files=("participant-cert-chain.crt" "participant-key.pem" "domain-cert-chain.crt" "domain-key.pem" "root-ca.crt")
        
        local missing_certs=0
        for cert_file in "${cert_files[@]}"; do
            if [[ -f "$tls_dir/$cert_file" ]]; then
                log_success "Certificate: $cert_file exists"
            else
                log_error "Certificate: $cert_file missing"
                ((missing_certs++))
            fi
        done
        
        if [[ $missing_certs -gt 0 ]]; then
            log_error "Certificates: $missing_certs certificate files missing"
        fi
    fi
}

generate_validation_report() {
    log_info "Generating validation report..."
    
    local report_file="canton-environment-validation-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Canton Environment Validation Report
Generated: $(date)
Configuration: $CONFIG_FILE
Working Directory: $(pwd)

System Information:
- OS: $(uname -s) $(uname -r)
- Architecture: $(uname -m)
- Hostname: $(hostname)
- User: $(whoami)

Java Environment:
$(java -version 2>&1)

Environment Variables:
- JAVA_HOME: ${JAVA_HOME:-"Not set"}
- JAVA_OPTS: ${JAVA_OPTS:-"Not set"}
- POSTGRES_HOST: ${POSTGRES_HOST:-"Not set"}
- POSTGRES_USER: ${POSTGRES_USER:-"Not set"}
- POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:+"Set"}${POSTGRES_PASSWORD:-"Not set"}

Validation Results:
==================

ERRORS (${#ERRORS[@]}):
EOF
    
    for error in "${ERRORS[@]}"; do
        echo "- $error" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

WARNINGS (${#WARNINGS[@]}):
EOF
    
    for warning in "${WARNINGS[@]}"; do
        echo "- $warning" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

INFO (${#INFO[@]}):
EOF
    
    for info in "${INFO[@]}"; do
        echo "- $info" >> "$report_file"
    done
    
    log_success "Validation report generated: $report_file"
}

main() {
    local DEBUG=false
    local FIX=false
    local REPORT=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --fix)
                FIX=true
                shift
                ;;
            --report)
                REPORT=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Change to Canton directory
    cd "$CANTON_DIR"
    
    log_info "Canton Environment Validation"
    log_info "=============================="
    log_info "Configuration: $CONFIG_FILE"
    log_info "Working directory: $(pwd)"
    echo ""
    
    # Run all validations
    validate_system_requirements
    validate_java_environment
    validate_dependencies
    validate_canton_installation
    validate_network_connectivity
    validate_database_setup
    validate_certificates
    
    echo ""
    log_info "Validation Summary"
    log_info "=================="
    
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        log_success "No critical errors found"
    else
        log_error "Found ${#ERRORS[@]} critical error(s)"
        for error in "${ERRORS[@]}"; do
            echo "  - $error"
        done
    fi
    
    if [[ ${#WARNINGS[@]} -eq 0 ]]; then
        log_success "No warnings found"
    else
        log_warn "Found ${#WARNINGS[@]} warning(s)"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
    fi
    
    # Generate report if requested
    if [[ "$REPORT" == "true" ]]; then
        generate_validation_report
    fi
    
    # Return appropriate exit code
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo ""
        log_error "Environment validation failed. Please address the errors above."
        exit 1
    elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        log_warn "Environment validation completed with warnings. Review warnings for optimal performance."
        exit 0
    else
        echo ""
        log_success "Environment validation passed! Ready for Canton deployment."
        exit 0
    fi
}

# Export variables for use in script
export DEBUG FIX

main "$@"