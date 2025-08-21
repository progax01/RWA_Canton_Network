#!/bin/bash

# Canton Network Startup Script
# This script performs pre-flight checks and starts the Canton network
# with proper validation and monitoring.

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
JAVA_OPTS="${JAVA_OPTS:--Xms4g -Xmx4g -XX:+UseG1GC -XX:G1HeapRegionSize=16m}"
CANTON_LOG_LEVEL="${CANTON_LOG_LEVEL:-INFO}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"

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

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Starts Canton network with comprehensive pre-flight checks.

Environment Variables:
  CONFIG_FILE              Canton configuration file (default: config/canton-single-participant.conf)
  JAVA_OPTS               JVM options (default: -Xms4g -Xmx4g -XX:+UseG1GC -XX:G1HeapRegionSize=16m)
  CANTON_LOG_LEVEL        Log level (default: INFO)
  HEALTH_CHECK_TIMEOUT    Health check timeout in seconds (default: 30)

Options:
  -h, --help              Show this help message
  -c, --config FILE       Specify configuration file
  -j, --java-opts OPTS    Override JVM options
  --skip-db-check         Skip database connectivity check
  --skip-cert-check       Skip certificate verification
  --skip-health-check     Skip health checks after startup
  --console               Start with console enabled
  --background            Start in background (daemon mode)
  --dry-run              Show what would be done without starting Canton
  --debug                Enable debug output

Examples:
  # Basic startup with all checks
  ./start-canton-network.sh

  # Start with console enabled
  ./start-canton-network.sh --console

  # Start in background with custom config
  ./start-canton-network.sh --config my-config.conf --background

  # Skip checks and start immediately
  ./start-canton-network.sh --skip-db-check --skip-cert-check
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the correct directory
    if [[ ! -f "bin/canton" ]]; then
        log_error "Canton binary not found. Please run from Canton installation directory."
        exit 1
    fi
    
    # Check Java installation
    if ! command -v java &> /dev/null; then
        log_error "Java is not installed or not in PATH."
        exit 1
    fi
    
    # Check Java version
    local java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1-2)
    log_debug "Java version: $java_version"
    
    # Check if configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Check required directories
    mkdir -p log
    
    log_success "Prerequisites check passed"
}

check_system_resources() {
    log_info "Checking system resources..."
    
    # Check available memory
    if command -v free &> /dev/null; then
        local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
        if [[ $mem_gb -lt 6 ]]; then
            log_warn "System has only ${mem_gb}GB RAM. Canton recommends at least 6GB."
        else
            log_success "System has ${mem_gb}GB RAM available"
        fi
    fi
    
    # Check available disk space
    if command -v df &> /dev/null; then
        local disk_gb=$(df -BG "$CANTON_DIR" | awk 'NR==2{print $4}' | sed 's/G//')
        if [[ $disk_gb -lt 10 ]]; then
            log_warn "Available disk space is only ${disk_gb}GB. Ensure adequate space for logs and data."
        else
            log_success "Available disk space: ${disk_gb}GB"
        fi
    fi
}

validate_environment() {
    log_info "Validating environment variables..."
    
    # Check database environment variables
    local db_env_missing=false
    
    if [[ -z "${POSTGRES_HOST:-}" ]]; then
        log_warn "POSTGRES_HOST not set. Using value from config file."
    else
        log_debug "POSTGRES_HOST: $POSTGRES_HOST"
    fi
    
    if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
        log_warn "POSTGRES_PASSWORD not set. Using value from config file."
    else
        log_debug "POSTGRES_PASSWORD: [HIDDEN]"
    fi
    
    # Validate JAVA_OPTS
    if [[ -n "$JAVA_OPTS" ]]; then
        log_debug "JAVA_OPTS: $JAVA_OPTS"
        
        # Check for minimum heap size
        if [[ "$JAVA_OPTS" == *"-Xmx"* ]]; then
            local max_heap=$(echo "$JAVA_OPTS" | grep -o '\-Xmx[0-9]*[gGmM]' | head -1 | sed 's/-Xmx//')
            log_debug "Max heap size: $max_heap"
        fi
    fi
    
    log_success "Environment validation completed"
}

check_ports() {
    log_info "Checking port availability..."
    
    local ports=(
        "5011:Participant Ledger API"
        "5012:Participant Admin API" 
        "5013:Participant Health Check"
        "5018:Domain Public API"
        "5019:Domain Admin API"
        "5014:Domain Health Check"
        "9000:Prometheus Metrics"
    )
    
    local port_conflicts=false
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d':' -f1)
        local service=$(echo "$port_info" | cut -d':' -f2)
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warn "Port $port ($service) is already in use"
            port_conflicts=true
        else
            log_debug "Port $port ($service) is available"
        fi
    done
    
    if [[ "$port_conflicts" == "true" ]]; then
        log_warn "Some ports are in use. Canton may fail to start or use different ports."
    else
        log_success "All required ports are available"
    fi
}

