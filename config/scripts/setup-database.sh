#!/bin/bash

# Canton Database Setup Script
# This script creates PostgreSQL databases for Canton participant and domain
# and sets up the required user permissions.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (can be overridden by environment)
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_ADMIN_USER="${POSTGRES_ADMIN_USER:-postgres}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD:-}"
CANTON_DB_USER="${CANTON_DB_USER:-canton}"
CANTON_DB_PASSWORD="${CANTON_DB_PASSWORD:-}"
JSON_API_DB_USER="${JSON_API_DB_USER:-json_api}"
JSON_API_DB_PASSWORD="${JSON_API_DB_PASSWORD:-}"
PARTICIPANT_DB="${PARTICIPANT_DB:-canton_participant}"
DOMAIN_DB="${DOMAIN_DB:-canton_domain}"
JSON_API_DB="${JSON_API_DB:-json_api_store}"

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

Creates PostgreSQL databases for Canton participant and domain.

Environment Variables:
  POSTGRES_HOST             PostgreSQL host (default: localhost)
  POSTGRES_PORT             PostgreSQL port (default: 5432)
  POSTGRES_ADMIN_USER       PostgreSQL admin user (default: postgres)
  POSTGRES_ADMIN_PASSWORD   PostgreSQL admin password (required)
  CANTON_DB_USER           Canton database user (default: canton)
  CANTON_DB_PASSWORD       Canton database password (required)
  JSON_API_DB_USER         JSON API database user (default: json_api)
  JSON_API_DB_PASSWORD     JSON API database password (required)
  PARTICIPANT_DB           Participant database name (default: canton_participant)
  DOMAIN_DB                Domain database name (default: canton_domain)
  JSON_API_DB              JSON API database name (default: json_api_store)

Options:
  -h, --help               Show this help message
  -f, --force              Drop existing databases if they exist
  -v, --verify             Verify database setup after creation
  --dry-run               Show what would be done without executing

Examples:
  # Basic setup (requires passwords)
  export POSTGRES_ADMIN_PASSWORD=admin_password
  export CANTON_DB_PASSWORD=strong_canton_password
  export JSON_API_DB_PASSWORD=strong_json_api_password
  ./setup-database.sh

  # Setup with custom host and user
  export POSTGRES_HOST=db.example.com
  export POSTGRES_ADMIN_PASSWORD=admin_password
  export CANTON_DB_PASSWORD=strong_canton_password
  ./setup-database.sh --verify
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if psql is installed
    if ! command -v psql &> /dev/null; then
        log_error "psql is not installed. Please install PostgreSQL client tools."
        exit 1
    fi
    
    # Check required environment variables
    if [[ -z "$POSTGRES_ADMIN_PASSWORD" ]]; then
        log_error "POSTGRES_ADMIN_PASSWORD environment variable is required"
        exit 1
    fi
    
    if [[ -z "$CANTON_DB_PASSWORD" ]]; then
        log_error "CANTON_DB_PASSWORD environment variable is required"
        exit 1
    fi
    
    if [[ -z "$JSON_API_DB_PASSWORD" ]]; then
        log_error "JSON_API_DB_PASSWORD environment variable is required"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

test_connection() {
    log_info "Testing PostgreSQL connection..."
    
    export PGPASSWORD="$POSTGRES_ADMIN_PASSWORD"
    
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -c "SELECT version();" > /dev/null 2>&1; then
        log_success "Successfully connected to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
    else
        log_error "Failed to connect to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
        log_error "Please verify that PostgreSQL is running and credentials are correct"
        exit 1
    fi
}

check_existing_databases() {
    log_info "Checking for existing databases..."
    
    export PGPASSWORD="$POSTGRES_ADMIN_PASSWORD"
    
    # Check if participant database exists
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -lqt | cut -d \| -f 1 | grep -qw "$PARTICIPANT_DB"; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "Participant database '$PARTICIPANT_DB' exists and will be dropped"
        else
            log_error "Participant database '$PARTICIPANT_DB' already exists. Use --force to drop it."
            exit 1
        fi
    fi
    
    # Check if domain database exists
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -lqt | cut -d \| -f 1 | grep -qw "$DOMAIN_DB"; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "Domain database '$DOMAIN_DB' exists and will be dropped"
        else
            log_error "Domain database '$DOMAIN_DB' already exists. Use --force to drop it."
            exit 1
        fi
    fi
    
    # Check if JSON API database exists
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -lqt | cut -d \| -f 1 | grep -qw "$JSON_API_DB"; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "JSON API database '$JSON_API_DB' exists and will be dropped"
        else
            log_error "JSON API database '$JSON_API_DB' already exists. Use --force to drop it."
            exit 1
        fi
    fi
    
    # Check if canton user exists
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$CANTON_DB_USER'" | grep -q 1; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "User '$CANTON_DB_USER' exists and will be updated"
        else
            log_info "User '$CANTON_DB_USER' already exists and will be updated"
        fi
    fi
    
    # Check if JSON API user exists
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$JSON_API_DB_USER'" | grep -q 1; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "User '$JSON_API_DB_USER' exists and will be updated"
        else
            log_info "User '$JSON_API_DB_USER' already exists and will be updated"
        fi
    fi
}

