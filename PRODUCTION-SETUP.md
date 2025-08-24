# RWA Platform Production Setup Guide

This guide provides step-by-step instructions for deploying your RWA Canton platform in a production environment with TLS security, proper JWT management, and HTTP JSON API integration.

## 📋 Prerequisites

### System Requirements
- Linux server with at least 4GB RAM and 20GB storage
- PostgreSQL 12+ database server
- NGINX reverse proxy
- Java 11+ runtime
- Node.js 16+ (for JWT management)
- SSL certificates for your domain

### Database Setup
```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt update
sudo apt install postgresql postgresql-contrib

# Create production databases
sudo -u postgres createdb canton_participant
sudo -u postgres createdb canton_domain  
sudo -u postgres createdb json_api_store

# Create database users
sudo -u postgres createuser canton_prod
sudo -u postgres createuser json_api_prod

# Set passwords (replace with secure passwords)
sudo -u postgres psql -c "ALTER USER canton_prod PASSWORD 'your_secure_password';"
sudo -u postgres psql -c "ALTER USER json_api_prod PASSWORD 'your_secure_password';"

# Grant permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE canton_participant TO canton_prod;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE canton_domain TO canton_prod;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE json_api_store TO json_api_prod;"
```

## 🔧 Configuration

### 1. Environment Setup

Copy and customize the environment file:
```bash
cp config/production.env config/.env
nano config/.env  # Edit with your values
```

Required environment variables:
- `CANTON_DB_USER` and `CANTON_DB_PASSWORD` - Canton database credentials
- `JSON_API_DB_USER` and `JSON_API_DB_PASSWORD` - JSON API database credentials
- Domain and SSL certificate paths
- JWT configuration parameters

### 2. TLS Certificates

Your `config/tls/` directory should contain:
- `root-ca.crt` - Root certificate authority
- `ledger-api.crt/.key` - Ledger API server certificate  
- `admin-api.crt/.key` - Admin API server certificate
- `public-api.crt/.key` - Domain public API certificate
- `admin-client.crt/.key` - Client certificate for JSON API

If you need to generate test certificates, use:
```bash
cd config/tls
./gen-test-certs.sh  # For development only
```

### 3. JWT Signing Certificates

Ensure you have JWT signing certificates in `config/jwt/`:
- `jwt-sign.crt` - Public certificate for token verification
- `jwt-sign.key` - Private key for token signing

## 🚀 Deployment

### Automated Deployment

Run the production deployment script:
```bash
./deploy-production.sh deploy
```

This script will:
1. ✅ Validate environment and certificates
2. 🗄️ Setup databases
3. 🚀 Start Canton nodes with TLS
4. 🌐 Start HTTP JSON API  
5. 👥 Generate initial user setup
6. 🔑 Create JWT tokens
7. 🔧 Create systemd services

### Manual Deployment Steps

If you prefer manual deployment:

1. **Start Canton**:
   ```bash
   java -jar lib/canton-open-source-2.10.2.jar \
     --config config/canton-production.conf \
     --log-level-root INFO daemon
   ```

2. **Setup Users and Parties** (in Canton console):
   ```scala
   // Load the setup script
   exec("setup-users-parties.canton")
   ```

3. **Start JSON API**:
   ```bash
   java -jar http-json-2.10.2.jar \
     --config config/json-api-production.conf
   ```

## 🔒 Security Configuration

### NGINX Reverse Proxy

Install the NGINX configuration:
```bash
sudo cp config/nginx-rwa-api.conf /etc/nginx/sites-available/rwa-api
sudo ln -s /etc/nginx/sites-available/rwa-api /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Update the configuration with:
- Your actual domain name
- SSL certificate paths  
- CORS origins for your frontend

### JWT Token Management

Use the production JWT manager for secure token handling:

```bash
# Generate user-based token (recommended)
./jwt-manager-production.js user-token bank_admin

# Generate party-based token (legacy)  
./jwt-manager-production.js party-token "NewBank::1220...,NewAlice::1220..."

# Validate existing token
./jwt-manager-production.js validate "eyJhbGciOiJSUzI1NiIs..."

# List user-party mappings
./jwt-manager-production.js list-users

# Add new user mapping
./jwt-manager-production.js add-user "new_user" "Party1::abc...,Party2::def..."
```

### User-Party Mappings

Edit `config/user-party-mappings.json` to define which Canton parties each application user can act as:

```json
{
  "participant_admin": [],
  "bank_admin": ["NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"],
  "alice_user": ["NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"],
  "bob_user": ["NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"]
}
```

## 🌐 API Integration

### Using the JSON API

All HTTP requests must include a valid JWT token:

```bash
# Get bearer token
TOKEN=$(./jwt-manager-production.js user-token bank_admin)

