#!/bin/bash
# Test JWT authentication with JSON API

source ./load_jwt_tokens.sh

echo "🧪 Testing JWT authentication with JSON API..."
echo

# Package ID from your RWA contract
RWA_PACKAGE_ID="323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1"

echo "1. Testing health check (no auth required)..."
curl -s http://localhost:7575/livez
echo
echo

echo "2. Testing authenticated endpoint - List packages..."
curl -s -X GET http://localhost:7575/v1/packages \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json"
echo
echo

echo "3. Testing contract creation - Gold Registry..."
curl -s -X POST http://localhost:7575/v1/create \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"templateId\": \"$RWA_PACKAGE_ID:TokenExample:AssetRegistry\",
    \"payload\": {
      \"admin\": \"NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d\",
      \"name\": \"Gold Token\",
      \"symbol\": \"GLD\"
    }
  }"
echo
echo

echo "4. Testing query - Alice's tokens..."
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"templateIds\": [\"$RWA_PACKAGE_ID:TokenExample:Token\"],
    \"query\": {
      \"owner\": \"NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d\"
    }
  }"
echo
echo

echo "✅ JWT API testing completed!"