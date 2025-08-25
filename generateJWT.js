const fs = require('fs');
const jwt = require('jsonwebtoken');

// Load the RSA private key that will be used for signing (RS256)
const privateKeyPath = 'config/jwt/jwt-sign.key';

if (!fs.existsSync(privateKeyPath)) {
    console.error(`Error: Private key file not found at ${privateKeyPath}`);
    console.error('Please ensure JWT signing key is properly configured');
    process.exit(1);
}

const privateKey = fs.readFileSync(privateKeyPath);

// Define the ledger ID from Canton config (participant1)
const ledgerId = "participant1";

// Load party mappings from the JSON file
const partyMappingsPath = 'config/user-party-mappings.json';
let partyMappings = {};

if (fs.existsSync(partyMappingsPath)) {
    try {
        const partyMappingsData = fs.readFileSync(partyMappingsPath, 'utf8');
        partyMappings = JSON.parse(partyMappingsData);
        console.log('Loaded party mappings from:', partyMappingsPath);
    } catch (error) {
        console.error('Error reading party mappings:', error.message);
        process.exit(1);
    }
} else {
    console.warn('Party mappings file not found, using hardcoded values');
}

/**
 * Generate JWT token for a specific user role
 * @param {string} userRole - The user role (participant_admin, bank_admin, alice_user, bob_user)
 * @param {string} applicationId - Application identifier for the token
 * @returns {string} Generated JWT token
 */
function generateToken(userRole, applicationId = "rwa-json-api") {
    // Create user-based JWT token for Canton's user management system
    // This references the users created in Canton (bank_admin, alice_user, bob_user)
    let payload = {
        scope: "daml_ledger_api",  // Must match target-scope in config
        aud: "https://daml.com/jwt/aud/participant/participant1",  // Must match target-audience in Canton config
        sub: userRole,             // Subject is the user ID that exists in Canton
        iss: "canton-jwt-issuer",  // Issuer identifier
        exp: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year expiry
        iat: Math.floor(Date.now() / 1000)  // Issued at
    };

    console.log(`Generating user-based token for Canton user: ${userRole}`);
    console.log(`Token will reference existing Canton user with ID: ${userRole}`);

    // Sign the JWT using the private key and RS256 algorithm
    // This creates a user-based token that references existing Canton users
    const token = jwt.sign(payload, privateKey, { algorithm: 'RS256' });
    
    return token;
}

/**
 * Generate multi-party JWT token for operations requiring multiple parties
 * @param {string} tokenName - Name for the token (e.g., 'alice_bank')
 * @param {Array<string>} parties - Array of party IDs to include in actAs
 * @param {string} applicationId - Application identifier for the token
 * @returns {string} Generated JWT token
 */
function generateMultiPartyToken(tokenName, parties, applicationId = "rwa-json-api") {
    // Create multi-party JWT token for operations like Transfer
    let payload = {
        scope: "daml_ledger_api",  // Must match target-scope in config
        aud: "https://daml.com/jwt/aud/participant/participant1",  // Must match target-audience in Canton config
        sub: tokenName,            // Subject is a descriptive name
        iss: "canton-jwt-issuer",  // Issuer identifier
        exp: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year expiry
        iat: Math.floor(Date.now() / 1000),  // Issued at
        actAs: parties,            // Multiple parties that can act
        readAs: parties            // Same parties for read access
    };

    console.log(`Generating multi-party token: ${tokenName}`);
    console.log(`Parties included: ${parties.join(', ')}`);

    // Sign the JWT using the private key and RS256 algorithm
    const token = jwt.sign(payload, privateKey, { algorithm: 'RS256' });
    
    return token;
}

/**
 * Generate tokens for all users and save to files
 */