# Create a contract
curl -X POST https://your-domain.com/api/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "YourPackage:YourModule:YourTemplate",
    "payload": {"field1": "value1", "field2": "value2"}
  }'

# Exercise a choice
curl -X POST https://your-domain.com/api/exercise \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "YourPackage:YourModule:YourTemplate",
    "contractId": "00af1d02...",
    "choice": "YourChoice",
    "argument": {"param1": "value1"}
  }'

# Query contracts
curl -X POST https://your-domain.com/api/query \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["YourPackage:YourModule:YourTemplate"]
  }'
```

### Backend Integration Example (Node.js)

```javascript
const axios = require('axios');

class RWAAPIClient {
    constructor(apiUrl, jwtManager) {
        this.apiUrl = apiUrl;
        this.jwtManager = jwtManager;
    }

    async createContract(userId, templateId, payload) {
        const token = this.jwtManager.generateApplicationUserToken(userId);
        
        const response = await axios.post(`${this.apiUrl}/create`, {
            templateId,
            payload
        }, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        return response.data;
    }

    async exerciseChoice(userId, templateId, contractId, choice, argument) {
        const token = this.jwtManager.generateApplicationUserToken(userId);
        
        const response = await axios.post(`${this.apiUrl}/exercise`, {
            templateId,
            contractId,
            choice,
            argument
        }, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        return response.data;
    }
}
```

## 📊 Monitoring and Maintenance

### System Services

Install systemd services for automatic startup:
```bash
sudo cp rwa-canton.service /etc/systemd/system/
sudo cp rwa-json-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rwa-canton rwa-json-api
```

Control services:
```bash
sudo systemctl start rwa-canton
sudo systemctl start rwa-json-api
sudo systemctl status rwa-canton
sudo systemctl status rwa-json-api
```

### Health Monitoring

- **Canton Health**: `curl -k https://localhost:5011/readyz`
- **JSON API Health**: `curl http://localhost:7575/livez`
- **Through Proxy**: `curl https://your-domain.com/health`

### Log Files

Monitor application logs:
```bash
tail -f log/canton-production.log
tail -f log/json-api-production.log
journalctl -u rwa-canton -f
journalctl -u rwa-json-api -f
```

### Database Monitoring

```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity WHERE datname IN ('canton_participant', 'canton_domain', 'json_api_store');

-- Check database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database 
WHERE datname IN ('canton_participant', 'canton_domain', 'json_api_store');
```

## 🔄 Updates and Maintenance

### Regular Maintenance Tasks

1. **Token Rotation**: Regularly generate new JWT tokens
2. **Certificate Renewal**: Update TLS certificates before expiry  
3. **Database Backup**: Regular PostgreSQL backups
4. **Log Rotation**: Configure logrotate for application logs
5. **Security Updates**: Keep Java, PostgreSQL, and NGINX updated

### Backup Strategy

```bash
# Database backups
pg_dump -h localhost -U canton_prod canton_participant > backup_participant_$(date +%Y%m%d).sql
pg_dump -h localhost -U canton_prod canton_domain > backup_domain_$(date +%Y%m%d).sql
pg_dump -h localhost -U json_api_prod json_api_store > backup_json_api_$(date +%Y%m%d).sql

# Configuration backup
tar -czf config_backup_$(date +%Y%m%d).tar.gz config/
```

## 🆘 Troubleshooting

### Common Issues

1. **Canton won't start**: Check database connectivity and TLS certificates
2. **JSON API connection failed**: Verify Canton is running and client certificates are valid
3. **Token validation failed**: Check JWT signing certificate and token expiry
4. **NGINX 502 errors**: Ensure JSON API is running on the expected port

### Debug Commands

```bash
# Check system status
./deploy-production.sh status

# Validate certificates
openssl x509 -in config/tls/ledger-api.crt -text -noout

# Test database connection
psql -h localhost -U canton_prod -d canton_participant -c "SELECT 1;"

# Validate JWT token
./jwt-manager-production.js validate "your-token-here"
```

## 🚀 Going Live Checklist

- [ ] PostgreSQL databases created and secured
- [ ] TLS certificates installed and valid
- [ ] Environment variables configured
- [ ] Canton nodes started with production config
- [ ] JSON API running behind NGINX proxy
- [ ] JWT tokens generated and tested
- [ ] User-party mappings configured
- [ ] Health monitoring setup
- [ ] Backup strategy implemented
- [ ] Security review completed
- [ ] Load testing performed

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review Canton documentation: https://docs.daml.com/canton/
- Monitor system logs for detailed error messages
- Verify all configuration files match your environment

---

**⚠️ Security Note**: This production setup includes comprehensive security measures, but always perform a security audit before deploying to production with real assets.