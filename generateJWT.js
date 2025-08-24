#!/usr/bin/env node
/**
 * JWT Token Generator for RWA Platform (Corrected Version)
 * Generates RS256 JWT tokens for Canton Ledger API with proper claims.
 */

const crypto = require('crypto');
const fs = require('fs');

// Configuration (make sure these match your Canton participant settings)
const PRIVATE_KEY_FILE = "config/jwt/jwt-sign.key";
const LEDGER_ID = "participant1";  // Use logical participant name for custom claims
const APPLICATION_ID = "rwa-json-api";    // Application ID for command submissions:contentReference[oaicite:12]{index=12}

// Party IDs from your Canton setup (replace with actual party IDs)
const PARTIES = {
    bank:  "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    alice: "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    bob:   "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
};

/** Base64 URL encoding without padding */
function base64UrlEncode(str) {
    return Buffer.from(str).toString('base64')
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

/** Create JWT header */
function createJwtHeader() {
    const header = { alg: "RS256", typ: "JWT" };
    return base64UrlEncode(JSON.stringify(header));
}

/** Create JWT payload for a user-based token (audience & scope approach) */
function createUserJwtPayload(userId, participantId = LEDGER_ID, expiryHours = 4800) {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        aud: `https://daml.com/jwt/aud/participant/${participantId}`,  // audience must include correct participant ID:contentReference[oaicite:13]{index=13}
        sub: userId,                      // Ledger API user ID (participant user)
        scope: "daml_ledger_api",         // Required scope for ledger API access
        iat: now,
        exp: now + expiryHours * 3600
        // Note: iss (issuer) is omitted for the default identity provider
    };
    return base64UrlEncode(JSON.stringify(payload));
}

/** Create JWT payload for custom Daml claims (actAs approach) */
function createCustomJwtPayload(actAsParties, participantId = LEDGER_ID, expiryHours = 4800) {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        "https://daml.com/ledger-api": {
            participantId: participantId,       // restrict token to this participant/ledger:contentReference[oaicite:14]{index=14}
            actAs: actAsParties,               // parties that this token can actAs
            applicationId: APPLICATION_ID      // include applicationId for command submissions:contentReference[oaicite:15]{index=15}
        },
        aud: `https://daml.com/jwt/aud/participant/${participantId}`,   // audience claim for participant
        scope: "daml_ledger_api",   // required for Canton configuration
        iat: now,
        exp: now + expiryHours * 3600
        // iss omitted for default identity provider
    };
    return base64UrlEncode(JSON.stringify(payload));
}

/** Sign JWT (RS256) */
function signJwt(header, payload, privateKeyPem) {
    const data = `${header}.${payload}`;
    const signature = crypto.sign('RSA-SHA256', Buffer.from(data), privateKeyPem);
    return base64UrlEncode(signature);
}

/** Create a JWT using custom Daml claims (for specific actAs parties) */
function createJwt(actAsParties, expiryHours = 4800) {
    // Load signing key
    if (!fs.existsSync(PRIVATE_KEY_FILE)) {
        throw new Error(`Private key file not found: ${PRIVATE_KEY_FILE}`);
    }
    const privateKey = fs.readFileSync(PRIVATE_KEY_FILE, 'utf8');
    // Build token
    const header = createJwtHeader();
    const payload = createCustomJwtPayload(actAsParties, LEDGER_ID, expiryHours);
    const signature = signJwt(header, payload, privateKey);
    return `${header}.${payload}.${signature}`;
}

/** Create a JWT token for a participant user (using userId approach) */
function createUserJwt(userId, expiryHours = 4800) {
    if (!fs.existsSync(PRIVATE_KEY_FILE)) {
        throw new Error(`Private key file not found: ${PRIVATE_KEY_FILE}`);
    }
    const privateKey = fs.readFileSync(PRIVATE_KEY_FILE, 'utf8');
    const header = createJwtHeader();
    const payload = createUserJwtPayload(userId, LEDGER_ID, expiryHours);
    const signature = signJwt(header, payload, privateKey);
    return `${header}.${payload}.${signature}`;
}

