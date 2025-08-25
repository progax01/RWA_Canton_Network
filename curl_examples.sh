#!/bin/bash

# Simple curl examples for testing Canton JSON API with JWT tokens
# Usage: source this file to get environment variables, then use the example commands

# Load tokens if available
if [ -f "jwt-tokens.json" ]; then
    export PARTICIPANT_ADMIN_TOKEN=$(jq -r '.participant_admin // empty' jwt-tokens.json)
    export BANK_ADMIN_TOKEN=$(jq -r '.bank_admin // empty' jwt-tokens.json)
    export ALICE_USER_TOKEN=$(jq -r '.alice_user // empty' jwt-tokens.json)
    export BOB_USER_TOKEN=$(jq -r '.bob_user // empty' jwt-tokens.json)
    echo "✓ Tokens loaded from jwt-tokens.json"
else
    echo "⚠ jwt-tokens.json not found. Generate tokens first with: node generateJWT.js"
fi

# JSON API URL
export JSON_API_URL="http://localhost:7575"

echo "=== QUICK CURL EXAMPLES ==="
echo "1. Health check:"
echo "curl \$JSON_API_URL/readyz"
echo ""
echo "2. Query parties as Alice:"
echo "curl -H \"Authorization: Bearer \$ALICE_USER_TOKEN\" \$JSON_API_URL/v1/parties"
echo ""
echo "3. Query active contracts as Alice:"
echo "curl -X POST -H \"Authorization: Bearer \$ALICE_USER_TOKEN\" -H \"Content-Type: application/json\" -d '{\"templateIds\": [], \"query\": {}}' \$JSON_API_URL/v1/query"
echo ""
echo "4. List packages (admin):"
echo "curl -H \"Authorization: Bearer \$PARTICIPANT_ADMIN_TOKEN\" \$JSON_API_URL/v1/packages"