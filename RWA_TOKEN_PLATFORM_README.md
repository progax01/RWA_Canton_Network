# RWA Token Platform - Complete User Guide

## 🏗️ Overview

The RWA (Real World Asset) Token Platform is a Daml-based system that enables the creation, management, and trading of tokenized assets (like Gold and Silver tokens). The platform runs on Canton and provides REST API access through the Daml JSON API.

## 📋 Table of Contents

1. [Platform Architecture](#platform-architecture)
2. [Authentication Setup](#authentication-setup)
3. [Contract Types](#contract-types)
4. [Admin Journey](#admin-journey)
5. [User Journey](#user-journey)
6. [Query Commands Reference](#query-commands-reference)
7. [Complete Workflows](#complete-workflows)
8. [Troubleshooting](#troubleshooting)

---

## 🏛️ Platform Architecture

### Components
- **Canton Participant**: Blockchain ledger node
- **Daml JSON API**: REST API gateway (port 7575)
- **JWT Authentication**: Token-based security
- **Multi-party Contracts**: Require multiple signatures for some operations

### Key Parties
- **NewBank**: Asset issuer and admin
- **NewAlice**: Regular user
- **NewBob**: Regular user
- **participant1**: System administrator

---

## 🔐 Authentication Setup

### 1. Load JWT Tokens
```bash
# Load all authentication tokens
source jwt-tokens-shell.txt

# Verify tokens are loaded
echo "Bank: $BANK_ADMIN_TOKEN" | cut -c1-50
echo "Alice: $ALICE_USER_TOKEN" | cut -c1-50
echo "Multi-party Alice+Bank: $ALICE_BANK_TOKEN_TOKEN" | cut -c1-50
```

### 2. Available Token Types

| Token Type | Purpose | Usage |
|------------|---------|--------|
| `$BANK_ADMIN_TOKEN` | Bank operations (mint, admin) | Create registries, mint tokens |
| `$ALICE_USER_TOKEN` | Alice operations (query own assets) | View Alice's tokens |
| `$BOB_USER_TOKEN` | Bob operations (query own assets) | View Bob's tokens |
| `$ALICE_BANK_TOKEN_TOKEN` | Multi-party (Alice + Bank) | Transfer, redemption requests |
| `$BOB_BANK_TOKEN_TOKEN` | Multi-party (Bob + Bank) | Transfer, redemption requests |
| `$PARTICIPANT_ADMIN_TOKEN` | System admin | Manage parties, users |

---

## 📄 Contract Types

### 1. AssetRegistry Contract
**Purpose**: Manages each token type (Gold, Silver, etc.)
- **Signatory**: Bank
- **Key**: Admin party + symbol
- **Choices**: Mint, Transfer, RequestRedemption

### 2. Token Contract  
**Purpose**: Represents actual token holdings
- **Signatory**: Bank (issuer)
- **Observer**: Owner
- **Key**: Issuer + Owner + Symbol

### 3. RedeemRequest Contract
**Purpose**: Handles token redemption requests
- **Signatory**: Bank
- **Observer**: Token owner
- **Choices**: Accept (burn tokens), Cancel (return tokens)

---

## 👨‍💼 Admin Journey

### Step 1: Create Asset Registries

```bash
# Create Gold Token Registry
curl -X POST http://localhost:7575/v1/create \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "payload": {
      "admin": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "name": "Gold Token",
      "symbol": "GLD"
    }
  }'
```

```bash
# Create Silver Token Registry
curl -X POST http://localhost:7575/v1/create \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "payload": {
      "admin": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "name": "Silver Token",
      "symbol": "SLV"
    }
  }'
```

### Step 2: Mint Initial Tokens

```bash
# First, get the Gold Registry contract ID
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')

# Mint 100 Gold tokens to Alice
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Mint",
    "argument": {
      "to": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 100
    }
  }'

# Mint 50 Gold tokens to Bob
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Mint",
    "argument": {
      "to": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 50
    }
  }'
```

### Step 3: Manage Redemption Requests

```bash
# View pending redemption requests
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest"]
  }' | jq -r '.result[] | "Request ID: " + .contractId + " | Owner: " + .payload.owner + " | Amount: " + (.payload.amount | tostring) + " " + .payload.symbol'

# Accept a redemption request (burns tokens)
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest",
    "contractId": "REDEEM_REQUEST_CONTRACT_ID",
    "choice": "Accept",
    "argument": {}
  }'

# Cancel a redemption request (returns tokens to user)
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest",
    "contractId": "REDEEM_REQUEST_CONTRACT_ID",
    "choice": "Cancel",
    "argument": {}
  }'
```

---

## 👤 User Journey

### Step 1: Check Token Balance

```bash
# Alice checks her token holdings
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"],
    "query": {
      "owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
    }
  }' | jq -r '.result[] | "Alice has " + (.payload.amount | tostring) + " " + .payload.symbol + " tokens"'
```

### Step 2: Transfer Tokens

```bash
# Alice transfers 30 Gold tokens to Bob (requires multi-party token)
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')

curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $ALICE_BANK_TOKEN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Transfer",
    "argument": {
      "sender": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "recipient": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 30
    }
  }'
```

### Step 3: Request Token Redemption

```bash
# Alice requests to redeem 50 Gold tokens (requires multi-party token)
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $ALICE_BANK_TOKEN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "RequestRedemption",
    "argument": {
      "redeemer": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 50
    }
  }'
```

---

## 🔍 Query Commands Reference

### 1. Get All Parties
```bash
curl -X GET http://localhost:7575/v1/parties \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

### 2. Query Asset Registries

```bash
# All asset registries
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"]}' \
  | jq -r '.result[] | "Registry: " + .payload.symbol + " (" + .payload.name + ") | ID: " + .contractId'

# Specific asset registry (Gold)
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId'
```

### 3. Query Token Holdings

```bash
# Alice's tokens
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' \
  | jq -r '.result[] | "Token: " + .payload.symbol + " | Amount: " + (.payload.amount | tostring)'

# Bob's tokens  
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BOB_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' \
  | jq -r '.result[] | "Token: " + .payload.symbol + " | Amount: " + (.payload.amount | tostring)'

# All tokens (admin view)
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"]}' \
  | jq -r '.result[] | "Owner: " + .payload.owner + " | " + (.payload.amount | tostring) + " " + .payload.symbol'
```

### 4. Query Redemption Requests

```bash
# All pending redemption requests
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest"]}' \
  | jq -r '.result[] | "Request: " + .contractId + " | " + .payload.owner + " wants " + (.payload.amount | tostring) + " " + .payload.symbol'

# Alice's redemption requests
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest"], "query": {"owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' \
  | jq -r '.result[] | "Alice Request: " + (.payload.amount | tostring) + " " + .payload.symbol + " | ID: " + .contractId'
```

---

## 🎯 Complete Workflows

### Workflow 1: End-to-End Token Lifecycle

```bash
#!/bin/bash
source jwt-tokens-shell.txt

echo "=== Complete Token Lifecycle Test ==="

# 1. Create Gold Registry
echo "1. Creating Gold Registry..."
curl -s -X POST http://localhost:7575/v1/create \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry", "payload": {"admin": "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", "name": "Gold Token", "symbol": "GLD"}}' | jq '.status'

# 2. Get Registry ID
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')

echo "2. Gold Registry ID: $GOLD_REGISTRY_ID"

# 3. Mint tokens to Alice
echo "3. Minting 100 GLD to Alice..."
curl -s -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry", "contractId": "'"$GOLD_REGISTRY_ID"'", "choice": "Mint", "argument": {"to": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", "amount": 100}}' | jq '.status'

# 4. Check Alice's balance
echo "4. Alice's token balance:"
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' | jq -r '.result[] | "Alice: " + (.payload.amount | tostring) + " " + .payload.symbol'

# 5. Alice transfers to Bob
echo "5. Alice transfers 30 GLD to Bob..."
curl -s -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $ALICE_BANK_TOKEN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry", "contractId": "'"$GOLD_REGISTRY_ID"'", "choice": "Transfer", "argument": {"sender": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", "recipient": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", "amount": 30}}' | jq '.status'

# 6. Check updated balances
echo "6. Updated balances:"
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' | jq -r '.result[] | "Alice: " + (.payload.amount | tostring) + " " + .payload.symbol'

curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BOB_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' | jq -r '.result[] | "Bob: " + (.payload.amount | tostring) + " " + .payload.symbol'

# 7. Alice requests redemption
echo "7. Alice requests redemption of 20 GLD..."
curl -s -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $ALICE_BANK_TOKEN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry", "contractId": "'"$GOLD_REGISTRY_ID"'", "choice": "RequestRedemption", "argument": {"redeemer": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", "amount": 20}}' | jq '.status'

# 8. Check redemption request
echo "8. Pending redemption requests:"
REDEEM_REQUEST_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest"]}' \
  | jq -r '.result[0].contractId')

echo "Redemption Request ID: $REDEEM_REQUEST_ID"

# 9. Bank accepts redemption
echo "9. Bank accepts redemption request..."
curl -s -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:RedeemRequest", "contractId": "'"$REDEEM_REQUEST_ID"'", "choice": "Accept", "argument": {}}' | jq '.status'

# 10. Final balances
echo "10. Final balances:"
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $ALICE_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewAlice::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' | jq -r '.result[] | "Alice Final: " + (.payload.amount | tostring) + " " + .payload.symbol'

curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BOB_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"], "query": {"owner": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"}}' | jq -r '.result[] | "Bob Final: " + (.payload.amount | tostring) + " " + .payload.symbol'

echo "=== Workflow Complete ==="
```

### Workflow 2: Add New User to Platform

```bash
#!/bin/bash
source jwt-tokens-shell.txt

echo "=== Adding New User to Platform ==="

# 1. Create new party
echo "1. Creating new party 'NewCharlie'..."
NEW_PARTY_RESULT=$(curl -s -X POST http://localhost:7575/v1/parties/allocate \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"identifierHint": "NewCharlie", "displayName": "Charlie"}')

echo "$NEW_PARTY_RESULT" | jq '.'

# Extract the party ID (you'll need to do this manually from the response)
# NEW_CHARLIE_PARTY="NewCharlie::1220..."

# 2. Create user account
echo "2. Creating user account 'charlie_user'..."
curl -s -X POST http://localhost:7575/v1/user/create \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "charlie_user",
    "primaryParty": "'"$NEW_CHARLIE_PARTY"'",
    "rights": [
      { "type": "CanActAs",  "party": "'"$NEW_CHARLIE_PARTY"'" },
      { "type": "CanReadAs", "party": "'"$NEW_CHARLIE_PARTY"'" }
    ]
  }' | jq '.'

# 3. Generate JWT token for new user (you'd need to update generateJWT.js)
echo "3. Generate JWT token for charlie_user using generateJWT.js"

# 4. Mint tokens to new user
echo "4. Admin mints 75 GLD tokens to Charlie..."
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')

curl -s -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Mint",
    "argument": {
      "to": "'"$NEW_CHARLIE_PARTY"'",
      "amount": 75
    }
  }' | jq '.status'

echo "=== New User Setup Complete ==="
```

---

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. Authentication Errors (401/403)
```bash
# Error: "missing Authorization header"
# Solution: Ensure you're using the correct JWT token

# Check if tokens are loaded
echo $BANK_ADMIN_TOKEN | cut -c1-50

# Reload tokens if empty
source jwt-tokens-shell.txt
```

#### 2. Contract Not Found Errors
```bash
# Error: "CONTRACT_NOT_FOUND"
# Solution: Use the correct contract ID from queries

# Get fresh contract ID
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')
```

#### 3. Permission Denied Errors
```bash
# Error: "PERMISSION_DENIED"
# Solution: Use multi-party tokens for operations requiring multiple parties

# For Transfer and RequestRedemption, use:
# $ALICE_BANK_TOKEN_TOKEN or $BOB_BANK_TOKEN_TOKEN
```

#### 4. JSON Parsing Errors
```bash
# Error: "JsonReaderError"
# Solution: Ensure JSON is on single line with no line breaks

# Bad:
curl -d '{
  "templateId": "...",
  "contractId": "..."
}'