/** Generate all required tokens for RWA platform operations */
function generateAllTokens() {
    const tokens = {};
    console.log("=== RWA Platform JWT Token Generator ===\n");
    console.log(`Ledger ID (audience): ${LEDGER_ID}`);       // Confirming ledger/participant ID
    console.log(`Application ID: ${APPLICATION_ID}`);
    console.log(`Private Key: ${PRIVATE_KEY_FILE}\n`);
    // Individual party tokens (each acts as a single party)
    console.log("📝 Generating individual party tokens (actAs)...");
    tokens.bank  = createJwt([PARTIES.bank]);
    tokens.alice = createJwt([PARTIES.alice]);
    tokens.bob   = createJwt([PARTIES.bob]);
    console.log("✅ Bank token generated");
    console.log("✅ Alice token generated");
    console.log("✅ Bob token generated\n");
    // Multi-party tokens (for joint actions requiring two parties)
    console.log("🔐 Generating multi-party tokens (actAs)...");
    tokens.bank_alice = createJwt([PARTIES.bank, PARTIES.alice]);
    tokens.bank_bob   = createJwt([PARTIES.bank, PARTIES.bob]);
    console.log("✅ Bank+Alice token generated");
    console.log("✅ Bank+Bob token generated\n");
    // Admin token using user-based approach (for participant admin user)
    console.log("👑 Generating admin token (user-based)...");
    tokens.admin = createUserJwt("participant_admin");
    console.log("✅ Admin token generated (participant_admin)\n");
    return tokens;
}

/** Save tokens to a JSON file */
function saveTokensToFile(tokens, filename = "jwt-tokens.json") {
    try {
        fs.writeFileSync(filename, JSON.stringify(tokens, null, 2));
        console.log(`💾 Tokens saved to ${filename}`);
    } catch (error) {
        console.error(`Error saving tokens: ${error.message}`);
    }
}

/** Create a shell script to export all tokens as env vars */
function createShellScript(tokens) {
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19) + ' UTC';
    const scriptContent = `#!/bin/bash
# RWA Platform JWT Tokens (generated on ${timestamp})
export BANK_TOKEN="${tokens.bank}"
export ALICE_TOKEN="${tokens.alice}"
export BOB_TOKEN="${tokens.bob}"
export BANK_ALICE_TOKEN="${tokens.bank_alice}"
export BANK_BOB_TOKEN="${tokens.bank_bob}"
export ADMIN_TOKEN="${tokens.admin}"
echo "🔑 RWA JWT tokens loaded into environment"
echo "Available tokens: BANK_TOKEN, ALICE_TOKEN, BOB_TOKEN, BANK_ALICE_TOKEN, BANK_BOB_TOKEN, ADMIN_TOKEN"
`;
    try {
        fs.writeFileSync("load_jwt_tokens.sh", scriptContent);
        fs.chmodSync("load_jwt_tokens.sh", 0o755);
        console.log("📜 Shell script created: load_jwt_tokens.sh");
    } catch (error) {
        console.error(`Error creating shell script: ${error.message}`);
    }
}

/** Create example curl commands for using the tokens */
function createCurlExamples() {
    const RWA_PACKAGE_ID = "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1";  // replace with your package ID
    const examples = `#!/bin/bash
# RWA Platform JSON API Curl Examples (load tokens first: source ./load_jwt_tokens.sh)
echo "4800. Create Gold Registry (Bank):"
echo "curl -X POST http://localhost:7575/v1/create \\\\"
echo "  -H \\"Authorization: Bearer \$BANK_TOKEN\\" \\\\"
echo "  -H \\"Content-Type: application/json\\" \\\\"
echo "  -d '{\\"templateId\\": "\$RWA_PACKAGE_ID:TokenExample:AssetRegistry", \\"payload\\": {\\"admin\\": "${PARTIES.bank}", \\"name\\": "Gold Token", \\"symbol\\": "GLD"}}'"
# ... (additional examples trimmed for brevity)
`;
    try {
        fs.writeFileSync("curl_examples.sh", examples);
        fs.chmodSync("curl_examples.sh", 0o755);
        console.log("📋 Curl examples script created: curl_examples.sh");
    } catch (error) {
        console.error(`Error creating curl examples: ${error.message}`);
    }
}

// Main execution
try {
    const tokens = generateAllTokens();
    saveTokensToFile(tokens);
    createShellScript(tokens);
    createCurlExamples();
    // Print tokens for quick reference
    console.log("\n=== JWT Tokens ===");
    console.log(`BANK_TOKEN: ${tokens.bank}`);
    console.log(`ALICE_TOKEN: ${tokens.alice}`);
    console.log(`BOB_TOKEN: ${tokens.bob}`);
    console.log(`BANK_ALICE_TOKEN: ${tokens.bank_alice}`);
    console.log(`BANK_BOB_TOKEN: ${tokens.bank_bob}`);
    console.log(`ADMIN_TOKEN: ${tokens.admin}`);
    console.log("\n🎉 JWT generation completed successfully!");
    console.log("Next steps: source the tokens (source ./load_jwt_tokens.sh), start the JSON API, then use curl or your app with these tokens.");
} catch (error) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(4800);
}

