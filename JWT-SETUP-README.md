# JWT Authentication Setup for RWA Platform

This guide covers the complete setup of production-grade JWT authentication for the RWA Platform using Canton Ledger API and JSON API service.

## 🔐 Security Overview

The RWA platform now uses **RS256 JWT tokens** for secure authentication, eliminating the need for `--allow-insecure-tokens`. This setup includes:

- **RSA key pair** for token signing/verification
- **Canton Ledger API** configured for JWT validation
- **JSON API service** without insecure token allowance
- **Multi-party tokens** for complex operations requiring multiple signatories

## 📁 Generated Files

| File | Description |
|------|-------------|
| `config/jwt/jwt-sign.key` | Private RSA key for signing JWTs |
| `config/jwt/jwt-sign.crt` | Public certificate for verifying JWTs |
| `generate_jwt_tokens.js` | Node.js script to generate JWT tokens |
| `jwt-tokens.json` | Generated JWT tokens in JSON format |
| `load_jwt_tokens.sh` | Shell script to export tokens as env vars |
| `curl_examples.sh` | Ready-to-use curl commands |
| `start_json_api.sh` | JSON API startup script |
| `test_jwt_api.sh` | JWT authentication test script |

## 🚀 Quick Start

### 1. Generate JWT Tokens

```bash
# Generate all required JWT tokens
node generate_jwt_tokens.js

# Load tokens into environment
source ./load_jwt_tokens.sh
```

### 2. Start Canton Network (JWT-enabled)

```bash
# Start Canton with JWT authentication enabled
./bin/canton -c config/canton-single-participant.conf
```

### 3. Start JSON API Service

```bash
# Start JSON API with JWT authentication (no insecure tokens)
./start_json_api.sh
```

### 4. Test JWT Authentication

```bash
# Test JWT authentication with sample requests
./test_jwt_api.sh
```

## 🔑 Available JWT Tokens

### Individual Party Tokens

| Token | Purpose | Can Act As |
|-------|---------|------------|
| `$BANK_TOKEN` | Bank operations (admin) | NewBank |
| `$ALICE_TOKEN` | Alice operations | NewAlice |  
| `$BOB_TOKEN` | Bob operations | NewBob |

### Multi-Party Tokens

| Token | Purpose | Can Act As |
|-------|---------|------------|
| `$BANK_ALICE_TOKEN` | Alice transfers/redemptions | NewBank + NewAlice |
| `$BANK_BOB_TOKEN` | Bob transfers | NewBank + NewBob |

### Why Multi-Party Tokens?

Due to the RWA contract design, the `AssetRegistry` is only visible to the Bank (admin). When users exercise choices on the registry (like `Transfer` or `RequestRedemption`), the JSON API needs to act as both the user and the Bank to access the contract.

## 📝 JSON API Operations

### Create Asset Registry

```bash
curl -X POST http://localhost:7575/v1/create \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "payload": {
      "admin": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9e5261b69405d1e0de8a768d",
      "name": "Gold Token", 
      "symbol": "GLD"
    }
  }'
```

### Mint Tokens

```bash
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "[GOLD_REGISTRY_CONTRACT_ID]",
    "choice": "Mint",
    "argument": {
      "to": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 100
    }
  }'
```

### Transfer Tokens (Multi-Party Authentication)

```bash
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "[GOLD_REGISTRY_CONTRACT_ID]",
    "choice": "Transfer",
    "argument": {
      "sender": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "recipient": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 30
    }
  }'
```

### Query User Tokens

```bash
curl -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"],
    "query": {
      "owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
    }
  }'
```

### Request Redemption

```bash
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry", 
    "contractId": "[GOLD_REGISTRY_CONTRACT_ID]",
    "choice": "RequestRedemption",
    "argument": {
      "redeemer": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 50
    }
  }'
```

### Accept/Cancel Redemption

```bash
# Accept redemption (burns tokens)
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest",
    "contractId": "[REDEEM_REQUEST_CONTRACT_ID]", 
    "choice": "Accept",
    "argument": {}
  }'

# Cancel redemption (returns tokens)  
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest",
    "contractId": "[REDEEM_REQUEST_CONTRACT_ID]",
    "choice": "Cancel", 
    "argument": {}
  }'
```

## ⚙️ Configuration Details

### Canton Configuration

The `config/canton-single-participant.conf` has been updated with JWT authentication:

