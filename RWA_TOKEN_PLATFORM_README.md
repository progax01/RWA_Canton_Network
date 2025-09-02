# RWA Token Platform - Complete Setup & User Guide

## 🏗️ Overview

The RWA (Real World Asset) Token Platform is a Daml-based system that enables the creation, management, and trading of tokenized assets (like Gold and Silver tokens). The platform runs on Canton and provides REST API access through the Daml JSON API.

This guide provides complete instructions to clone, setup, and run the RWA Token Platform on any system from scratch.

## ⚡ Quick Start

For experienced users who want to get running immediately:

```bash
# 1. Prerequisites: Install Java 11+, Node.js 16+, PostgreSQL 12+
# 2. Set environment variables
export POSTGRES_ADMIN_PASSWORD=your_postgres_password
export CANTON_DB_PASSWORD=your_canton_password

# 3. Clone and setup
git clone <repository-url>
cd canton-open-source-2.10.2
npm install

# 4. Automated setup
./config/scripts/setup-canton-production.sh --generate-certs --yes

# 5. Setup network and generate tokens
./config/scripts/connect-participant-domain.sh --create-parties --upload-dars
node generateJWT.js

# 6. Start JSON API and test
./start_json_api.sh &
source jwt-tokens-shell.txt
curl -X GET http://localhost:7575/v1/parties -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN"
```

If quick start fails, follow the detailed setup instructions below.

## 📋 Table of Contents

