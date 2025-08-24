#!/usr/bin/env python3
"""
JWT Token Generator for RWA Platform
Generates properly signed RS256 JWT tokens for Canton Ledger API
"""
import json
import jwt
import datetime
import os

PRIVATE_KEY_FILE = "config/jwt/jwt-sign.key"
LEDGER_ID = "participant1"        # Use participant1.ledger_api.ledger_id() output
APPLICATION_ID = "rwa-json-api"

# Party IDs from your Canton setup (update these with your actual party IDs)
PARTIES = {
    "bank": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "alice": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "bob": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
}

def create_jwt(act_as_parties, expiry_hours=1):
    """
    Create a JWT token signed with RS256
    
    Args:
        act_as_parties: List of party IDs that can act as
        expiry_hours: Token expiry time in hours
    
    Returns:
        JWT token string
    """
    if not os.path.exists(PRIVATE_KEY_FILE):
        raise FileNotFoundError(f"Private key file not found: {PRIVATE_KEY_FILE}")
    
    with open(PRIVATE_KEY_FILE, 'r') as f:
        private_key = f.read()
    
    payload = {
        "https://daml.com/ledger-api": {
            "ledgerId": LEDGER_ID,
            "applicationId": APPLICATION_ID,
            "actAs": act_as_parties,
        },
        # Token expiry
        "exp": int((datetime.datetime.utcnow() + datetime.timedelta(hours=expiry_hours)).timestamp()),
        # Issue time
        "iat": int(datetime.datetime.utcnow().timestamp()),
        # Issuer
        "iss": "rwa-platform"
    }
    
    return jwt.encode(payload, private_key, algorithm="RS256")

def generate_all_tokens():
    """Generate all required tokens for RWA platform operations"""
    
    tokens = {}
    
    print("=== RWA Platform JWT Token Generator ===\n")
    print(f"Ledger ID: {LEDGER_ID}")
    print(f"Application ID: {APPLICATION_ID}")
    print(f"Private Key: {PRIVATE_KEY_FILE}")
    print()
    
    # Individual party tokens
    print("📝 Generating individual party tokens...")
    tokens['bank'] = create_jwt([PARTIES['bank']])
    tokens['alice'] = create_jwt([PARTIES['alice']])  
    tokens['bob'] = create_jwt([PARTIES['bob']])
    
    print(f"✅ Bank token generated")
    print(f"✅ Alice token generated")
    print(f"✅ Bob token generated")
    print()
    
    # Multi-party tokens for operations requiring both user and admin
    print("🔐 Generating multi-party tokens...")
    tokens['bank_alice'] = create_jwt([PARTIES['bank'], PARTIES['alice']])
    tokens['bank_bob'] = create_jwt([PARTIES['bank'], PARTIES['bob']])
    
    print(f"✅ Bank+Alice token generated")
    print(f"✅ Bank+Bob token generated")
    print()
    
    return tokens

def save_tokens_to_file(tokens, filename="jwt-tokens.json"):
    """Save tokens to a JSON file for easy access"""
    with open(filename, 'w') as f:
        json.dump(tokens, f, indent=2)
    print(f"💾 Tokens saved to {filename}")

def print_tokens(tokens):
    """Print tokens in a format suitable for shell variables"""
    print("=== JWT Tokens for RWA Platform ===\n")
    
    print("🏦 BANK TOKEN:")
    print(f"export BANK_TOKEN=\"{tokens['bank']}\"\n")
    
    print("👩 ALICE TOKEN:")  
    print(f"export ALICE_TOKEN=\"{tokens['alice']}\"\n")
    
    print("👨 BOB TOKEN:")
    print(f"export BOB_TOKEN=\"{tokens['bob']}\"\n")
    
    print("🏦👩 BANK+ALICE TOKEN (for transfers/redemptions by Alice):")
    print(f"export BANK_ALICE_TOKEN=\"{tokens['bank_alice']}\"\n")
    
    print("🏦👨 BANK+BOB TOKEN (for transfers by Bob):")
    print(f"export BANK_BOB_TOKEN=\"{tokens['bank_bob']}\"\n")
    
    print("💡 Usage in curl commands:")
    print("curl -H \"Authorization: Bearer $BANK_TOKEN\" ...")
    print("curl -H \"Authorization: Bearer $BANK_ALICE_TOKEN\" ...")

def create_shell_script(tokens):
    """Create a shell script to export all tokens as environment variables"""
    script_content = f"""#!/bin/bash
# RWA Platform JWT Tokens
# Generated on {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

export BANK_TOKEN="{tokens['bank']}"
export ALICE_TOKEN="{tokens['alice']}"
export BOB_TOKEN="{tokens['bob']}"
export BANK_ALICE_TOKEN="{tokens['bank_alice']}"
export BANK_BOB_TOKEN="{tokens['bank_bob']}"

echo "🔑 RWA JWT tokens loaded into environment"
echo "📋 Available tokens: BANK_TOKEN, ALICE_TOKEN, BOB_TOKEN, BANK_ALICE_TOKEN, BANK_BOB_TOKEN"
"""
    
    with open("load_jwt_tokens.sh", 'w') as f:
        f.write(script_content)
    
    # Make the script executable
    os.chmod("load_jwt_tokens.sh", 0o755)
    print("📜 Shell script created: load_jwt_tokens.sh")
    print("   Usage: source ./load_jwt_tokens.sh")

if __name__ == "__main__":
    try:
        # Generate all tokens
        tokens = generate_all_tokens()
        
        # Save to JSON file
        save_tokens_to_file(tokens)
        
        # Create shell script
        create_shell_script(tokens)
        
        # Print tokens for manual use
        print_tokens(tokens)
        
        print("\n🎉 JWT token generation completed successfully!")
        print("📖 Next steps:")
        print("   1. Source the tokens: source ./load_jwt_tokens.sh")
        print("   2. Start JSON API service")
        print("   3. Test with curl commands using the tokens")
        
    except Exception as e:
        print(f"❌ Error generating tokens: {e}")
        exit(1)