function generateAllTokens() {
    const users = ['participant_admin', 'bank_admin', 'alice_user', 'bob_user'];
    const tokens = {};
    
    console.log('='.repeat(80));
    console.log('GENERATING JWT TOKENS FOR ALL USERS');
    console.log('='.repeat(80));
    
    users.forEach(user => {
        console.log(`\nGenerating token for: ${user}`);
        const token = generateToken(user);
        
        if (token) {
            tokens[user] = token;
            console.log(`✓ Token generated successfully for ${user}`);
            console.log(`Token length: ${token.length} characters`);
            
            // Save individual token to file
            const tokenFile = `${user}-jwt-token.txt`;
            fs.writeFileSync(tokenFile, token);
            console.log(`✓ Token saved to: ${tokenFile}`);
        } else {
            console.log(`✗ Failed to generate token for ${user}`);
        }
    });
    
    console.log('\n' + '='.repeat(40));
    console.log('GENERATING MULTI-PARTY TOKENS');
    console.log('='.repeat(40));
    
    // Generate multi-party tokens for operations
    const multiPartyTokens = [
        {
            name: 'alice_bank_token',
            parties: [
                'NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
                'NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d'
            ]
        },
        {
            name: 'bob_bank_token',
            parties: [
                'NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
                'NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d'
            ]
        },
        {
            name: 'all_parties_token',
            parties: [
                'NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
                'NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
                'NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d'
            ]
        }
    ];
    
    multiPartyTokens.forEach(tokenConfig => {
        console.log(`\nGenerating multi-party token: ${tokenConfig.name}`);
        const token = generateMultiPartyToken(tokenConfig.name, tokenConfig.parties);
        
        if (token) {
            tokens[tokenConfig.name] = token;
            console.log(`✓ Multi-party token generated successfully`);
            console.log(`Token length: ${token.length} characters`);
            
            // Save individual token to file
            const tokenFile = `${tokenConfig.name}-jwt-token.txt`;
            fs.writeFileSync(tokenFile, token);
            console.log(`✓ Token saved to: ${tokenFile}`);
        }
    });
    
    // Save all tokens to a combined JSON file
    if (Object.keys(tokens).length > 0) {
        const allTokensFile = 'jwt-tokens.json';
        fs.writeFileSync(allTokensFile, JSON.stringify(tokens, null, 2));
        console.log(`\n✓ All tokens saved to: ${allTokensFile}`);
        
        // Also save in a format suitable for shell scripts
        const shellTokensFile = 'jwt-tokens-shell.txt';
        let shellContent = '#!/bin/bash\n# JWT Tokens for Canton API Testing\n\n';
        Object.entries(tokens).forEach(([user, token]) => {
            const varName = user.toUpperCase().replace('-', '_') + '_TOKEN';
            shellContent += `export ${varName}="${token}"\n`;
        });
        fs.writeFileSync(shellTokensFile, shellContent);
        fs.chmodSync(shellTokensFile, '755');
        console.log(`✓ Shell-friendly tokens saved to: ${shellTokensFile}`);
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('TOKEN GENERATION COMPLETED');
    console.log('='.repeat(80));
    
    return tokens;
}

/**
 * Display token information for debugging
 */
function displayTokenInfo(token, userRole) {
    try {
        const decoded = jwt.decode(token, { complete: true });
        console.log(`\nToken Information for ${userRole}:`);
        console.log('Header:', JSON.stringify(decoded.header, null, 2));
        console.log('Payload:', JSON.stringify(decoded.payload, null, 2));
        console.log('Token (first 50 chars):', token.substring(0, 50) + '...');
    } catch (error) {
        console.error('Error decoding token:', error.message);
    }
}

// Main execution
if (require.main === module) {
    // Check command line arguments
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        // Generate all tokens
        const tokens = generateAllTokens();
        
        // Display sample token info for Alice
        if (tokens.alice_user) {
            displayTokenInfo(tokens.alice_user, 'alice_user');
        }
        
    } else if (args.length === 1) {
        // Generate token for specific user
        const userRole = args[0];
        console.log(`Generating token for specific user: ${userRole}`);
        
        const token = generateToken(userRole);
        if (token) {
            console.log('\nGenerated JWT Token:');
            console.log(token);
            displayTokenInfo(token, userRole);
        }
        
    } else {
        console.log('Usage:');
        console.log('  node generateJWT.js                    # Generate tokens for all users');
        console.log('  node generateJWT.js <user_role>        # Generate token for specific user');
        console.log('');
        console.log('Available user roles:');
        console.log('  - participant_admin');
        console.log('  - bank_admin');
        console.log('  - alice_user');
        console.log('  - bob_user');
        process.exit(1);
    }
}

module.exports = { generateToken, generateAllTokens };