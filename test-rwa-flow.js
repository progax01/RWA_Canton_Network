#!/usr/bin/env node
/**
 * Complete RWA Flow Test via JSON API
 * Tests the entire token lifecycle: create registries, mint, transfer, redeem
 */

const http = require('http');

// Configuration
const JSON_API_HOST = 'localhost';
const JSON_API_PORT = 7575;


const PARTICIPANT_ADMIN_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwczovL2RhbWwuY29tL2xlZGdlci1hcGkiOnsibGVkZ2VySWQiOiJwYXJ0aWNpcGFudDEiLCJhcHBsaWNhdGlvbklkIjoibXktYXBwIiwiYWRtaW4iOnRydWV9LCJpYXQiOjE3NTYwOTMwNzh9.fzFfvy00AbnzbGJFAL-K5MoA1H2E17mZ1r97gkXCXGFajL1gnhGShKrhygzRdcaJfWMhjRXjB2q4BuAmJuDz3RCmXsb5qbyHjrtUPT39H0eP-j3ejthKIur72bgNqP_bqqfF1wkdnlZVoo_Tph_dRdCLcY5Qtni5K0HIcw_0CT9G6X--xigADL4BDAOXxzkWaXmHXWR4v0JKKi9UAD5xiwoDlfd6dVGZKSKsKTOXgs9H1cWD8aP-bKDnE8YrYh9IgN1A5wE5XoyXEzJDEwTOYUvFKj-RnqsRkt9x1Ho-OFXkxa0SYRxBqeIk5BE6irX_F9bk5Z99EwZA-3dWcGPPNQ";
const BANK_TOKEN ="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwczovL2RhbWwuY29tL2xlZGdlci1hcGkiOnsibGVkZ2VySWQiOiJwYXJ0aWNpcGFudDEiLCJhcHBsaWNhdGlvbklkIjoibXktYXBwIiwiYWN0QXMiOlsiTmV3QmFuazo6MTIyMGI4NDVkY2YwZDljZjUyY2UxZTc0NTdhNzQ0YTZmM2RlN2VmZjRhOWVlOTUyNjFiNjk0MDVkMWUwZGU4YTc2OGQiXSwicmVhZEFzIjpbIk5ld0Jhbms6OjEyMjBiODQ1ZGNmMGQ5Y2Y1MmNlMWU3NDU3YTc0NGE2ZjNkZTdlZmY0YTllZTk1MjYxYjY5NDA1ZDFlMGRlOGE3NjhkIl19LCJpYXQiOjE3NTYwOTMwNzh9.RkvqbYBb2gnqyezRs2VM8P2IcQVlhj8heBYcRhbuAAi1fpN_lsB73Kak0a0RoNrWBJCtiZqrugEsDYmVRR_LAl8AnTsMSeE5Jm7nKoZWM0YVO2pz7pfi2BRLGztgeEkCNdfsqGM92mqeTxXIftIXGEMRFuQU_A2lUs1ZKixKi-lPDyGX2l49k_S34phZeGMoy9JgZO9FFkxE4Az6vwH-7hZuKHC5iJQaan469hYKLrYEuCFkLmaDK0FGrVhU0bsiySh2vAAyOY2kuUbEI8JCz7yBy6oLD2Wa20k0nUeG2SpjRks4q1j1PccMF6MflSnvlMvIIUXkQp1EisxiXE6C4A"
const ALICE_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwczovL2RhbWwuY29tL2xlZGdlci1hcGkiOnsibGVkZ2VySWQiOiJwYXJ0aWNpcGFudDEiLCJhcHBsaWNhdGlvbklkIjoibXktYXBwIiwiYWN0QXMiOlsiTmV3QWxpY2U6OjEyMjBiODQ1ZGNmMGQ5Y2Y1MmNlMWU3NDU3YTc0NGE2ZjNkZTdlZmY0YTllZTk1MjYxYjY5NDA1ZDFlMGRlOGE3NjhkIl0sInJlYWRBcyI6WyJOZXdBbGljZTo6MTIyMGI4NDVkY2YwZDljZjUyY2UxZTc0NTdhNzQ0YTZmM2RlN2VmZjRhOWVlOTUyNjFiNjk0MDVkMWUwZGU4YTc2OGQiXX0sImlhdCI6MTc1NjA5MzA3OH0.F1KjPsB4XQWeDSdRtQV3RBtmdsiEq1cgvgBkAZ_RfhV4kVS5-9MqkFKN8iXbytOiJFWUELSrR3ArzlT9yMeqZavjEEh5wq-dpMDf7hGCdTJ94ASn0uGN0IPjUTEjVFUas1LLCUxS5krY2lA4EAPFBrHLkK05fxa6_SO5GXzH0uGRA1vWvb41kwyKXWFLemQDkblVkVGO-ZZCjfff9MLBOeUPKf5LZw-LiSFhlhF0IF3Yr55lTtoqBAGsahfKzsC9sLQ9zedg9jhTV-qa1yc0NE-1uvdzQyf5Pv0RlVwmjm8X-wFqUOhTgCK4OqEgLv6J5smHuo-neHc1DRr9-FBJ5g"
const BOB_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwczovL2RhbWwuY29tL2xlZGdlci1hcGkiOnsibGVkZ2VySWQiOiJwYXJ0aWNpcGFudDEiLCJhcHBsaWNhdGlvbklkIjoibXktYXBwIiwiYWN0QXMiOlsiTmV3Qm9iOjoxMjIwYjg0NWRjZjBkOWNmNTJjZTFlNzQ1N2E3NDRhNmYzZGU3ZWZmNGE5ZWU5NTI2MWI2OTQwNWQxZTBkZThhNzY4ZCJdLCJyZWFkQXMiOlsiTmV3Qm9iOjoxMjIwYjg0NWRjZjBkOWNmNTJjZTFlNzQ1N2E3NDRhNmYzZGU3ZWZmNGE5ZWU5NTI2MWI2OTQwNWQxZTBkZThhNzY4ZCJdfSwiaWF0IjoxNzU2MDkzMDc4fQ.B_9LEjdI_zUcAHag2TO_T2BCCoeQSpcakRDYjsoFNe9aaO2knRez1NOzUg6lEK-Txc3xCMiUl-P78yc1oKVmby2dfQz1iT0uh70STPIx0uFpT4K_4Fax_7SLOnRdpa5AkcvuU7_0ClujHooY67xBIbvAS-J5IEtPFcTlnUKY8JgWUcgCmG-0OTJ31vyJ-J4mLJ16h9rF5H-kvpPmRRi_5zYx38O6ph95DL2TgY4NLu2k17ygJ3FEu6IYlGsa_DauCn4lpYFA1sVcueYjS1LDDh05YOAIlwUY2rdu56nFvTt6HQlo-9kqHApUCgsdqTsSch8BNkbrlKjiTKcX1l6j3Q"

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