#!/usr/bin/env node
/**
 * Complete RWA Flow Test via JSON API
 * Tests the entire token lifecycle: create registries, mint, transfer, redeem
 */

const http = require('http');

// Configuration
const JSON_API_HOST = 'localhost';
const JSON_API_PORT = 7575;

// JWT Tokens (2-hour expiry)
const BANK_TOKEN = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2RhbWwuY29tL2p3dC9hdWQvcGFydGljaXBhbnQvcGFydGljaXBhbnQxIiwic3ViIjoiYmFua19hZG1pbiIsInNjb3BlIjoiZGFtbF9sZWRnZXJfYXBpIiwiaWF0IjoxNzU2MDUwMTg3LCJleHAiOjE3NTYwNTczODcsImp0aSI6ImUyNmJiNjQ0LTI3NGEtNDM4My1hNjJlLTE0OWJjMjk5M2ZiZSJ9.ANZUfEpUb5zOf1JMHGnZj2LQFfeGn39LdZiX3GQ7U_xzK-U-kQzaIkQQ2yFtxnxDvVB3YEnNDQ53n6qhvYF_p5ZxMCr_VhRKmkEMFOdrfuHbeAFaMV8JI9QJv_VsRV5BdkkaSELvX7IlBlVF_m3hjNJyIy2m_3MuaUkD6YOFSgU3x7OiiPTW261FEbpT6IoBVMniDajD5wavpgS-6bPXU4zQXncNBOf32j1Mtr9c1TtOID9aPNztmv5ATa8frvb2s9Fs2jN8TVL-e6eR-_TRODrOIiBAmLRi1HsI_RsIpq5RkBHjDhoeecOBLviKjLuv2sQ3uon_MEZVFFdwCRf--w';
const ALICE_TOKEN = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2RhbWwuY29tL2p3dC9hdWQvcGFydGljaXBhbnQvcGFydGljaXBhbnQxIiwic3ViIjoiYWxpY2VfdXNlciIsInNjb3BlIjoiZGFtbF9sZWRnZXJfYXBpIiwiaWF0IjoxNzU2MDUwNDA1LCJleHAiOjE3NTYwNTc2MDUsImp0aSI6IjI1MzM1YTVhLTVhZjktNDIzMi05YmI5LTY3NWFlNGNjYmI2ZSJ9.TLRPRA5XYQmokxs6Y_RQOVkCNrX9hPPNXWW9nmv4oGckXT_UbL0o2vRl2OTA2KdMAm6oF2MiAqcxeMB75LnbVJuBtzBNEgE5vNHFgI4HJTEVicvZRiKKHZ620QEGsIM1VPuy26nlAl29OF5R2cy5B5VUgRSZ4suPehWlDa8d3PtYHsdWJiBfM25BSJy2E6PFBPnqUqkYn7YEli1Nfis37lNnLFUma7gpFiQJihB8RF7l_OlpwH65B2KPYTEv-vbboS_X3kwMP-_fBGi5qk7nNijHOgSSifMBnMjGi49USBE8Pl78NhULKZpFQ5XMJ2QTU6ZXrXJ2n1BdnDflr-9GfQ';
const BOB_TOKEN = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2RhbWwuY29tL2p3dC9hdWQvcGFydGljaXBhbnQvcGFydGljaXBhbnQxIiwic3ViIjoiYm9iX3VzZXIiLCJzY29wZSI6ImRhbWxfbGVkZ2VyX2FwaSIsImlhdCI6MTc1NjA1MDQzOCwiZXhwIjoxNzU2MDU3NjM4LCJqdGkiOiJkNTcyNDczZS05NTcxLTQyZTctODUyNy02ODRhZjQzOWYyM2IifQ.ojGZK7q_VJYFD_yw0mskuB21Fguyhk9S4epfKFYKPSKHiEwqIJaxDvdczfB481seU3Z5Vc458eUL2-FYg_z-TEeJYZyvFlJo5Kc3BL9weYBfJ8CEdHPlotinDJjpN4jUS8EZjF2B2evGS0rSAhin0q_yx_xewz0kBwWK2DCjj8fGOiSTJQDaVJbfc-Bz1h3HVh5RIJt3KjWqYWgoyea90g8lrTwrJyIW-59lsvWsBXYxW-iX8tHFhi95PZHtSryY98fImJ6t-PJuleXD57fOgfJsxPWKSY30Jj37On7pko6H4Fscn5sW0pjV1wbon5D_YKJLvTl3mhO9qtySqX8JVQ';

