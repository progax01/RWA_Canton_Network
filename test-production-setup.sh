#!/bin/bash
# Production Setup Testing Script
# Tests all components of the RWA Platform production deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "\n${BLUE}🧪 Testing: $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Load environment variables
load_environment() {
    if [[ -f "${CONFIG_DIR}/production.env" ]]; then
        source "${CONFIG_DIR}/production.env"
    else
        echo -e "${YELLOW}⚠️ No production environment file found, using defaults${NC}"
    fi
}

# Test 1: Environment Variables
test_environment() {
    [[ -n "$CANTON_DB_USER" ]] && 
    [[ -n "$CANTON_DB_PASSWORD" ]] && 
    [[ -n "$JSON_API_DB_USER" ]] && 
    [[ -n "$JSON_API_DB_PASSWORD" ]]
}

# Test 2: TLS Certificates
test_certificates() {
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
        "config/jwt/jwt-sign.crt"
        "config/jwt/jwt-sign.key"
    )
    
    for cert_file in "${cert_files[@]}"; do
        [[ -f "$cert_file" ]] || return 1
        
        # Validate certificate format
        if [[ "$cert_file" == *.crt ]]; then
            openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1 || return 1
        fi
    done
    
    return 0
}

# Test 3: Database Connectivity
test_database() {
    # Test Canton database
    PGPASSWORD="${CANTON_DB_PASSWORD}" psql -h localhost -U "${CANTON_DB_USER}" -d canton_participant -c "SELECT 1;" >/dev/null 2>&1 || return 1
    PGPASSWORD="${CANTON_DB_PASSWORD}" psql -h localhost -U "${CANTON_DB_USER}" -d canton_domain -c "SELECT 1;" >/dev/null 2>&1 || return 1
    
    # Test JSON API database
    PGPASSWORD="${JSON_API_DB_PASSWORD}" psql -h localhost -U "${JSON_API_DB_USER}" -d json_api_store -c "SELECT 1;" >/dev/null 2>&1 || return 1
    
    return 0
}

# Test 4: Canton Services
test_canton_services() {
    # Check if Canton process is running
    pgrep -f "canton-open-source" >/dev/null || return 1
    
    # Test ledger API connectivity (may take time to start)
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -k -s --connect-timeout 5 "https://localhost:5011/readyz" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    return 1
}

# Test 5: JSON API Service
test_json_api() {
    # Check if JSON API process is running
    pgrep -f "http-json" >/dev/null || return 1
    
    # Test JSON API connectivity
    local max_attempts=5
    local attempt=1
    local port="${JSON_API_PORT:-7575}"
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --connect-timeout 5 "http://localhost:${port}/livez" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    return 1
}

# Test 6: JWT Token Generation
test_jwt_generation() {
    [[ -x "./jwt-manager-production.js" ]] || return 1
    
    # Test token generation for different users
    local users=("participant_admin" "bank_admin" "alice_user" "bob_user")
    
    for user in "${users[@]}"; do
        local token
        token=$(./jwt-manager-production.js user-token "$user" 2>/dev/null) || return 1
        
        # Basic token format validation
        [[ "$token" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]] || return 1
        
        # Validate token
        ./jwt-manager-production.js validate "$token" >/dev/null 2>&1 || return 1
    done
    
    return 0
}

# Test 7: Configuration Files
test_configuration_files() {
    [[ -f "config/canton-production.conf" ]] || return 1
    [[ -f "config/json-api-production.conf" ]] || return 1
    [[ -f "config/user-party-mappings.json" ]] || return 1
    [[ -f "config/nginx-rwa-api.conf" ]] || return 1
    
    # Validate JSON syntax
    python3 -m json.tool config/user-party-mappings.json >/dev/null 2>&1 || return 1
    
    return 0
}

# Test 8: API Endpoints (if JSON API is running)
test_api_endpoints() {
    local port="${JSON_API_PORT:-7575}"
    local base_url="http://localhost:${port}"
    
    # Test health endpoint
    curl -s --connect-timeout 5 "${base_url}/livez" | grep -q "OK" || return 1
    
    # Test with JWT token (basic endpoint test)
    local token
    token=$(./jwt-manager-production.js user-token "participant_admin" 2>/dev/null) || return 1
    
    # Test parties endpoint (should return 200 even if empty)
    curl -s -w "%{http_code}" -H "Authorization: Bearer $token" \
        "${base_url}/v1/parties" | grep -q "200" || return 1
    
    return 0
}

