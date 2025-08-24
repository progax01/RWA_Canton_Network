#!/usr/bin/env python3
import json
import base64
import hmac
import hashlib

def create_jwt_token(party, full_party_id):
    # JWT Header
    header = {
        "alg": "HS256",
        "typ": "JWT"
    }
    
    # JWT Payload
    payload = {
        "https://daml.com/ledger-api": {
            "ledgerId": "participant1",
            "applicationId": "json-api",
            "actAs": [full_party_id]
        }
    }
    
    # Encode header and payload
    encoded_header = base64.urlsafe_b64encode(json.dumps(header, separators=(',', ':')).encode()).decode().rstrip('=')
    encoded_payload = base64.urlsafe_b64encode(json.dumps(payload, separators=(',', ':')).encode()).decode().rstrip('=')
    
    # Create signature (using a simple secret for development)
    secret = "development-secret"
    signature = base64.urlsafe_b64encode(
        hmac.new(
            secret.encode(), 
            f"{encoded_header}.{encoded_payload}".encode(), 
            hashlib.sha256
        ).digest()
    ).decode().rstrip('=')
    
    return f"{encoded_header}.{encoded_payload}.{signature}"

# Create tokens for each party with full party IDs
parties = {
    "Alice": "Alice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "Bob": "Bob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "Bank": "Bank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
}
tokens = {}

for party, full_id in parties.items():
    tokens[party] = create_jwt_token(party, full_id)
    print(f"{party} token: {tokens[party]}")

# Save tokens to file for easy access
with open('jwt-tokens.json', 'w') as f:
    json.dump(tokens, f, indent=2)

print("\nTokens saved to jwt-tokens.json")