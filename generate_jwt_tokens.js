#!/usr/bin/env node
/**
 * JWT Token Generator for RWA Platform
 * Generates properly signed RS256 JWT tokens for Canton Ledger API
 * Usage: node generate_jwt_tokens.js
 */

const crypto = require('crypto');
const fs = require('fs');

// Configuration
const PRIVATE_KEY_FILE = "config/jwt/jwt-sign.key";
const LEDGER_ID = "participant1";        // Use participant1.ledger_api.ledger_id() output
const APPLICATION_ID = "rwa-json-api";

// Party IDs from your Canton setup (update these with your actual party IDs)
const PARTIES = {
    bank: "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    alice: "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    bob: "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
};

/**
 * Base64 URL encoding without padding
 */
function base64UrlEncode(str) {
    return Buffer.from(str)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

/**
 * Create JWT header
 */
function createJwtHeader() {
    const header = {
        alg: "RS256",
        typ: "JWT"
    };
    return base64UrlEncode(JSON.stringify(header));
}

/**
 * Create JWT payload (Approach 1: User-based with audience & scope)
 */
function createUserJwtPayload(userId, participantId = "participant1", expiryHours = 1) {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        aud: `https://daml.com/jwt/aud/participant/${participantId}`, // target specific participant
        sub: userId,                                                 // Ledger API user ID
        scope: "daml_ledger_api",                                   // Required scope for ledger access
        iat: now,
        exp: now + (expiryHours * 3600)
        // iss omitted for default identity provider 
    };
    return base64UrlEncode(JSON.stringify(payload));
}

/**
 * Create JWT payload (Approach 2: Custom Daml claims with actAs)
 */
function createCustomJwtPayload(actAsParties, participantId = "participant1", expiryHours = 1) {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        "https://daml.com/ledger-api": {
            participantId: participantId,   // restrict to this participant
            actAs: actAsParties            // list of party IDs this token can act as
        },
        aud: `https://daml.com/jwt/aud/participant/${participantId}`, // audience claim
        scope: "daml_ledger_api",                                   // required scope
        iat: now,
        exp: now + (expiryHours * 3600)
        // iss omitted for default identity provider
    };
    return base64UrlEncode(JSON.stringify(payload));
}

/**
 * Sign JWT using RS256
 */
function signJwt(header, payload, privateKey) {
    const data = `${header}.${payload}`;
    const signature = crypto.sign('RSA-SHA256', Buffer.from(data), privateKey);
    return base64UrlEncode(signature);
}

/**
 * Create a JWT token using custom Daml claims (actAs approach)
 */
function createJwt(actAsParties, expiryHours = 1) {
    try {
        // Read private key
        if (!fs.existsSync(PRIVATE_KEY_FILE)) {
            throw new Error(`Private key file not found: ${PRIVATE_KEY_FILE}`);
        }
        
        const privateKey = fs.readFileSync(PRIVATE_KEY_FILE, 'utf8');
        
        // Create JWT components using custom Daml claims
        const header = createJwtHeader();
        const payload = createCustomJwtPayload(actAsParties, LEDGER_ID, expiryHours);
        const signature = signJwt(header, payload, privateKey);
        
        return `${header}.${payload}.${signature}`;
    } catch (error) {
        console.error(`Error creating JWT: ${error.message}`);
        process.exit(1);
    }
}

/**
 * Create a JWT token using user-based approach
 */
function createUserJwt(userId, expiryHours = 1) {
    try {
        // Read private key
        if (!fs.existsSync(PRIVATE_KEY_FILE)) {
            throw new Error(`Private key file not found: ${PRIVATE_KEY_FILE}`);
        }
        
        const privateKey = fs.readFileSync(PRIVATE_KEY_FILE, 'utf8');
        
        // Create JWT components using user-based approach
        const header = createJwtHeader();
        const payload = createUserJwtPayload(userId, LEDGER_ID, expiryHours);
        const signature = signJwt(header, payload, privateKey);
        
        return `${header}.${payload}.${signature}`;
    } catch (error) {
        console.error(`Error creating user JWT: ${error.message}`);
        process.exit(1);
    }
}

/**
 * Generate all required tokens for RWA platform operations
 */