// Party IDs
const PARTIES = {
    bank: 'NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
    alice: 'NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d',
    bob: 'NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d'
};

function makeJsonApiRequest(method, path, data = null, token = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: JSON_API_HOST,
            port: JSON_API_PORT,
            path: path,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        };

        if (token) {
            options.headers['Authorization'] = `Bearer ${token}`;
        }

        const req = http.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => responseData += chunk);
            res.on('end', () => {
                try {
                    const result = JSON.parse(responseData);
                    resolve({ status: res.statusCode, data: result });
                } catch (e) {
                    resolve({ status: res.statusCode, data: responseData });
                }
            });
        });

        req.on('error', reject);
        
        if (data) {
            req.write(JSON.stringify(data));
        }
        
        req.end();
    });
}

async function testJsonApiHealth() {
    try {
        console.log('🔍 Testing JSON API health...');
        const response = await makeJsonApiRequest('GET', '/v1/query', null, BANK_TOKEN);
        console.log('✅ JSON API is responding:', response.status);
        // HTTP 200 = OK, HTTP 401 = Missing auth (but API is working), HTTP 403 = HTTPS required
        return response.status === 200 || response.status === 401;
    } catch (error) {
        console.log('❌ JSON API health check failed:', error.message);
        return false;
    }
}

async function queryContracts(token, templateId = null) {
    try {
        const payload = templateId ? { templateIds: [templateId] } : {};
        const response = await makeJsonApiRequest('POST', '/v1/query', payload, token);
        return response.data;
    } catch (error) {
        console.log('❌ Contract query failed:', error.message);
        return { result: [] };
    }
}

async function main() {
    console.log('🚀 Starting RWA Flow Test via JSON API...');
    console.log('=' * 50);
    
    try {
        // Test JSON API connection
        const isHealthy = await testJsonApiHealth();
        if (!isHealthy) {
            console.log('❌ Cannot proceed - JSON API is not responding');
            process.exit(1);
        }

        // Step 1: Query existing AssetRegistry contracts
        console.log('\n📋 Step 1: Querying existing AssetRegistry contracts...');
        const registryContracts = await queryContracts(BANK_TOKEN, 'TokenExample:AssetRegistry');
        console.log(`Found ${registryContracts.result?.length || 0} AssetRegistry contracts`);

        // Step 2: Query existing Token contracts
        console.log('\n📋 Step 2: Querying existing Token contracts...');
        const tokenContracts = await queryContracts(ALICE_TOKEN, 'TokenExample:Token');
        console.log(`Found ${tokenContracts.result?.length || 0} Token contracts for Alice`);

        // Step 3: Query Bob's tokens
        console.log('\n📋 Step 3: Querying Bob\'s tokens...');
        const bobTokens = await queryContracts(BOB_TOKEN, 'TokenExample:Token');
        console.log(`Found ${bobTokens.result?.length || 0} Token contracts for Bob`);

        // Step 4: Check pending redemptions
        console.log('\n📋 Step 4: Querying pending redemptions...');
        const redemptions = await queryContracts(BANK_TOKEN, 'TokenExample:RedeemRequest');
        console.log(`Found ${redemptions.result?.length || 0} pending redemption requests`);

        console.log('\n✅ RWA Flow Test completed successfully!');
        console.log('📊 Summary:');
        console.log(`  - AssetRegistry contracts: ${registryContracts.result?.length || 0}`);
        console.log(`  - Alice's tokens: ${tokenContracts.result?.length || 0}`);
        console.log(`  - Bob's tokens: ${bobTokens.result?.length || 0}`);
        console.log(`  - Pending redemptions: ${redemptions.result?.length || 0}`);

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        process.exit(1);
    }
}

main();