# Good:
curl -d '{"templateId": "...", "contractId": "..."}'
```

#### 5. Template ID Errors
```bash
# Error: "did not have two ':' chars"
# Solution: Use full template ID format

# Correct format:
"templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"

# Wrong format:
"templateId": "TokenExample.AssetRegistry"
```

### Debug Commands

```bash
# 1. Check API connectivity
curl -X GET http://localhost:7575/v1/parties \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN"

# 2. Verify JWT token structure
node -e "console.log(require('jsonwebtoken').decode('$ALICE_USER_TOKEN', {complete: true}))"

# 3. Check Canton participant status
curl -X GET http://localhost:7575/v1/parties \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN"

# 4. View all active contracts
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"]}' | jq '.result | length'
```

---

## 📝 Summary

This README provides comprehensive guidance for:
- **Admins**: Create registries, mint tokens, manage redemptions
- **Users**: Check balances, transfer tokens, request redemptions  
- **Developers**: Query all contract states, debug issues

**Key Takeaways:**
1. Always use appropriate JWT tokens for operations
2. Multi-party operations require multi-party tokens
3. Get fresh contract IDs from queries before operations
4. Use proper JSON formatting (single line, no breaks)
5. Follow the template ID format exactly

For additional support, check the troubleshooting section or examine the Canton console logs.