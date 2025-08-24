#!/bin/bash
# RWA Platform JSON API Curl Examples (load tokens first: source ./load_jwt_tokens.sh)
echo "4800. Create Gold Registry (Bank):"
echo "curl -X POST http://localhost:7575/v1/create \\"
echo "  -H \"Authorization: Bearer $BANK_TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"templateId\": "$RWA_PACKAGE_ID:TokenExample:AssetRegistry", \"payload\": {\"admin\": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", \"name\": "Gold Token", \"symbol\": "GLD"}}'"
# ... (additional examples trimmed for brevity)
