#!/bin/bash

# Test script to verify JWT token generation and JSON API setup
# This script validates the JWT tokens and provides examples of usage

echo "JWT Token Generation and JSON API Setup - Test Script"
echo "======================================================"

# Check if JWT tokens were generated
echo "1. Checking JWT token files..."
for token_file in participant_admin-jwt-token.txt bank_admin-jwt-token.txt alice_user-jwt-token.txt bob_user-jwt-token.txt; do
    if [ -f "$token_file" ]; then
        echo "✓ $token_file exists ($(wc -c < "$token_file") bytes)"
    else
        echo "✗ $token_file missing"
    fi
done

# Check if JWT tokens JSON file exists
if [ -f "jwt-tokens.json" ]; then
    echo "✓ jwt-tokens.json exists ($(wc -c < "jwt-tokens.json") bytes)"
else
    echo "✗ jwt-tokens.json missing"
fi

# Check if shell-friendly tokens exist
if [ -f "jwt-tokens-shell.txt" ]; then
    echo "✓ jwt-tokens-shell.txt exists and is executable: $(test -x jwt-tokens-shell.txt && echo yes || echo no)"
else
    echo "✗ jwt-tokens-shell.txt missing"
fi

echo ""
echo "2. Validating JWT token structure..."

# Load tokens and validate structure using Node.js
if [ -f "jwt-tokens.json" ]; then
    node -e "
    const fs = require('fs');
    const jwt = require('jsonwebtoken');
    
    try {
        const tokens = JSON.parse(fs.readFileSync('jwt-tokens.json', 'utf8'));
        
        for (const [user, token] of Object.entries(tokens)) {
            const decoded = jwt.decode(token, { complete: true });
            const payload = decoded.payload;
            const damlClaims = payload['https://daml.com/ledger-api'];
            
            console.log(\`✓ \${user}: Valid JWT structure\`);
            console.log(\`  - Ledger ID: \${damlClaims.ledgerId}\`);
            console.log(\`  - Application ID: \${damlClaims.applicationId}\`);
            
            if (damlClaims.admin) {
                console.log(\`  - Admin privileges: true\`);
            }
            if (damlClaims.actAs) {
                console.log(\`  - Can act as: \${damlClaims.actAs.length} parties\`);
            }
            if (damlClaims.readAs) {
                console.log(\`  - Can read as: \${damlClaims.readAs.length} parties\`);
            }
            console.log('');
        }
    } catch (error) {
        console.error('Error validating tokens:', error.message);
    }
    "
fi

echo "3. Checking prerequisites for JSON API..."

# Check if JSON API jar exists
if [ -f "http-json-2.10.2.jar" ]; then
    echo "✓ http-json-2.10.2.jar exists ($(du -h http-json-2.10.2.jar | cut -f1))"
else
    echo "✗ http-json-2.10.2.jar missing"
fi

# Check if TLS certificates exist
if [ -f "config/tls/root-ca.crt" ]; then
    echo "✓ Root CA certificate exists"
    echo "  Certificate info:"
    openssl x509 -in config/tls/root-ca.crt -noout -subject -dates 2>/dev/null || echo "  Could not read certificate details"
else
    echo "✗ Root CA certificate missing at config/tls/root-ca.crt"
fi

# Check if JWT signing key exists
if [ -f "config/jwt/jwt-sign.key" ]; then
    echo "✓ JWT signing key exists"
else
    echo "✗ JWT signing key missing at config/jwt/jwt-sign.key"
fi

# Check if party mappings exist
if [ -f "config/user-party-mappings.json" ]; then
    echo "✓ Party mappings file exists"
    echo "  Party mappings:"
    cat config/user-party-mappings.json | jq -r 'to_entries[] | "  - \(.key): \(.value | length) parties"' 2>/dev/null || \
        echo "  Could not parse party mappings (jq not available)"
else
    echo "✗ Party mappings missing at config/user-party-mappings.json"
fi

echo ""
echo "4. Usage examples:"
echo ""
echo "To start the JSON API server:"
echo "  ./start_json_api.sh"
echo ""
echo "To test with curl (using Alice's token):"
echo "  ALICE_TOKEN=\$(cat alice_user-jwt-token.txt)"
echo "  curl -H \"Authorization: Bearer \$ALICE_TOKEN\" \\"
echo "       -H \"Content-Type: application/json\" \\"
echo "       http://localhost:7575/v1/query"
echo ""
echo "To use tokens in shell scripts:"
echo "  source jwt-tokens-shell.txt"
echo "  echo \"Alice token: \$ALICE_USER_TOKEN\""
echo ""
echo "======================================================"
echo "Setup validation complete!"