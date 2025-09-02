#!/usr/bin/env node
/**
 * Simple JWT Token Decoder
 * Decode and display JWT token payload for debugging
 */

function decodeJwt(token) {
    try {
        const parts = token.split('.');
        if (parts.length !== 3) {
            throw new Error('Invalid JWT format - must have 3 parts');
        }

        const [header, payload, signature] = parts;
        
        // Decode header (base64url to base64)
        const decodedHeader = JSON.parse(Buffer.from(header.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
        
        // Decode payload (base64url to base64)
        const decodedPayload = JSON.parse(Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());

        console.log('=== JWT TOKEN ANALYSIS ===');
        console.log('\n🏷️  HEADER:');
        console.log(JSON.stringify(decodedHeader, null, 2));
        
        console.log('\n📋 PAYLOAD:');
        console.log(JSON.stringify(decodedPayload, null, 2));
        
        console.log('\n🔐 SIGNATURE:');
        console.log(`Length: ${signature.length} characters`);
        console.log(`Preview: ${signature.substring(0, 50)}...`);

        // Check expiry
        if (decodedPayload.exp) {
            const expiry = new Date(decodedPayload.exp * 1000);
            const now = new Date();
            const isExpired = now > expiry;
            
            console.log('\n⏰ EXPIRY:');
            console.log(`Expires: ${expiry.toISOString()}`);
            console.log(`Current: ${now.toISOString()}`);
            console.log(`Status: ${isExpired ? '❌ EXPIRED' : '✅ VALID'}`);
        }

        // Canton-specific checks
        console.log('\n🔍 CANTON COMPATIBILITY:');
        
        if (decodedPayload.aud) {
            console.log(`✅ Audience: ${decodedPayload.aud}`);
        } else {
            console.log('❌ Missing audience (aud) claim');
        }
        
        if (decodedPayload.scope === 'daml_ledger_api') {
            console.log('✅ Scope: daml_ledger_api');
        } else {
            console.log(`❌ Wrong/missing scope: ${decodedPayload.scope || 'none'}`);
        }
        
        if (decodedPayload.sub) {
            console.log(`✅ User (sub): ${decodedPayload.sub}`);
        }
        
        if (decodedPayload['https://daml.com/ledger-api']) {
            const damlClaims = decodedPayload['https://daml.com/ledger-api'];
            console.log('✅ Custom Daml claims present:');
            if (damlClaims.actAs) {
                console.log(`   - actAs: ${damlClaims.actAs.length} parties`);
                damlClaims.actAs.forEach((party, i) => {
                    console.log(`     ${i + 1}. ${party}`);
                });
            }
            if (damlClaims.participantId) {
                console.log(`   - participantId: ${damlClaims.participantId}`);
            }
        }
        
        if (decodedPayload.iss) {
            console.log(`⚠️  Issuer (iss): ${decodedPayload.iss} (should be omitted for default Canton setup)`);
        } else {
            console.log('✅ No issuer (iss) claim - good for default Canton setup');
        }

    } catch (error) {
        console.error(`❌ Error decoding JWT: ${error.message}`);
        process.exit(1);
    }
}

// Get token from command line argument or environment variable
const token = process.argv[2] || process.env.BANK_TOKEN;

if (!token) {
    console.log('Usage: node decode_jwt.js <jwt_token>');
    console.log('   or: BANK_TOKEN="..." node decode_jwt.js');
    process.exit(1);
}

decodeJwt(token);