create_databases() {
    log_info "Creating Canton databases..."
    
    export PGPASSWORD="$POSTGRES_ADMIN_PASSWORD"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would execute the following SQL commands:"
        cat << EOF
-- Drop existing databases (if --force specified)
DROP DATABASE IF EXISTS $PARTICIPANT_DB;
DROP DATABASE IF EXISTS $DOMAIN_DB;
DROP DATABASE IF EXISTS $JSON_API_DB;

-- Create or update users
DROP USER IF EXISTS $CANTON_DB_USER;
DROP USER IF EXISTS $JSON_API_DB_USER;
CREATE USER $CANTON_DB_USER WITH PASSWORD '$CANTON_DB_PASSWORD';
CREATE USER $JSON_API_DB_USER WITH PASSWORD '$JSON_API_DB_PASSWORD';

-- Create databases
CREATE DATABASE $PARTICIPANT_DB OWNER $CANTON_DB_USER;
CREATE DATABASE $DOMAIN_DB OWNER $CANTON_DB_USER;
CREATE DATABASE $JSON_API_DB OWNER $JSON_API_DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $PARTICIPANT_DB TO $CANTON_DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DOMAIN_DB TO $CANTON_DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $JSON_API_DB TO $JSON_API_DB_USER;
EOF
        return 0
    fi
    
    # Create SQL script
    SQL_SCRIPT=$(mktemp)
    cat > "$SQL_SCRIPT" << EOF
-- Canton Database Setup Script
-- Generated on $(date)

-- Drop existing databases if force mode is enabled
EOF
    
    if [[ "${FORCE:-false}" == "true" ]]; then
        cat >> "$SQL_SCRIPT" << EOF
DROP DATABASE IF EXISTS $PARTICIPANT_DB;
DROP DATABASE IF EXISTS $DOMAIN_DB;
DROP DATABASE IF EXISTS $JSON_API_DB;
DROP USER IF EXISTS $CANTON_DB_USER;
DROP USER IF EXISTS $JSON_API_DB_USER;
EOF
    fi
    
    cat >> "$SQL_SCRIPT" << EOF

-- Create Canton user
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$CANTON_DB_USER') THEN
        CREATE USER $CANTON_DB_USER WITH PASSWORD '$CANTON_DB_PASSWORD';
    ELSE
        ALTER USER $CANTON_DB_USER WITH PASSWORD '$CANTON_DB_PASSWORD';
    END IF;
END
\$\$;

-- Create JSON API user
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$JSON_API_DB_USER') THEN
        CREATE USER $JSON_API_DB_USER WITH PASSWORD '$JSON_API_DB_PASSWORD';
    ELSE
        ALTER USER $JSON_API_DB_USER WITH PASSWORD '$JSON_API_DB_PASSWORD';
    END IF;
END
\$\$;

-- Create databases
CREATE DATABASE $PARTICIPANT_DB OWNER $CANTON_DB_USER;
CREATE DATABASE $DOMAIN_DB OWNER $CANTON_DB_USER;
CREATE DATABASE $JSON_API_DB OWNER $JSON_API_DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $PARTICIPANT_DB TO $CANTON_DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DOMAIN_DB TO $CANTON_DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $JSON_API_DB TO $JSON_API_DB_USER;

-- Apply performance tuning (adjust based on your hardware)
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET maintenance_work_mem = '256MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET random_page_cost = 1.1;

-- Reload configuration
SELECT pg_reload_conf();
EOF
    
    log_info "Executing database creation script..."
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN_USER" -d postgres -f "$SQL_SCRIPT"; then
        log_success "Databases created successfully"
    else
        log_error "Failed to create databases"
        rm -f "$SQL_SCRIPT"
        exit 1
    fi
    
    rm -f "$SQL_SCRIPT"
}

verify_setup() {
    log_info "Verifying database setup..."
    
    # Test connection with canton user
    export PGPASSWORD="$CANTON_DB_PASSWORD"
    
    # Test participant database
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$CANTON_DB_USER" -d "$PARTICIPANT_DB" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Participant database connection test passed"
    else
        log_error "Failed to connect to participant database as $CANTON_DB_USER"
        exit 1
    fi
    
    # Test domain database
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$CANTON_DB_USER" -d "$DOMAIN_DB" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Domain database connection test passed"
    else
        log_error "Failed to connect to domain database as $CANTON_DB_USER"
        exit 1
    fi
    
    # Test JSON API database
    export PGPASSWORD="$JSON_API_DB_PASSWORD"
    if psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$JSON_API_DB_USER" -d "$JSON_API_DB" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "JSON API database connection test passed"
    else
        log_error "Failed to connect to JSON API database as $JSON_API_DB_USER"
        exit 1
    fi
    
    # Show database information
    log_info "Database setup summary:"
    echo "  Host: $POSTGRES_HOST:$POSTGRES_PORT"
    echo "  Canton User: $CANTON_DB_USER"
    echo "  JSON API User: $JSON_API_DB_USER"
    echo "  Participant DB: $PARTICIPANT_DB"
    echo "  Domain DB: $DOMAIN_DB"
    echo "  JSON API DB: $JSON_API_DB"
}

main() {
    local FORCE=false
    local VERIFY=false
    local DRY_RUN=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verify)
                VERIFY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "Canton Database Setup Script"
    log_info "=============================="
    
    check_prerequisites
    test_connection
    check_existing_databases
    create_databases
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if [[ "$VERIFY" == "true" ]]; then
            verify_setup
        fi
        
        log_success "Database setup completed successfully!"
        log_info "You can now start Canton with the production configuration"
        log_info "Connection string for participant: jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$PARTICIPANT_DB"
        log_info "Connection string for domain: jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$DOMAIN_DB"
        log_info "Connection string for JSON API: jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$JSON_API_DB"
    fi
}

# Export variables for use in script
export FORCE VERIFY DRY_RUN

main "$@"