```hocon
ledger-api {
  port = 5011
  address = "0.0.0.0"
  # Enable JWT authorization using RSA-signed certificate
  auth-services = [{
    # verify tokens signed with RS256 (RSA-SHA256)
    type = jwt-rs-256-crt
    certificate = "config/jwt/jwt-sign.crt"
  }]
}
```

### JWT Token Structure

Each JWT contains the following claims:

```json
{
  "https://daml.com/ledger-api": {
    "ledgerId": "participant1",
    "applicationId": "rwa-json-api", 
    "actAs": ["NewBank::1220...", "NewAlice::1220..."]
  },
  "exp": 1755867869,
  "iat": 1755864269,
  "iss": "rwa-platform"
}
```

## 🔒 Security Best Practices

### Token Management

1. **Expiry**: Tokens expire after 1 hour by default
2. **Rotation**: Regenerate tokens regularly in production
3. **Storage**: Keep private keys secure and never commit to version control
4. **Transport**: Use HTTPS in production environments

### Production Deployment

1. **TLS Configuration**: Enable TLS for JSON API service
2. **Certificate Management**: Use CA-signed certificates instead of self-signed
3. **Key Security**: Store private keys in secure key management systems
4. **Monitoring**: Implement JWT token usage monitoring and alerting

### Environment Variables

```bash
# Production environment setup
export JWT_PRIVATE_KEY_PATH="/secure/path/to/jwt-sign.key"
export JWT_CERTIFICATE_PATH="/secure/path/to/jwt-sign.crt"
export JSON_API_TLS_ENABLED="true"
export JSON_API_TLS_CERT="/path/to/server.crt"
export JSON_API_TLS_KEY="/path/to/server.key"
```

## 🧪 Testing and Validation

### Test JWT Token Validity

```bash
# Decode JWT token (using online decoder or jwt-cli)
echo $BANK_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

### Validate API Responses

```bash
# Test unauthorized access (should fail)
curl -X GET http://localhost:7575/v1/packages

# Test authorized access (should succeed)
curl -X GET http://localhost:7575/v1/packages \
  -H "Authorization: Bearer $BANK_TOKEN"
```

### Load Testing

```bash
# Simple load test with authorized requests
for i in {1..10}; do
  curl -s -H "Authorization: Bearer $ALICE_TOKEN" \
    -X POST http://localhost:7575/v1/query \
    -H "Content-Type: application/json" \
    -d '{"templateIds": ["323be96..."]}'
done
```

## 🚨 Troubleshooting

### Common Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` | Missing/invalid JWT | Check token format and expiry |
| `403 Forbidden` | Insufficient permissions | Use multi-party token for registry operations |
| `CONTRACT_NOT_FOUND` | Wrong party in actAs | Include Bank in actAs for registry access |
| `Connection refused` | JSON API not running | Start JSON API service |

### Debug Commands

```bash
# Check JWT token content
node -e "console.log(JSON.stringify(JSON.parse(Buffer.from('$BANK_TOKEN'.split('.')[1], 'base64').toString()), null, 2))"

# Test Canton connectivity
curl http://localhost:5011/health

# Test JSON API health  
curl http://localhost:7575/livez
```

## 📈 Performance Considerations

### JWT Token Caching

- Tokens are validated on each request
- Consider implementing token caching for high-throughput scenarios
- Monitor JWT validation performance

### Connection Pooling

- Use HTTP connection pooling for JSON API clients
- Implement proper retry mechanisms with exponential backoff

### Rate Limiting

- Implement rate limiting for JWT token generation
- Monitor API usage patterns and implement appropriate limits

## 🎯 Production Deployment Checklist

- [ ] Replace self-signed certificates with CA-signed certificates
- [ ] Enable TLS for JSON API service
- [ ] Implement proper key rotation procedures
- [ ] Set up monitoring and alerting for JWT operations
- [ ] Configure rate limiting and DDoS protection
- [ ] Implement audit logging for all API operations
- [ ] Set up backup and recovery procedures for keys
- [ ] Document incident response procedures
- [ ] Conduct security penetration testing
- [ ] Implement automated security scanning

---

## 🎉 Success!

Your RWA Platform now has production-grade JWT authentication! 

✅ **Secure**: RS256 signed tokens with proper key management  
✅ **Scalable**: Multi-party tokens support complex workflows  
✅ **Production-Ready**: No insecure token allowances  
✅ **Comprehensive**: Full testing and documentation suite

**Next Steps**: Deploy to production environment with proper TLS and monitoring.