check_database_connectivity() {
    if [[ "${SKIP_DB_CHECK:-false}" == "true" ]]; then
        log_info "Skipping database connectivity check"
        return 0
    fi
    
    log_info "Checking database connectivity..."
    
    # Try to run the database setup script in verify mode
    if [[ -x "$SCRIPT_DIR/setup-database.sh" ]]; then
        if "$SCRIPT_DIR/setup-database.sh" --dry-run > /dev/null 2>&1; then
            log_success "Database connectivity check passed"
        else
            log_warn "Database connectivity check failed. You may need to setup the database first."
            log_info "Run: $SCRIPT_DIR/setup-database.sh"
        fi
    else
        log_warn "Database setup script not found. Skipping connectivity check."
    fi
}

check_certificates() {
    if [[ "${SKIP_CERT_CHECK:-false}" == "true" ]]; then
        log_info "Skipping certificate verification"
        return 0
    fi
    
    log_info "Verifying certificates..."
    
    if [[ -x "$SCRIPT_DIR/verify-certificates.sh" ]]; then
        if "$SCRIPT_DIR/verify-certificates.sh" > /dev/null 2>&1; then
            log_success "Certificate verification passed"
        else
            log_warn "Certificate verification failed. You may need to setup certificates first."
            log_info "Run: $SCRIPT_DIR/verify-certificates.sh --generate"
        fi
    else
        log_warn "Certificate verification script not found. Skipping certificate check."
    fi
}

prepare_startup() {
    log_info "Preparing Canton startup..."
    
    # Set JVM options
    export JAVA_OPTS
    
    # Create startup command
    local canton_cmd="./bin/canton"
    local canton_args=()
    
    # Add configuration file
    canton_args+=("-c" "$CONFIG_FILE")
    
    # Add console flag if requested
    if [[ "${CONSOLE:-false}" == "true" ]]; then
        canton_args+=("--console")
    fi
    
    # Add other flags
    if [[ "${MANUAL_START:-false}" == "true" ]]; then
        canton_args+=("--manual-start")
    fi
    
    # Set log level
    if [[ -n "$CANTON_LOG_LEVEL" ]]; then
        canton_args+=("-D" "canton.logging.level=$CANTON_LOG_LEVEL")
    fi
    
    CANTON_COMMAND="$canton_cmd ${canton_args[*]}"
    log_debug "Canton command: $CANTON_COMMAND"
}

start_canton() {
    log_info "Starting Canton network..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $CANTON_COMMAND"
        log_info "[DRY RUN] With JAVA_OPTS: $JAVA_OPTS"
        return 0
    fi
    
    # Create PID file for tracking
    local pid_file="log/canton.pid"
    
    if [[ "${BACKGROUND:-false}" == "true" ]]; then
        log_info "Starting Canton in background mode..."
        nohup $CANTON_COMMAND > log/canton-startup.log 2>&1 &
        local canton_pid=$!
        echo $canton_pid > "$pid_file"
        log_success "Canton started in background (PID: $canton_pid)"
        log_info "Logs: log/canton-startup.log, log/canton.log"
    else
        log_info "Starting Canton in foreground mode..."
        log_info "Use Ctrl+C to stop Canton"
        log_info "Command: $CANTON_COMMAND"
        echo ""
        
        # Trap signals to clean up PID file
        trap 'rm -f "$pid_file"; exit 0' INT TERM
        
        $CANTON_COMMAND &
        local canton_pid=$!
        echo $canton_pid > "$pid_file"
        
        wait $canton_pid
        rm -f "$pid_file"
    fi
}

