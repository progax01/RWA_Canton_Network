#!/usr/bin/env node
/**
 * Production JWT Manager for RWA Platform
 * Handles user-based tokens, party management, and secure token generation
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Production Configuration (read from environment)
const CONFIG = {
    PRIVATE_KEY_FILE: process.env.JWT_PRIVATE_KEY_FILE || "config/jwt/jwt-sign.key",
    PARTICIPANT_ID: process.env.CANTON_PARTICIPANT_ID || "participant1",
    APPLICATION_ID: process.env.RWA_APPLICATION_ID || "rwa-platform-api",
    TOKEN_EXPIRY_HOURS: parseInt(process.env.JWT_EXPIRY_HOURS) || 2,
    SCOPE: process.env.JWT_SCOPE || "daml_ledger_api"
};

// User and Party Management
class UserPartyManager {
    constructor() {
        this.userPartyMappings = new Map();
        this.loadUserMappings();
    }

    // Load user-party mappings from file or database
    loadUserMappings() {
        try {
            const mappingsFile = 'config/user-party-mappings.json';
            if (fs.existsSync(mappingsFile)) {
                const data = JSON.parse(fs.readFileSync(mappingsFile, 'utf8'));
                this.userPartyMappings = new Map(Object.entries(data));
                console.log(`✅ Loaded ${this.userPartyMappings.size} user-party mappings`);
            } else {
                console.log("⚠️ No user-party mappings file found, using defaults");
                this.initializeDefaults();
            }
        } catch (error) {
            console.error(`Error loading user mappings: ${error.message}`);
            this.initializeDefaults();
        }
    }

    // Initialize default mappings for testing
    initializeDefaults() {
        this.userPartyMappings.set('bank_admin', ['NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d']);
        this.userPartyMappings.set('alice_user', ['NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d']);
        this.userPartyMappings.set('bob_user', ['NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d']);
        this.userPartyMappings.set('participant_admin', []); // Admin with no specific parties
    }

    // Get parties for a user
    getUserParties(userId) {
        return this.userPartyMappings.get(userId) || [];
    }

    // Add or update user-party mapping
    addUserPartyMapping(userId, parties) {
        this.userPartyMappings.set(userId, parties);
        this.saveMappings();
    }

    // Save mappings to file
    saveMappings() {
        try {
            const mappingsFile = 'config/user-party-mappings.json';
            const data = Object.fromEntries(this.userPartyMappings);
            fs.writeFileSync(mappingsFile, JSON.stringify(data, null, 2));
        } catch (error) {
            console.error(`Error saving mappings: ${error.message}`);
        }
    }
}

// JWT Token Generator with enhanced security
class ProductionJWTGenerator {
    constructor() {
        this.userManager = new UserPartyManager();
        this.loadPrivateKey();
    }

    loadPrivateKey() {
        if (!fs.existsSync(CONFIG.PRIVATE_KEY_FILE)) {
            throw new Error(`Private key file not found: ${CONFIG.PRIVATE_KEY_FILE}`);
        }
        this.privateKey = fs.readFileSync(CONFIG.PRIVATE_KEY_FILE, 'utf8');
        console.log(`✅ Loaded private key from ${CONFIG.PRIVATE_KEY_FILE}`);
    }

    // Base64 URL encoding without padding
    base64UrlEncode(data) {
        return Buffer.from(data).toString('base64')
            .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    }

    // Create JWT header
    createJwtHeader() {
        return this.base64UrlEncode(JSON.stringify({
            alg: "RS256",
            typ: "JWT"
        }));
    }

    // Create user-based JWT payload (recommended approach)
    createUserJwtPayload(userId, expiryHours = CONFIG.TOKEN_EXPIRY_HOURS) {
        const now = Math.floor(Date.now() / 1000);
        return this.base64UrlEncode(JSON.stringify({
            aud: `https://daml.com/jwt/aud/participant/${CONFIG.PARTICIPANT_ID}`,
            sub: userId,
            scope: CONFIG.SCOPE,
            iat: now,
            exp: now + (expiryHours * 3600),
            jti: crypto.randomUUID() // Unique token ID for tracking/revocation
        }));
    }

    // Create party-based JWT payload (legacy approach)
    createPartyJwtPayload(parties, expiryHours = CONFIG.TOKEN_EXPIRY_HOURS) {
        const now = Math.floor(Date.now() / 1000);
        return this.base64UrlEncode(JSON.stringify({
            "https://daml.com/ledger-api": {
                participantId: CONFIG.PARTICIPANT_ID,
                actAs: parties,
                applicationId: CONFIG.APPLICATION_ID
            },
            aud: `https://daml.com/jwt/aud/participant/${CONFIG.PARTICIPANT_ID}`,
            scope: CONFIG.SCOPE,
            iat: now,
            exp: now + (expiryHours * 3600),
            jti: crypto.randomUUID()
        }));
    }

    // Sign JWT using RS256
    signJwt(header, payload) {
        const data = `${header}.${payload}`;
        const signature = crypto.sign('RSA-SHA256', Buffer.from(data), this.privateKey);
        return this.base64UrlEncode(signature);
    }

    // Generate user-based token (production recommended)
    generateUserToken(userId, expiryHours = CONFIG.TOKEN_EXPIRY_HOURS) {
        const header = this.createJwtHeader();
        const payload = this.createUserJwtPayload(userId, expiryHours);
        const signature = this.signJwt(header, payload);
        return `${header}.${payload}.${signature}`;
    }

    // Generate party-based token (for specific use cases)
    generatePartyToken(parties, expiryHours = CONFIG.TOKEN_EXPIRY_HOURS) {
        const header = this.createJwtHeader();
        const payload = this.createPartyJwtPayload(parties, expiryHours);
        const signature = this.signJwt(header, payload);
        return `${header}.${payload}.${signature}`;
    }

    // Generate token for application user (maps user to parties)
    generateApplicationUserToken(userId, expiryHours = CONFIG.TOKEN_EXPIRY_HOURS) {
        const parties = this.userManager.getUserParties(userId);
        if (parties.length === 0 && userId !== 'participant_admin') {
            throw new Error(`No parties found for user: ${userId}`);
        }
        return this.generateUserToken(userId, expiryHours);
    }

    // Validate token format (basic check)
    validateToken(token) {
        const parts = token.split('.');
        if (parts.length !== 3) {
            return { valid: false, error: 'Invalid JWT format' };
        }
        
        try {
            const payload = JSON.parse(Buffer.from(parts[1], 'base64url'));
            const now = Math.floor(Date.now() / 1000);
            
            if (payload.exp && payload.exp < now) {
                return { valid: false, error: 'Token expired' };
            }
            
            return { valid: true, payload };
        } catch (error) {
            return { valid: false, error: 'Invalid token payload' };
        }
    }
}

// Environment validation
function validateEnvironment() {
    console.log("🔍 Validating production environment...");
    
    const required = [
        'CANTON_DB_USER',
        'CANTON_DB_PASSWORD', 
        'JSON_API_DB_USER',
        'JSON_API_DB_PASSWORD'
    ];
    
    const missing = required.filter(env => !process.env[env]);
    if (missing.length > 0) {
        console.error(`❌ Missing environment variables: ${missing.join(', ')}`);
        process.exit(1);
    }
    
    console.log("✅ Environment validation passed");
}

// CLI Interface
function printUsage() {
    console.log(`
Production JWT Manager for RWA Platform

Usage: node jwt-manager-production.js [command] [options]

Commands:
  user-token <userId>          Generate token for ledger user
  party-token <party1,party2>  Generate token for specific parties
  validate <token>             Validate JWT token
  list-users                   List all user-party mappings
  add-user <userId> <parties>  Add new user-party mapping

Environment Variables:
  JWT_PRIVATE_KEY_FILE         Path to JWT signing key (default: config/jwt/jwt-sign.key)
  CANTON_PARTICIPANT_ID        Canton participant ID (default: participant1)
  RWA_APPLICATION_ID           Application ID (default: rwa-platform-api)
  JWT_EXPIRY_HOURS            Token expiry in hours (default: 2)
  JWT_SCOPE                   JWT scope (default: daml_ledger_api)

Examples:
  node jwt-manager-production.js user-token bank_admin
  node jwt-manager-production.js party-token "NewBank::12209...,NewAlice::12209..."
  node jwt-manager-production.js validate "eyJhbGciOiJSUzI1NiIs..."
`);
}

// Main execution
function main() {
    const command = process.argv[2];
    const arg1 = process.argv[3];
    const arg2 = process.argv[4];

    if (!command) {
        printUsage();
        return;
    }

    try {
        validateEnvironment();
        const generator = new ProductionJWTGenerator();

        switch (command) {
            case 'user-token':
                if (!arg1) {
                    console.error("❌ User ID required");
                    return;
                }
                const userToken = generator.generateApplicationUserToken(arg1);
                console.log(`🔑 User token for ${arg1}:`);
                console.log(userToken);
                break;

            case 'party-token':
                if (!arg1) {
                    console.error("❌ Parties required (comma-separated)");
                    return;
                }
                const parties = arg1.split(',').map(p => p.trim());
                const partyToken = generator.generatePartyToken(parties);
                console.log(`🔑 Party token for [${parties.join(', ')}]:`);
                console.log(partyToken);
                break;

            case 'validate':
                if (!arg1) {
                    console.error("❌ Token required");
                    return;
                }
                const validation = generator.validateToken(arg1);
                if (validation.valid) {
                    console.log("✅ Token is valid");
                    console.log("Payload:", JSON.stringify(validation.payload, null, 2));
                } else {
                    console.log("❌ Token validation failed:", validation.error);
                }
                break;

            case 'list-users':
                console.log("👥 User-Party Mappings:");
                generator.userManager.userPartyMappings.forEach((parties, userId) => {
                    console.log(`  ${userId}: [${parties.join(', ')}]`);
                });
                break;

            case 'add-user':
                if (!arg1 || !arg2) {
                    console.error("❌ User ID and parties required");
                    return;
                }
                const newParties = arg2.split(',').map(p => p.trim());
                generator.userManager.addUserPartyMapping(arg1, newParties);
                console.log(`✅ Added user ${arg1} with parties: [${newParties.join(', ')}]`);
                break;

            default:
                console.error(`❌ Unknown command: ${command}`);
                printUsage();
        }
    } catch (error) {
        console.error(`❌ Error: ${error.message}`);
        process.exit(1);
    }
}

// Export for use as module
module.exports = {
    ProductionJWTGenerator,
    UserPartyManager,
    CONFIG
};

// Run if called directly
if (require.main === module) {
    main();
}