function generateAllTokens() {
    const tokens = {};
    
    console.log("=== RWA Platform JWT Token Generator ===\n");
    console.log(`Ledger ID: ${LEDGER_ID}`);
    console.log(`Application ID: ${APPLICATION_ID}`);
    console.log(`Private Key: ${PRIVATE_KEY_FILE}`);
    console.log();
    
    // Individual party tokens using actAs approach
    console.log("📝 Generating individual party tokens (actAs approach)...");
    tokens.bank = createJwt([PARTIES.bank]);
    tokens.alice = createJwt([PARTIES.alice]);
    tokens.bob = createJwt([PARTIES.bob]);
    
    console.log("✅ Bank token generated");
    console.log("✅ Alice token generated");
    console.log("✅ Bob token generated");
    console.log();
    
    // Multi-party tokens for operations requiring both user and admin
    console.log("🔐 Generating multi-party tokens (actAs approach)...");
    tokens.bank_alice = createJwt([PARTIES.bank, PARTIES.alice]);
    tokens.bank_bob = createJwt([PARTIES.bank, PARTIES.bob]);
    
    console.log("✅ Bank+Alice token generated");
    console.log("✅ Bank+Bob token generated");
    console.log();
    
    // Admin token using user-based approach (as fallback)
    console.log("👑 Generating admin token (user-based approach)...");
    tokens.admin = createUserJwt("participant_admin");
    
    console.log("✅ Admin token generated (participant_admin)");
    console.log();
    
    return tokens;
}

/**
 * Save tokens to a JSON file for easy access
 */
function saveTokensToFile(tokens, filename = "jwt-tokens.json") {
    try {
        fs.writeFileSync(filename, JSON.stringify(tokens, null, 2));
        console.log(`💾 Tokens saved to ${filename}`);
    } catch (error) {
        console.error(`Error saving tokens: ${error.message}`);
    }
}

/**
 * Print tokens in a format suitable for shell variables
 */
function printTokens(tokens) {
    console.log("=== JWT Tokens for RWA Platform ===\n");
    
    console.log("🏦 BANK TOKEN:");
    console.log(`export BANK_TOKEN="${tokens.bank}"\n`);
    
    console.log("👩 ALICE TOKEN:");
    console.log(`export ALICE_TOKEN="${tokens.alice}"\n`);
    
    console.log("👨 BOB TOKEN:");
    console.log(`export BOB_TOKEN="${tokens.bob}"\n`);
    
    console.log("🏦👩 BANK+ALICE TOKEN (for transfers/redemptions by Alice):");
    console.log(`export BANK_ALICE_TOKEN="${tokens.bank_alice}"\n`);
    
    console.log("🏦👨 BANK+BOB TOKEN (for transfers by Bob):");
    console.log(`export BANK_BOB_TOKEN="${tokens.bank_bob}"\n`);
    
    console.log("👑 ADMIN TOKEN (user-based with participant_admin):");
    console.log(`export ADMIN_TOKEN="${tokens.admin}"\n`);
    
    console.log("💡 Usage in curl commands:");
    console.log("curl -H \"Authorization: Bearer $BANK_TOKEN\" ...");
    console.log("curl -H \"Authorization: Bearer $BANK_ALICE_TOKEN\" ...");
    console.log("curl -H \"Authorization: Bearer $ADMIN_TOKEN\" ...");
}

/**
 * Create a shell script to export all tokens as environment variables
 */
function createShellScript(tokens) {
    const now = new Date().toISOString().replace('T', ' ').substring(0, 19) + ' UTC';
    const scriptContent = `#!/bin/bash
# RWA Platform JWT Tokens
# Generated on ${now}

export BANK_TOKEN="${tokens.bank}"
export ALICE_TOKEN="${tokens.alice}"
export BOB_TOKEN="${tokens.bob}"
export BANK_ALICE_TOKEN="${tokens.bank_alice}"
export BANK_BOB_TOKEN="${tokens.bank_bob}"
export ADMIN_TOKEN="${tokens.admin}"

echo "🔑 RWA JWT tokens loaded into environment"
echo "📋 Available tokens: BANK_TOKEN, ALICE_TOKEN, BOB_TOKEN, BANK_ALICE_TOKEN, BANK_BOB_TOKEN, ADMIN_TOKEN"
`;
    
    try {
        fs.writeFileSync("load_jwt_tokens.sh", scriptContent);
        fs.chmodSync("load_jwt_tokens.sh", 0o755);
        console.log("📜 Shell script created: load_jwt_tokens.sh");
        console.log("   Usage: source ./load_jwt_tokens.sh");
    } catch (error) {
        console.error(`Error creating shell script: ${error.message}`);
    }
}

/**
 * Create curl example commands
 */
