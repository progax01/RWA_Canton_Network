#!/usr/bin/env node
/**
 * RWA Network Setup via Canton Admin API
 */

const https = require('https');
const fs = require('fs');

// Admin API configuration
const ADMIN_API_HOST = 'localhost';
const ADMIN_API_PORT = 5012;

// TLS options for self-signed certificates
const tlsOptions = {
    rejectUnauthorized: false, // Accept self-signed certificates
    ca: fs.readFileSync('config/tls/root-ca.crt'),
    cert: fs.readFileSync('config/tls/admin-client.crt'),
    key: fs.readFileSync('config/tls/admin-client.key')
};

function makeAdminRequest(method, path, data = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: ADMIN_API_HOST,
            port: ADMIN_API_PORT,
            path: path,
            method: method,
            headers: {
                'Content-Type': 'application/json'
            },
            ...tlsOptions
        };

        const req = https.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => responseData += chunk);
            res.on('end', () => {
                try {
                    const result = JSON.parse(responseData);
                    resolve(result);
                } catch (e) {
                    resolve(responseData);
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

async function checkParticipantHealth() {
    try {
        console.log('🔍 Checking participant health...');
        const health = await makeAdminRequest('GET', '/health');
        console.log('✅ Participant is healthy');
        return true;
    } catch (error) {
        console.log('❌ Participant health check failed:', error.message);
        return false;
    }
}

async function main() {
    console.log('🚀 Starting RWA Network Setup via Admin API...');
    
    try {
        const isHealthy = await checkParticipantHealth();
        if (!isHealthy) {
            console.log('❌ Cannot proceed - participant is not healthy');
            process.exit(1);
        }
        
        console.log('📝 Network setup would continue here...');
        console.log('💡 For now, please use the Canton console directly');
        
    } catch (error) {
        console.error('❌ Setup failed:', error.message);
        process.exit(1);
    }
}

main();