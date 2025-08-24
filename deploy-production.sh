#!/bin/bash
# Production Deployment Script for RWA Platform
# This script sets up the production environment for Canton and JSON API

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_DIR="${SCRIPT_DIR}/log"
PID_DIR="${SCRIPT_DIR}/run"

# Create necessary directories
create_directories() {
    echo -e "${BLUE}📁 Creating necessary directories...${NC}"
    mkdir -p "${LOG_DIR}" "${PID_DIR}"
    chmod 755 "${LOG_DIR}" "${PID_DIR}"
    echo -e "${GREEN}✅ Directories created${NC}"
}

# Load environment variables
load_environment() {
    echo -e "${BLUE}🌍 Loading production environment...${NC}"
    if [[ -f "${CONFIG_DIR}/production.env" ]]; then
        source "${CONFIG_DIR}/production.env"
        echo -e "${GREEN}✅ Environment loaded${NC}"
    else
        echo -e "${RED}❌ Production environment file not found: ${CONFIG_DIR}/production.env${NC}"
        echo "Please copy config/production.env.example and customize it"
        exit 1
    fi
}

# Validate environment
validate_environment() {
    echo -e "${BLUE}🔍 Validating environment...${NC}"
    
    local required_vars=(
        "CANTON_DB_USER"
        "CANTON_DB_PASSWORD"
        "JSON_API_DB_USER"
        "JSON_API_DB_PASSWORD"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required environment variables:${NC}"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Environment validation passed${NC}"
}

# Setup databases
setup_databases() {
    echo -e "${BLUE}🗄️ Setting up databases...${NC}"
    
    # Check if PostgreSQL is running
    if ! systemctl is-active --quiet postgresql; then
        echo -e "${YELLOW}⚠️ PostgreSQL is not running. Please start it first.${NC}"
        exit 1
    fi
    
    # Create databases if they don't exist
    echo "Creating Canton participant database..."
    sudo -u postgres createdb canton_participant 2>/dev/null || echo "Database already exists"
    
    echo "Creating Canton domain database..."
    sudo -u postgres createdb canton_domain 2>/dev/null || echo "Database already exists"
    
    echo "Creating JSON API query store database..."
    sudo -u postgres createdb json_api_store 2>/dev/null || echo "Database already exists"
    
    echo -e "${GREEN}✅ Databases setup completed${NC}"
}

# Validate certificates
validate_certificates() {
    echo -e "${BLUE}🔒 Validating TLS certificates...${NC}"
    
    local cert_files=(
        "config/tls/root-ca.crt"
        "config/tls/ledger-api.crt"
        "config/tls/ledger-api.key"
        "config/tls/admin-api.crt"
        "config/tls/admin-api.key"
        "config/tls/public-api.crt"
        "config/tls/public-api.key"
        "config/tls/admin-client.crt"
        "config/tls/admin-client.key"
    )
    
    for cert_file in "${cert_files[@]}"; do
        if [[ ! -f "$cert_file" ]]; then
            echo -e "${RED}❌ Missing certificate file: $cert_file${NC}"
            exit 1
        fi
    done
    
    # Validate JWT signing certificate
    if [[ ! -f "config/jwt/jwt-sign.crt" ]] || [[ ! -f "config/jwt/jwt-sign.key" ]]; then
        echo -e "${RED}❌ Missing JWT signing certificates${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Certificate validation passed${NC}"
}

# Start Canton nodes
start_canton() {
    echo -e "${BLUE}🚀 Starting Canton nodes...${NC}"
    
    local canton_jar="lib/canton-open-source-2.10.2.jar"
    local canton_config="${CANTON_CONFIG_FILE:-config/canton-production.conf}"
    local canton_log="${LOG_DIR}/canton-production.log"
    local canton_pid="${PID_DIR}/canton.pid"
    
    if [[ -f "$canton_pid" ]]; then
        local pid=$(cat "$canton_pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠️ Canton is already running (PID: $pid)${NC}"
            return
        else
            rm -f "$canton_pid"
        fi
    fi
    
    echo "Starting Canton with config: $canton_config"
    java -jar "$canton_jar" \
        --config "$canton_config" \
        --log-file-name "$canton_log" \
        --log-level-root INFO \
        daemon &
    
    local canton_pid_value=$!
    echo "$canton_pid_value" > "$canton_pid"
    
    echo -e "${GREEN}✅ Canton started (PID: $canton_pid_value)${NC}"
    
    # Wait for Canton to be ready
    echo "Waiting for Canton to be ready..."
    sleep 10
    
    # Check if Canton is responding
    local max_attempts=30
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -k -s --connect-timeout 2 "https://localhost:5011/readyz" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Canton is ready${NC}"
            break
        fi
        
        echo "Attempt $attempt/$max_attempts: Waiting for Canton..."
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        echo -e "${RED}❌ Canton failed to start properly${NC}"
        exit 1
    fi
}

# Start JSON API
start_json_api() {
    echo -e "${BLUE}🌐 Starting HTTP JSON API...${NC}"
    
    local json_api_jar="http-json-2.10.2.jar"
    local json_api_config="${JSON_API_CONFIG_FILE:-config/json-api-production.conf}"
    local json_api_log="${LOG_DIR}/json-api-production.log"
    local json_api_pid="${PID_DIR}/json-api.pid"
    
    if [[ -f "$json_api_pid" ]]; then
        local pid=$(cat "$json_api_pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠️ JSON API is already running (PID: $pid)${NC}"
            return
        else
            rm -f "$json_api_pid"
        fi
    fi
    
    echo "Starting JSON API with config: $json_api_config"
    java -jar "$json_api_jar" \
        --config "$json_api_config" \
        --log-file "$json_api_log" \
        --log-level INFO &
    
    local json_api_pid_value=$!
    echo "$json_api_pid_value" > "$json_api_pid"
    
    echo -e "${GREEN}✅ JSON API started (PID: $json_api_pid_value)${NC}"
    
    # Wait for JSON API to be ready
    echo "Waiting for JSON API to be ready..."
    sleep 5
    
    # Check if JSON API is responding
    local max_attempts=15
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --connect-timeout 2 "http://localhost:${JSON_API_PORT:-7575}/livez" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ JSON API is ready${NC}"
            break
        fi
        
        echo "Attempt $attempt/$max_attempts: Waiting for JSON API..."
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        echo -e "${RED}❌ JSON API failed to start properly${NC}"
        exit 1
    fi
}

# Setup Canton users and parties (if needed)
setup_canton_users() {
    echo -e "${BLUE}👥 Setting up Canton users and parties...${NC}"
    
    # This would typically involve running Canton console commands
    # For now, we'll just create the setup script that can be run manually
    cat > "${SCRIPT_DIR}/setup-users-parties.canton" << 'EOF'
// Canton Console Script for User and Party Setup

// Create ledger users
participant1.users.create("participant_admin", None, None)
participant1.users.create("bank_admin", None, None)
participant1.users.create("alice_user", None, None) 
participant1.users.create("bob_user", None, None)

// Grant rights to users (parties should already exist from your testing)
// Note: Replace with actual party IDs from your setup
val bankParty = "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
val aliceParty = "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
val bobParty = "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"

participant1.users.grant("bank_admin", Some(Set(PartyId.tryFromProtoPrimitive(bankParty))), Some(Set(PartyId.tryFromProtoPrimitive(bankParty))))
participant1.users.grant("alice_user", Some(Set(PartyId.tryFromProtoPrimitive(aliceParty))), Some(Set(PartyId.tryFromProtoPrimitive(aliceParty))))
participant1.users.grant("bob_user", Some(Set(PartyId.tryFromProtoPrimitive(bobParty))), Some(Set(PartyId.tryFromProtoPrimitive(bobParty))))

println("User and party setup completed!")
EOF
    
    echo -e "${YELLOW}📄 Created setup-users-parties.canton script${NC}"
    echo -e "${YELLOW}   Run it manually in Canton console when needed${NC}"
}

# Generate initial JWT tokens
generate_tokens() {
    echo -e "${BLUE}🔑 Generating initial JWT tokens...${NC}"
    
    # Make the JWT manager executable
    chmod +x jwt-manager-production.js
    
    # Generate tokens for all users
    echo "Generating tokens for production users..."
    ./jwt-manager-production.js user-token participant_admin > "${CONFIG_DIR}/admin-token.txt"
    ./jwt-manager-production.js user-token bank_admin > "${CONFIG_DIR}/bank-token.txt"
    ./jwt-manager-production.js user-token alice_user > "${CONFIG_DIR}/alice-token.txt"
    ./jwt-manager-production.js user-token bob_user > "${CONFIG_DIR}/bob-token.txt"
    
    echo -e "${GREEN}✅ Initial tokens generated and saved to config/{{NC}"
}

# Create systemd service files
create_systemd_services() {
    echo -e "${BLUE}🔧 Creating systemd service files...${NC}"
    
    # Canton service
    cat > "${SCRIPT_DIR}/rwa-canton.service" << EOF
[Unit]
Description=RWA Platform - Canton Network
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=forking
User=canton
Group=canton
WorkingDirectory=${SCRIPT_DIR}
Environment="JAVA_OPTS=-Xmx2g -Xms1g"
EnvironmentFile=${CONFIG_DIR}/production.env
ExecStart=/usr/bin/java -jar lib/canton-open-source-2.10.2.jar --config config/canton-production.conf daemon
ExecStop=/bin/kill -TERM \$MAINPID
PIDFile=${PID_DIR}/canton.pid
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # JSON API service
    cat > "${SCRIPT_DIR}/rwa-json-api.service" << EOF
[Unit]
Description=RWA Platform - HTTP JSON API
After=network.target rwa-canton.service
Requires=rwa-canton.service

[Service]
Type=forking  
User=canton
Group=canton
WorkingDirectory=${SCRIPT_DIR}
Environment="JAVA_OPTS=-Xmx1g -Xms512m"
EnvironmentFile=${CONFIG_DIR}/production.env
ExecStart=/usr/bin/java -jar http-json-2.10.2.jar --config config/json-api-production.conf
ExecStop=/bin/kill -TERM \$MAINPID
PIDFile=${PID_DIR}/json-api.pid
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ Systemd service files created${NC}"
    echo -e "${YELLOW}   Copy them to /etc/systemd/system/ and run 'systemctl daemon-reload'${NC}"
}

# Print status
print_status() {
    echo -e "\n${BLUE}📊 System Status:${NC}"
    
    # Check Canton
    if pgrep -f "canton-open-source" > /dev/null; then
        echo -e "${GREEN}✅ Canton is running${NC}"
    else
        echo -e "${RED}❌ Canton is not running${NC}"
    fi
    
    # Check JSON API
    if pgrep -f "http-json" > /dev/null; then
        echo -e "${GREEN}✅ JSON API is running${NC}"
    else
        echo -e "${RED}❌ JSON API is not running${NC}"
    fi
    
    # Show endpoints
    echo -e "\n${BLUE}🌐 Endpoints:${NC}"
    echo "  Canton Ledger API: https://localhost:5011"
    echo "  Canton Admin API:  https://localhost:5012"  
    echo "  Domain Public API: https://localhost:5018"
    echo "  Domain Admin API:  https://localhost:5019"
    echo "  JSON API:          http://localhost:${JSON_API_PORT:-7575}"
    
    # Show log files
    echo -e "\n${BLUE}📄 Log Files:${NC}"
    echo "  Canton:    ${LOG_DIR}/canton-production.log"
    echo "  JSON API:  ${LOG_DIR}/json-api-production.log"
}

# Main deployment function
main() {
    echo -e "${GREEN}🚀 RWA Platform Production Deployment${NC}"
    echo -e "${GREEN}=====================================${NC}\n"
    
    case "${1:-deploy}" in
        "deploy")
            create_directories
            load_environment
            validate_environment
            validate_certificates
            setup_databases
            start_canton
            start_json_api
            setup_canton_users
            generate_tokens
            create_systemd_services
            print_status
            echo -e "\n${GREEN}🎉 Production deployment completed successfully!${NC}"
            ;;
        
        "status")
            print_status
            ;;
            
        "stop")
            echo -e "${BLUE}🛑 Stopping services...${NC}"
            [[ -f "${PID_DIR}/json-api.pid" ]] && kill "$(cat "${PID_DIR}/json-api.pid")" 2>/dev/null || true
            [[ -f "${PID_DIR}/canton.pid" ]] && kill "$(cat "${PID_DIR}/canton.pid")" 2>/dev/null || true
            echo -e "${GREEN}✅ Services stopped${NC}"
            ;;
            
        "restart")
            $0 stop
            sleep 5
            $0 deploy
            ;;
            
        *)
            echo "Usage: $0 {deploy|status|stop|restart}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"