function createCurlExamples() {
    const examples = `#!/bin/bash
# RWA Platform - JSON API Curl Examples
# Load tokens first: source ./load_jwt_tokens.sh

# Package ID from your RWA contract
RWA_PACKAGE_ID="323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1"

echo "=== RWA Platform JSON API Examples ==="
echo

echo "1. Create Gold Registry (Bank)"
echo "curl -X POST http://localhost:7575/v1/create \\\\"
echo "  -H \"Authorization: Bearer \$BANK_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateId\": \"\$RWA_PACKAGE_ID:TokenExample:AssetRegistry\","
echo "    \"payload\": {"
echo "      \"admin\": \"${PARTIES.bank}\","
echo "      \"name\": \"Gold Token\","
echo "      \"symbol\": \"GLD\""
echo "    }"
echo "  }'"
echo

echo "2. Mint 100 Gold tokens to Alice (Bank)"
echo "curl -X POST http://localhost:7575/v1/exercise \\\\"
echo "  -H \"Authorization: Bearer \$BANK_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateId\": \"\$RWA_PACKAGE_ID:TokenExample:AssetRegistry\","
echo "    \"contractId\": \"[GOLD_REGISTRY_CONTRACT_ID]\","
echo "    \"choice\": \"Mint\","
echo "    \"argument\": {"
echo "      \"to\": \"${PARTIES.alice}\","
echo "      \"amount\": 100"
echo "    }"
echo "  }'"
echo

echo "3. Transfer 30 Gold from Alice to Bob (requires Bank+Alice token)"
echo "curl -X POST http://localhost:7575/v1/exercise \\\\"
echo "  -H \"Authorization: Bearer \$BANK_ALICE_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateId\": \"\$RWA_PACKAGE_ID:TokenExample:AssetRegistry\","
echo "    \"contractId\": \"[GOLD_REGISTRY_CONTRACT_ID]\","
echo "    \"choice\": \"Transfer\","
echo "    \"argument\": {"
echo "      \"sender\": \"${PARTIES.alice}\","
echo "      \"recipient\": \"${PARTIES.bob}\","
echo "      \"amount\": 30"
echo "    }"
echo "  }'"
echo

echo "4. Query Alice's tokens"
echo "curl -X POST http://localhost:7575/v1/query \\\\"
echo "  -H \"Authorization: Bearer \$ALICE_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateIds\": [\"\$RWA_PACKAGE_ID:TokenExample:Token\"],"
echo "    \"query\": {"
echo "      \"owner\": \"${PARTIES.alice}\""
echo "    }"
echo "  }'"
echo

echo "5. Request redemption of 50 Gold tokens (Alice - requires Bank+Alice token)"
echo "curl -X POST http://localhost:7575/v1/exercise \\\\"
echo "  -H \"Authorization: Bearer \$BANK_ALICE_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateId\": \"\$RWA_PACKAGE_ID:TokenExample:AssetRegistry\","
echo "    \"contractId\": \"[GOLD_REGISTRY_CONTRACT_ID]\","
echo "    \"choice\": \"RequestRedemption\","
echo "    \"argument\": {"
echo "      \"redeemer\": \"${PARTIES.alice}\","
echo "      \"amount\": 50"
echo "    }"
echo "  }'"
echo

echo "6. Accept redemption (Bank)"
echo "curl -X POST http://localhost:7575/v1/exercise \\\\"
echo "  -H \"Authorization: Bearer \$BANK_TOKEN\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -d '{"
echo "    \"templateId\": \"\$RWA_PACKAGE_ID:TokenExample:RedeemRequest\","
echo "    \"contractId\": \"[REDEEM_REQUEST_CONTRACT_ID]\","
echo "    \"choice\": \"Accept\","
echo "    \"argument\": {}"
echo "  }'"
echo
`;

    try {
        fs.writeFileSync("curl_examples.sh", examples);
        fs.chmodSync("curl_examples.sh", 0o755);
        console.log("📋 Curl examples created: curl_examples.sh");
    } catch (error) {
        console.error(`Error creating curl examples: ${error.message}`);
    }
}

// Main execution
try {
    // Generate all tokens
    const tokens = generateAllTokens();
    
    // Save to JSON file
    saveTokensToFile(tokens);
    
    // Create shell script
    createShellScript(tokens);
    
    // Create curl examples
    createCurlExamples();
    
    // Print tokens for manual use
    printTokens(tokens);
    
    console.log("\n🎉 JWT token generation completed successfully!");
    console.log("📖 Next steps:");
    console.log("   1. Source the tokens: source ./load_jwt_tokens.sh");
    console.log("   2. Start JSON API service");
    console.log("   3. Test with curl commands using the tokens");
    console.log("   4. See curl_examples.sh for ready-to-use commands");
    
} catch (error) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
}