perform_health_checks() {
    if [[ "${SKIP_HEALTH_CHECK:-false}" == "true" ]]; then
        log_info "Skipping health checks"
        return 0
    fi
    
    if [[ "${BACKGROUND:-false}" != "true" ]]; then
        log_info "Skipping health checks (foreground mode)"
        return 0
    fi
    
    log_info "Performing health checks..."
    
    local timeout=$HEALTH_CHECK_TIMEOUT
    local checks_passed=0
    local total_checks=3
    
    # Wait a bit for Canton to start
    log_info "Waiting for Canton to initialize..."
    sleep 10
    
    # Check if Canton process is running
    local pid_file="log/canton.pid"
    if [[ -f "$pid_file" ]]; then
        local canton_pid=$(cat "$pid_file")
        if ps -p $canton_pid > /dev/null 2>&1; then
            log_success "Canton process is running (PID: $canton_pid)"
            ((checks_passed++))
        else
            log_error "Canton process is not running"
        fi
    else
        log_error "Canton PID file not found"
    fi
    
    # Check participant health (if grpc-health-server is configured)
    log_info "Checking participant health endpoint..."
    if timeout 5 nc -z localhost 5013 2>/dev/null; then
        log_success "Participant health endpoint is responsive"
        ((checks_passed++))
    else
        log_warn "Participant health endpoint is not accessible (might not be configured)"
    fi
    
    # Check domain health (if grpc-health-server is configured)
    log_info "Checking domain health endpoint..."
    if timeout 5 nc -z localhost 5014 2>/dev/null; then
        log_success "Domain health endpoint is responsive"
        ((checks_passed++))
    else
        log_warn "Domain health endpoint is not accessible (might not be configured)"
    fi
    
    # Check Prometheus metrics
    log_info "Checking Prometheus metrics endpoint..."
    if timeout 5 nc -z localhost 9000 2>/dev/null; then
        log_success "Prometheus metrics endpoint is responsive"
    else
        log_warn "Prometheus metrics endpoint is not accessible"
    fi
    
    log_info "Health check summary: $checks_passed/$total_checks critical checks passed"
    
    if [[ $checks_passed -ge 1 ]]; then
        log_success "Canton network appears to be healthy"
    else
        log_warn "Canton network health checks failed. Check logs for issues."
    fi
}

show_next_steps() {
    log_info "Canton network startup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Connect participant to domain:"
    echo "   ./bin/canton -c $CONFIG_FILE --console"
    echo "   > participant1.domains.connect_local(mydomain)"
    echo ""
    echo "2. Create parties:"
    echo "   > val alice = participant1.parties.enable(\"Alice\")"
    echo "   > val bob = participant1.parties.enable(\"Bob\")"
    echo ""
    echo "3. Upload DAR files:"
    echo "   > participant1.dars.upload(\"path/to/your.dar\")"
    echo ""
    echo "Useful commands:"
    echo "- Check logs: tail -f log/canton.log"
    echo "- Stop Canton: pkill -f canton"
    echo "- Health status: curl http://localhost:9000/metrics"
    echo ""
}

cleanup_on_exit() {
    log_info "Cleaning up..."
    local pid_file="log/canton.pid"
    if [[ -f "$pid_file" ]]; then
        local canton_pid=$(cat "$pid_file")
        if ps -p $canton_pid > /dev/null 2>&1; then
            log_info "Stopping Canton (PID: $canton_pid)..."
            kill $canton_pid
        fi
        rm -f "$pid_file"
    fi
}

main() {
    local CONSOLE=false
    local BACKGROUND=false
    local DRY_RUN=false
    local DEBUG=false
    local SKIP_DB_CHECK=false
    local SKIP_CERT_CHECK=false
    local SKIP_HEALTH_CHECK=false
    
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
            -j|--java-opts)
                JAVA_OPTS="$2"
                shift 2
                ;;
            --skip-db-check)
                SKIP_DB_CHECK=true
                shift
                ;;
            --skip-cert-check)
                SKIP_CERT_CHECK=true
                shift
                ;;
            --skip-health-check)
                SKIP_HEALTH_CHECK=true
                shift
                ;;
            --console)
                CONSOLE=true
                shift
                ;;
            --background)
                BACKGROUND=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --debug)
                DEBUG=true
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
    
    log_info "Canton Network Startup Script"
    log_info "=============================="
    log_info "Configuration: $CONFIG_FILE"
    log_info "Working directory: $(pwd)"
    echo ""
    
    # Set trap for cleanup
    trap cleanup_on_exit EXIT INT TERM
    
    # Run all checks
    check_prerequisites
    check_system_resources
    validate_environment
    check_ports
    check_database_connectivity
    check_certificates
    
    # Prepare and start Canton
    prepare_startup
    start_canton
    
    # Perform health checks if running in background
    if [[ "${BACKGROUND}" == "true" && "${DRY_RUN}" == "false" ]]; then
        perform_health_checks
    fi
    
    # Show next steps
    if [[ "${DRY_RUN}" == "false" ]]; then
        show_next_steps
    fi
}

# Export variables for use in script
export DEBUG SKIP_DB_CHECK SKIP_CERT_CHECK SKIP_HEALTH_CHECK CONSOLE BACKGROUND DRY_RUN

main "$@"