1. [Prerequisites & System Requirements](#prerequisites--system-requirements)
2. [Installation & Setup](#installation--setup)
3. [Platform Architecture](#platform-architecture)
4. [Authentication Setup](#authentication-setup)
5. [Contract Types](#contract-types)
6. [Admin Journey](#admin-journey)
7. [User Journey](#user-journey)
8. [Query Commands Reference](#query-commands-reference)
9. [Complete Workflows](#complete-workflows)
10. [Troubleshooting](#troubleshooting)

---

## 🔧 Prerequisites & System Requirements

### System Requirements

- **Operating System**: Linux, macOS, or WSL2 on Windows
- **RAM**: 8GB minimum, 16GB recommended
- **CPU**: 4 cores minimum, 8+ cores recommended  
- **Disk Space**: 20GB+ free space
- **Java**: JDK 11+ (JDK 17+ recommended)
- **Node.js**: 16+ for JWT token generation

### Required Software

Before starting, ensure these tools are installed:

```bash
# Check Java version (must be 11+)
java -version

# Check Node.js version (must be 16+)
node --version

# PostgreSQL with client tools
psql --version

# Additional utilities
curl --version
nc -h  # netcat for port checking
jq --version  # JSON processing
```

### Database Setup

**PostgreSQL 12+ is required**. Install and configure:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# macOS with Homebrew
brew install postgresql

# Start PostgreSQL service
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS

# Create admin user and set password
sudo -u postgres createuser --interactive --pwprompt
```

Set these environment variables for database access:
```bash
export POSTGRES_HOST=localhost
export POSTGRES_ADMIN_PASSWORD=your_admin_password
export CANTON_DB_PASSWORD=your_strong_canton_password
```

---

## 🚀 Installation & Setup

### Step 1: Clone the Repository

```bash
# Clone the repository
git clone <repository-url>
cd canton-open-source-2.10.2

# Verify structure
ls -la
```

### Step 2: Install Dependencies

```bash
# Install Node.js dependencies for JWT generation
npm install

# Verify JWT library is installed
npm list jsonwebtoken
```

### Step 3: Automated Setup (Recommended)

**Option A: Quick Setup with Test Certificates**
```bash
# Set required environment variables
export POSTGRES_ADMIN_PASSWORD=your_postgres_admin_password
export CANTON_DB_PASSWORD=your_strong_canton_password

# Run automated setup
chmod +x config/scripts/setup-canton-production.sh
./config/scripts/setup-canton-production.sh --generate-certs --yes
```

**Option B: Interactive Setup**
```bash
# Interactive setup with prompts
./config/scripts/setup-canton-production.sh --interactive
```

### Step 4: Manual Setup (If Needed)

If automated setup doesn't work, run each component manually:

**4.1 Validate Environment**
```bash
chmod +x config/scripts/validate-environment.sh
./config/scripts/validate-environment.sh --report
```

**4.2 Setup Database**
```bash
chmod +x config/scripts/setup-database.sh
./config/scripts/setup-database.sh --verify
```

**4.3 Setup Certificates**
```bash
chmod +x config/scripts/verify-certificates.sh
./config/scripts/verify-certificates.sh --generate
```

**4.4 Start Canton Network**
```bash
chmod +x config/scripts/start-canton-network.sh
./config/scripts/start-canton-network.sh --console
```

### Step 5: Setup Network Topology

```bash
# Connect participant to domain and create parties
chmod +x config/scripts/connect-participant-domain.sh
./config/scripts/connect-participant-domain.sh --create-parties --upload-dars
```

### Step 6: Generate JWT Tokens

```bash
# Generate all JWT tokens for authentication
node generateJWT.js

# Verify tokens were created
ls -la *jwt-token.txt
cat jwt-tokens-shell.txt
```

### Step 7: Start JSON API Service

```bash
# Start the HTTP JSON API service
chmod +x start_json_api.sh
./start_json_api.sh
```

The JSON API will be available at `http://localhost:7575`

### Step 8: Verify Installation

```bash
# Load JWT tokens
source jwt-tokens-shell.txt

# Test participant admin API
curl -X GET http://localhost:7575/v1/parties \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN"

# Test bank admin token  
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"]}'
```

### Step 9: Run Complete Test Flow

Execute the complete token lifecycle test:
```bash
# Run automated test workflow
chmod +x test-rwa-flow.js
node test-rwa-flow.js
```

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
      "to": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 1000
    }
  }' |jq

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
  -H "Authorization: Bearer $Charlie" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"],
    "query": {
      "owner": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
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
echo $GOLD_REGISTRY_ID

curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $Charlie_bank" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Transfer",
    "argument": {
      "sender": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "recipient": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 30
    }
  }' |jq
```

### Step 3: Request Token Redemption

```bash
# Alice requests to redeem 50 Gold tokens (requires multi-party token)
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $Charlie_bank" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "RequestRedemption",
    "argument": {
      "redeemer": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 500
    }
  }' |jq
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
  -d '{"identifierHint": "NewCharlie", "displayName": "NewCharlie"}')

echo "$NEW_PARTY_RESULT" | jq '.'

# Extract the party ID (you'll need to do this manually from the response)
# NEW_CHARLIE_PARTY="NewCharlie::1220..."

# 2. Create user account
echo "2. Creating user account 'NewCharlie'..."
curl -s -X POST http://localhost:7575/v1/user/create \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "NewCharlie",
    "primaryParty": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "rights": [
      { "type": "CanActAs",  "party": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d" },
      { "type": "CanReadAs", "party": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d" }
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

### Workflow 3: Register Multi-Party User for Transfers

```bash
#!/bin/bash
source jwt-tokens-shell.txt

echo "=== Registering Multi-Party User in Canton Network ==="

# Example: Adding user 'vivek11' who can perform transfers and redemptions

# 1. Get the existing party ID (assuming party already exists in Canton)
echo "1. Using existing party: vivek11::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
VIVEK_PARTY="vivek11::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"

# 2. Create user account for multi-party operations
echo "2. Creating multi-party user account 'charlie_bank_token'..."
curl -X POST http://localhost:7575/v1/user/create \
  -H "Authorization: Bearer $PARTICIPANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "charlie_bank_token",
    "primary_party": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
  "rights": [
      { "type": "CanActAs",  "party": "NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"},
      { "type": "CanActAs",  "party":"NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d" },
      { "type": "CanReadAs", "party":"NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"},
      { "type": "CanReadAs","party":"NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d" }
    ]
  }' | jq

# 3. Export the multi-party JWT token (includes both user and bank permissions)
echo "3. Setting up multi-party JWT token..."
export VIVEK_BANK_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzY29wZSI6ImRhbWxfbGVkZ2VyX2FwaSIsImF1ZCI6Imh0dHBzOi8vZGFtbC5jb20vand0L2F1ZC9wYXJ0aWNpcGFudC9wYXJ0aWNpcGFudDEiLCJzdWIiOiJ2aXZlazExX2JhbmtfdG9rZW4iLCJpc3MiOiJjYW50b24tand0LWlzc3VlciIsImV4cCI6MTc4NzcyNzUwNywiaWF0IjoxNzU2MTkxNTA3LCJhY3RBcyI6WyJ2aXZlazExOjoxMjIwYjg0NWRjZjBkOWNmNTJjZTFlNzQ1N2E3NDRhNmYzZGU3ZWZmNGE5ZWU5NTI2MWI2OTQwNWQxZTBkZThhNzY4ZCIsIk5ld0Jhbms6OjEyMjBiODQ1ZGNmMGQ5Y2Y1MmNlMWU3NDU3YTc0NGE2ZjNkZTdlZmY0YTllZTk1MjYxYjY5NDA1ZDFlMGRlOGE3NjhkIl0sInJlYWRBcyI6WyJ2aXZlazExOjoxMjIwYjg0NWRjZjBkOWNmNTJjZTFlNzQ1N2E3NDRhNmYzZGU3ZWZmNGE5ZWU5NTI2MWI2OTQwNWQxZTBkZThhNzY4ZCIsIk5ld0Jhbms6OjEyMjBiODQ1ZGNmMGQ5Y2Y1MmNlMWU3NDU3YTc0NGE2ZjNkZTdlZmY0YTllZTk1MjYxYjY5NDA1ZDFlMGRlOGE3NjhkIl19.Do_nYAp7CAkitvOtcuSMJHjFfFO0WOSK5NfSFjYAV_t7H54Le_CwvRphDGWlOc_EwE_qlx9IcJPx0ALrmE3g-FBAJugl8xLNCucO7zWAxkRh82p6SGynA-sqL4BYwIaDFfeeXTmz2mp-pHiObd8DJjDCj7-kzUpt49xuU1iQ-oLVQfNK_T6Drmgru8Iq-tFuZBu07P3NOVaC_RnfmKtPQYcf_e7AlEpTih-HifSGg6wQ8Jy6AaHzi7R48_0xGlsmX3muRygrPMKaxsTiyljTs9p2MB9lgPQvSrSnYISxW0xO8-pqSlZSfFxq-X79LT9dfEFXM0t7rHopmi_wkiRrUA"

# Note: This JWT token contains:
# - sub: "vivek11_bank_token" (matches the user_id created above)
# - actAs: ["vivek11::1220...", "NewBank::1220..."] (can act as both user and bank)
# - readAs: ["vivek11::1220...", "NewBank::1220..."] (can read both user and bank data)

echo "Multi-party token configured for vivek11_bank_token user"

# 4. Verify the user can query their tokens
echo "4. Testing user token - checking vivek11's balance..."
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $VIVEK_BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"],
    "query": {
      "owner": "'"$VIVEK_PARTY"'"
    }
  }' | jq '.result[] | "vivek11 has " + (.payload.amount | tostring) + " " + .payload.symbol + " tokens"'

# 5. Test multi-party transfer capability
echo "5. Testing multi-party transfer - vivek11 transfers 10 GLD to Bob..."

# Get Gold Registry ID
GOLD_REGISTRY_ID=$(curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $BANK_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry"], "query": {"symbol": "GLD"}}' \
  | jq -r '.result[0].contractId')

echo "Using Gold Registry: $GOLD_REGISTRY_ID"

# Execute transfer using multi-party token
curl -X POST http://localhost:7575/v1/exercise \
  -H "Authorization: Bearer $VIVEK_BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:AssetRegistry",
    "contractId": "'"$GOLD_REGISTRY_ID"'",
    "choice": "Transfer",
    "argument": {
      "sender": "'"$VIVEK_PARTY"'",
      "recipient": "NewBob::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
      "amount": 10
    }
  }' | jq '.status'

# 6. Verify transfer completed
echo "6. Verifying transfer completed - checking updated balances..."
curl -s -X POST http://localhost:7575/v1/query \
  -H "Authorization: Bearer $VIVEK_BANK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateIds": ["323be96aa0b9cd4a6f9cf17a5096b7a69c0cc2da28d31baa5e53c72f2c8ce9c1:TokenExample:Token"],
    "query": {
      "owner": "'"$VIVEK_PARTY"'"
    }
  }' | jq '.result[] | "vivek11 now has " + (.payload.amount | tostring) + " " + .payload.symbol + " tokens"'

echo "=== Multi-Party User Registration Complete ==="
echo ""
echo "Summary:"
echo "✓ User 'vivek11_bank_token' created with multi-party permissions"
echo "✓ JWT token configured with both user and bank actAs/readAs rights"
echo "✓ User can now perform transfers and redemption requests"
echo "✓ Token works for both querying and multi-party operations"
```

### Key Points for Multi-Party Users

**Why Multi-Party Tokens are Needed:**
- **Transfer Operations**: Require both sender authorization AND AssetRegistry contract permissions (Bank)
- **Redemption Requests**: Need user consent AND Bank contract signature
- **Security**: Ensures both parties (user + Bank) approve multi-party operations

**JWT Token Structure for Multi-Party Users:**
```json
{
  "sub": "vivek11_bank_token",
  "actAs": [
    "vivek11::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d",
    "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
  ],
  "readAs": [
    "vivek11::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d", 
    "NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d"
  ]
}
```

**Operations Requiring Multi-Party Tokens:**
- ✅ **Transfer**: Sender + Bank permissions needed
- ✅ **RequestRedemption**: User + Bank permissions needed  
- ❌ **Query**: Single-party token sufficient
- ❌ **Mint**: Bank-only token sufficient

---

## 🚨 Troubleshooting

### Setup and Installation Issues

#### 1. Database Connection Failed
```bash
# Problem: Cannot connect to PostgreSQL
# Solutions:
# Check if PostgreSQL is running
sudo systemctl status postgresql  # Linux
brew services list postgresql     # macOS

# Test direct connection
psql -h localhost -U postgres -d postgres

# Re-run database setup
export POSTGRES_ADMIN_PASSWORD=your_password
export CANTON_DB_PASSWORD=your_canton_password
./config/scripts/setup-database.sh --force
```

#### 2. Java Version Issues
```bash
# Problem: "Unsupported Java version" or "JAVA_HOME not set"
# Solutions:
# Check Java version (must be 11+)
java -version

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64  # Linux
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home  # macOS

# Install correct Java version
sudo apt install openjdk-17-jdk  # Ubuntu
brew install openjdk@17          # macOS
```

#### 3. Port Conflicts
```bash
# Problem: "Address already in use" errors
# Solutions:
# Check what's using Canton ports
netstat -tuln | grep ':501[1289]\|:7575\|:9000'
lsof -i :5011  # Check specific port

# Kill conflicting processes
pkill -f canton
pkill -f http-json

# Find and kill process by port
sudo kill $(sudo lsof -t -i:5011)
```

### Runtime Issues

#### 4. Authentication Errors (401/403)
```bash
# Error: "missing Authorization header" or "invalid token"
# Solutions:
# Check if tokens are loaded
echo $BANK_ADMIN_TOKEN | cut -c1-50

# Reload tokens if empty
source jwt-tokens-shell.txt

# Regenerate tokens if corrupted
node generateJWT.js
source jwt-tokens-shell.txt
```

#### 5. Contract Not Found Errors
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

---

## 📚 Additional Information

### Service Endpoints

After successful setup, these endpoints will be available:

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| JSON API | 7575 | `http://localhost:7575` | REST API for ledger operations |
| Canton Participant Ledger API | 5011 | `grpc://localhost:5011` | gRPC API (TLS enabled) |
| Canton Admin API | 5012 | `https://localhost:5012` | Participant administration |
| Health Check | 5013 | `grpc://localhost:5013` | Health monitoring |
| Metrics | 9000 | `http://localhost:9000/metrics` | Prometheus metrics |

### File Structure

Key files and directories in the project:

```
canton-open-source-2.10.2/
├── config/
│   ├── scripts/                    # Setup and management scripts
│   ├── tls/                       # TLS certificates
│   ├── jwt/                       # JWT signing keys
│   └── canton-single-participant.conf  # Main Canton config
├── daml/
│   └── RWA/TokenExample.daml      # Smart contract code
├── dars/RWA.dar                   # Compiled smart contract
├── generateJWT.js                 # JWT token generator
├── start_json_api.sh              # JSON API startup script
├── jwt-tokens-shell.txt           # Generated JWT tokens
└── log/                           # Canton logs
```

### Environment Variables

Set these variables for optimal operation:

```bash
# Database
export POSTGRES_HOST=localhost
export POSTGRES_ADMIN_PASSWORD=your_admin_password
export CANTON_DB_PASSWORD=your_canton_password

# JVM Performance
export JAVA_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:G1HeapRegionSize=16m"

# Canton Configuration
export CONFIG_FILE=config/canton-single-participant.conf
```

### Useful Scripts

The project includes several utility scripts:

- **`config/scripts/setup-canton-production.sh`**: Master setup script
- **`config/scripts/validate-environment.sh`**: System validation
- **`generateJWT.js`**: Generate authentication tokens  
- **`start_json_api.sh`**: Start REST API service
- **`test-rwa-flow.js`**: End-to-end testing

### Support and Documentation

- **Canton Documentation**: https://docs.daml.com/canton/
- **Daml Documentation**: https://docs.daml.com/
- **JSON API Reference**: https://docs.daml.com/json-api/
- **Script Documentation**: `config/scripts/README.md`

For issues with setup or usage, check:
1. Canton logs in `log/canton.log`
2. JSON API logs in `json-api.log`
3. Environment validation: `./config/scripts/validate-environment.sh --report`

### Security Notes

- **Test Certificates**: This setup uses test certificates suitable for development only
- **Production**: Replace test certificates with proper CA-issued certificates for production
- **Database Security**: Use strong passwords and restrict database access
- **API Security**: JWT tokens provide authentication - keep them secure