# Test 9: Log Files
test_log_files() {
    [[ -d "log" ]] || return 1
    [[ -f "log/canton-production.log" ]] || [[ -f "log/canton.log" ]] || return 1
    
    return 0
}

# Test 10: File Permissions
test_file_permissions() {
    [[ -x "deploy-production.sh" ]] || return 1
    [[ -x "jwt-manager-production.js" ]] || return 1
    
    # Check sensitive files are not world-readable
    [[ $(stat -c %a "config/jwt/jwt-sign.key") == "600" ]] || 
    [[ $(stat -c %a "config/jwt/jwt-sign.key") == "640" ]] || return 1
    
    return 0
}

# Performance Test: Token Generation Speed
test_performance() {
    echo -e "${BLUE}⏱️ Performance test: Generating 10 tokens...${NC}"
    
    local start_time=$(date +%s.%N)
    
    for i in {1..10}; do
        ./jwt-manager-production.js user-token "participant_admin" >/dev/null 2>&1 || return 1
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo -e "${GREEN}⏱️ Generated 10 tokens in ${duration} seconds${NC}"
    
    # Should be able to generate tokens reasonably fast (less than 5 seconds for 10 tokens)
    (( $(echo "$duration < 5.0" | bc -l) )) || return 1
    
    return 0
}

# Integration Test: Complete API workflow
test_integration() {
    echo -e "${BLUE}🔄 Integration test: Complete API workflow...${NC}"
    
    local port="${JSON_API_PORT:-7575}"
    local base_url="http://localhost:${port}"
    
    # Generate token
    local token
    token=$(./jwt-manager-production.js user-token "bank_admin" 2>/dev/null) || return 1
    
    # Test parties endpoint
    local parties_response
    parties_response=$(curl -s -H "Authorization: Bearer $token" "${base_url}/v1/parties") || return 1
    
    # Validate JSON response
    echo "$parties_response" | python3 -m json.tool >/dev/null 2>&1 || return 1
    
    echo -e "${GREEN}✅ Integration test completed successfully${NC}"
    return 0
}

# Main test runner
main() {
    echo -e "${GREEN}🧪 RWA Platform Production Setup Testing${NC}"
    echo -e "${GREEN}=========================================${NC}\n"
    
    load_environment
    
    # Run all tests
    run_test "Environment Variables" "test_environment"
    run_test "TLS Certificates" "test_certificates"
    run_test "Database Connectivity" "test_database"
    run_test "Configuration Files" "test_configuration_files"
    run_test "File Permissions" "test_file_permissions"
    run_test "JWT Token Generation" "test_jwt_generation"
    run_test "Canton Services" "test_canton_services"
    run_test "JSON API Service" "test_json_api"
    run_test "Log Files" "test_log_files"
    run_test "API Endpoints" "test_api_endpoints"
    run_test "Performance" "test_performance"
    run_test "Integration Workflow" "test_integration"
    
    # Summary
    echo -e "\n${BLUE}📊 Test Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed! Production setup is ready.${NC}"
        exit 0
    else
        echo -e "\n${RED}⚠️ Some tests failed. Please review the issues above.${NC}"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "quick")
        echo -e "${BLUE}🏃 Quick test (basic checks only)${NC}"
        load_environment
        run_test "Environment Variables" "test_environment"
        run_test "TLS Certificates" "test_certificates"
        run_test "Configuration Files" "test_configuration_files"
        run_test "JWT Token Generation" "test_jwt_generation"
        ;;
    "integration")
        echo -e "${BLUE}🔄 Integration test only${NC}"
        load_environment
        run_test "Integration Workflow" "test_integration"
        ;;
    *)
        echo "Usage: $0 {run|quick|integration}"
        echo "  run         - Run all tests (default)"
        echo "  quick       - Run basic checks only"
        echo "  integration - Run integration test only"
        exit 1
        ;;
esac