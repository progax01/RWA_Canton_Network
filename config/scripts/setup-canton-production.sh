#!/bin/bash

# Canton Production Setup Master Script
# This script orchestrates the complete setup process for Canton production deployment
# including database setup, certificate verification, environment validation, and network startup.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANTON_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-config/canton-production-temp.conf}"

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

log_step() {
    echo -e "${BOLD}${PURPLE}[STEP]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Master script for Canton production setup and deployment.

Environment Variables:
  CONFIG_FILE              Canton configuration file (default: config/canton-single-participant.conf)
  POSTGRES_HOST           PostgreSQL host
  POSTGRES_PASSWORD       PostgreSQL password
  CANTON_DB_PASSWORD      Canton database password

Options:
  -h, --help              Show this help message
  -c, --config FILE       Specify configuration file
  --skip-validation       Skip environment validation
  --skip-database         Skip database setup
  --skip-certificates     Skip certificate setup
  --generate-certs        Generate test certificates
  --setup-only           Only run setup steps (don't start Canton)
  --interactive          Interactive mode with prompts
  --yes                  Answer yes to all prompts (non-interactive)

Setup Steps:
  1. Environment validation
  2. Database setup and connectivity test
  3. Certificate verification and setup
  4. Canton network startup
  5. Participant-domain connection
  6. Sample party creation (optional)
  7. DAR upload (optional)

Examples:
  # Full interactive setup
  ./setup-canton-production.sh --interactive

  # Non-interactive setup with test certificates
  export POSTGRES_PASSWORD=admin_pass
  export CANTON_DB_PASSWORD=canton_pass
  ./setup-canton-production.sh --generate-certs --yes

  # Setup only (no startup)
  ./setup-canton-production.sh --setup-only
EOF
}

print_banner() {
    echo ""
    echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
    echo -e "${BOLD}${BLUE}║              Canton Production Setup Script                   ║${NC}"
    echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
    echo -e "${BOLD}${BLUE}║  This script will guide you through setting up a complete    ║${NC}"
    echo -e "${BOLD}${BLUE}║  Canton production deployment with PostgreSQL, TLS, and      ║${NC}"
    echo -e "${BOLD}${BLUE}║  monitoring configuration.                                    ║${NC}"
    echo -e "${BOLD}${BLUE}║                                                               ║${NC}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Change to Canton directory
    cd "$CANTON_DIR"
    
    # Check if all required scripts exist
    local required_scripts=(
        "validate-environment.sh"
        "setup-database.sh"
        "verify-certificates.sh"
        "start-canton-network.sh"
        "connect-participant-domain.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            log_success "Script available: $script"
        else
            log_error "Required script not found or not executable: $script"
            exit 1
        fi
    done
    
    log_success "All required scripts are available"
}

prompt_user() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        return 0
    fi
    
    local response
    echo -n -e "${YELLOW}[PROMPT]${NC} $message (y/N): "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_environment() {
    if [[ "${SKIP_VALIDATION:-false}" == "true" ]]; then
        log_info "Skipping environment validation"
        return 0
    fi
    
    log_step "Step 1: Environment Validation"
    echo "This step validates system requirements, Java environment, and dependencies."
    
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if ! prompt_user "Run environment validation?"; then
            log_info "Skipping environment validation"
            return 0
        fi
    fi
    
    if "$SCRIPT_DIR/validate-environment.sh"; then
        log_success "Environment validation passed"
    else
        log_error "Environment validation failed"
        if [[ "${INTERACTIVE:-false}" == "true" ]]; then
            if prompt_user "Continue despite validation failures?"; then
                log_warn "Continuing with validation failures"
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

setup_database() {
    if [[ "${SKIP_DATABASE:-false}" == "true" ]]; then
        log_info "Skipping database setup"
        return 0
    fi
    
    log_step "Step 2: Database Setup"
    echo "This step creates PostgreSQL databases for Canton participant and domain."
    
    # Check if database credentials are set
    if [[ -z "${POSTGRES_ADMIN_PASSWORD:-}" ]]; then
        if [[ "${INTERACTIVE:-false}" == "true" ]]; then
            echo -n "Enter PostgreSQL admin password: "
            read -s POSTGRES_ADMIN_PASSWORD
            echo ""
            export POSTGRES_ADMIN_PASSWORD
        else
            log_error "POSTGRES_ADMIN_PASSWORD environment variable is required"
            return 1
        fi
    fi
    
    if [[ -z "${CANTON_DB_PASSWORD:-}" ]]; then
        if [[ "${INTERACTIVE:-false}" == "true" ]]; then
            echo -n "Enter Canton database password: "
            read -s CANTON_DB_PASSWORD
            echo ""
            export CANTON_DB_PASSWORD
        else
            log_error "CANTON_DB_PASSWORD environment variable is required"
            return 1
        fi
    fi
    
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if ! prompt_user "Setup databases?"; then
            log_info "Skipping database setup"
            return 0
        fi
    fi
    
    local db_args=("--verify")
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        db_args+=("--force")
    fi
    
    if "$SCRIPT_DIR/setup-database.sh" "${db_args[@]}"; then
        log_success "Database setup completed"
    else
        log_error "Database setup failed"
        return 1
    fi
}

setup_certificates() {
    if [[ "${SKIP_CERTIFICATES:-false}" == "true" ]]; then
        log_info "Skipping certificate setup"
        return 0
    fi
    
    log_step "Step 3: Certificate Setup"
    echo "This step verifies or generates TLS certificates for secure communication."
    
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if ! prompt_user "Setup certificates?"; then
            log_info "Skipping certificate setup"
            return 0
        fi
    fi
    
    local cert_args=()
    if [[ "${GENERATE_CERTS:-false}" == "true" ]]; then
        cert_args+=("--generate")
        log_warn "Generating test certificates (NOT for production use)"
    fi
    
    if "$SCRIPT_DIR/verify-certificates.sh" "${cert_args[@]}"; then
        log_success "Certificate setup completed"
    else
        log_error "Certificate setup failed"
        if [[ "${GENERATE_CERTS:-false}" != "true" ]]; then
            log_info "Try running with --generate-certs to create test certificates"
        fi
        return 1
    fi
}

start_canton_network() {
    if [[ "${SETUP_ONLY:-false}" == "true" ]]; then
        log_info "Setup-only mode: Skipping Canton startup"
        return 0
    fi
    
    log_step "Step 4: Canton Network Startup"
    echo "This step starts the Canton network with participant and domain nodes."
    
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if ! prompt_user "Start Canton network?"; then
            log_info "Skipping Canton startup"
            return 0
        fi
    fi
    
    local canton_args=("--background")
    
    if "$SCRIPT_DIR/start-canton-network.sh" "${canton_args[@]}"; then
        log_success "Canton network started successfully"
        sleep 5  # Give Canton time to fully initialize
    else
        log_error "Failed to start Canton network"
        return 1
    fi
}

connect_network() {
    if [[ "${SETUP_ONLY:-false}" == "true" ]]; then
        log_info "Setup-only mode: Skipping network connection"
        return 0
    fi
    
    log_step "Step 5: Network Connection"
    echo "This step connects the participant to the domain."
    
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if ! prompt_user "Connect participant to domain?"; then
            log_info "Skipping network connection"
            return 0
        fi
    fi
    
    if "$SCRIPT_DIR/connect-participant-domain.sh"; then
        log_success "Participant connected to domain"
    else
        log_error "Failed to connect participant to domain"
        return 1
    fi
}

create_sample_setup() {
    if [[ "${SETUP_ONLY:-false}" == "true" ]]; then
        log_info "Setup-only mode: Skipping sample setup"
        return 0
    fi
    
    log_step "Step 6: Sample Setup (Optional)"
    echo "This step creates sample parties and uploads example DARs."
    
    local create_samples=false
    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        if prompt_user "Create sample parties and upload DARs?"; then
            create_samples=true
        fi
    elif [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        create_samples=true
    fi
    
    if [[ "$create_samples" == "true" ]]; then
        if "$SCRIPT_DIR/connect-participant-domain.sh" --create-parties --upload-dars; then
            log_success "Sample setup completed"
        else
            log_warn "Sample setup completed with some issues"
        fi
    else
        log_info "Skipping sample setup"
    fi
}

show_final_status() {
    log_step "Final Status and Next Steps"
    
    if [[ "${SETUP_ONLY:-false}" == "true" ]]; then
        echo ""
        log_success "Canton setup completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Start Canton:"
        echo "   ./config/scripts/start-canton-network.sh"
        echo ""
        echo "2. Connect participant to domain:"
        echo "   ./config/scripts/connect-participant-domain.sh"
        echo ""
    else
        echo ""
        # Get current status
        if "$SCRIPT_DIR/connect-participant-domain.sh" --status-only > /dev/null 2>&1; then
            log_success "Canton production deployment completed successfully!"
        else
            log_warn "Canton deployment completed with some issues"
        fi
        
        echo ""
        echo "Your Canton network is now running with:"
        echo "- Participant: participant1 (Admin API: localhost:5012, Ledger API: localhost:5011)"
        echo "- Domain: mydomain (Public API: localhost:5018, Admin API: localhost:5019)"
        echo "- Monitoring: Prometheus metrics on localhost:9000"
        echo ""
        echo "Useful commands:"
        echo "- Check status: ./config/scripts/connect-participant-domain.sh --status-only"
        echo "- Interactive console: ./bin/canton -c $CONFIG_FILE --console"
        echo "- View logs: tail -f log/canton.log"
        echo "- Stop Canton: pkill -f canton"
        echo ""
        echo "For application development:"
        echo "- gRPC Ledger API: localhost:5011 (with TLS)"
        echo "- Admin APIs: localhost:5012 (participant), localhost:5019 (domain)"
        echo "- Health checks: localhost:5013 (participant), localhost:5014 (domain)"
        echo ""
    fi
    
    log_info "Setup completed! Check the README for additional configuration options."
}

cleanup_on_failure() {
    log_error "Setup failed. Cleaning up..."
    
    # Stop Canton if it was started
    if pgrep -f "canton.*$CONFIG_FILE" > /dev/null; then
        log_info "Stopping Canton..."
        pkill -f "canton.*$CONFIG_FILE" || true
    fi
    
    # Remove PID file
    local pid_file="log/canton.pid"
    if [[ -f "$pid_file" ]]; then
        rm -f "$pid_file"
    fi
    
    log_info "Cleanup completed"
}

main() {
    local INTERACTIVE=false
    local NON_INTERACTIVE=false
    local SETUP_ONLY=false
    local SKIP_VALIDATION=false
    local SKIP_DATABASE=false
    local SKIP_CERTIFICATES=false
    local GENERATE_CERTS=false
    
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
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --skip-database)
                SKIP_DATABASE=true
                shift
                ;;
            --skip-certificates)
                SKIP_CERTIFICATES=true
                shift
                ;;
            --generate-certs)
                GENERATE_CERTS=true
                shift
                ;;
            --setup-only)
                SETUP_ONLY=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --yes)
                NON_INTERACTIVE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set up error handling
    trap cleanup_on_failure ERR
    
    print_banner
    
    log_info "Starting Canton production setup..."
    log_info "Configuration: $CONFIG_FILE"
    log_info "Working directory: $(pwd)"
    
    if [[ "$INTERACTIVE" == "true" && "$NON_INTERACTIVE" == "true" ]]; then
        log_error "Cannot use both --interactive and --yes options"
        exit 1
    fi
    
    echo ""
    
    # Run setup steps
    check_prerequisites
    validate_environment
    setup_database
    setup_certificates
    start_canton_network
    connect_network
    create_sample_setup
    show_final_status
}

# Export variables for use in subscripts
export INTERACTIVE NON_INTERACTIVE SETUP_ONLY SKIP_VALIDATION SKIP_DATABASE SKIP_CERTIFICATES GENERATE_CERTS

main "$@"