# RWA (Real World Assets) Token Platform on Canton

A complete implementation of a Real World Assets token platform using Daml smart contracts deployed on Canton ledger. This platform supports minting, transferring, and redemption of tokenized assets like Gold and Silver.

## 🏗️ Architecture Overview

The platform consists of three main Daml templates:

1. **`Token`** - Represents individual token holdings for users
2. **`AssetRegistry`** - Manages token operations (mint, transfer, redemption requests)  
3. **`RedeemRequest`** - Handles pending redemption workflows

## 📋 Prerequisites

- Canton v2.10.2 or higher
- PostgreSQL database
- Daml SDK v2.10.2

## 🚀 Quick Start

### 1. Start Canton Network

```bash
cd /root/canton-prod/canton-open-source-2.10.2
./bin/canton -c config/canton-single-participant.conf
```

### 2. Run Complete Setup and Testing

Execute all commands from the file `config/scripts/New.txt` in your Canton console to:
- Connect to domain
- Create parties (Bank, Alice, Bob)
- Upload RWA contract
- Test all functionality

## 📖 Detailed Usage Guide

### Initial Setup Commands

```scala
// Connect participant to domain
participant1.domains.connect_local(mydomain)

// Create parties
val bank = participant1.parties.enable("NewBank") 
val alice = participant1.parties.enable("NewAlice")  
val bob = participant1.parties.enable("NewBob")

// Upload RWA contract
participant1.dars.upload("dars/RWA.dar")

// Get package ID
val rwaPkg = participant1.packages.find("TokenExample").head 
val rwaPackageId = rwaPkg.packageId
```

### Create Asset Registries

```scala
// Create Gold and Silver registries
val createGoldRegistryCmd = ledger_api_utils.create(rwaPackageId, 
  "TokenExample", "AssetRegistry", 
  Map("admin" -> bank, "name" -> "Gold Token", "symbol" -> "GLD"))

val createSilverRegistryCmd = ledger_api_utils.create(rwaPackageId, 
  "TokenExample", "AssetRegistry", 
  Map("admin" -> bank, "name" -> "Silver Token", "symbol" -> "SLV"))

participant1.ledger_api.commands.submit(Seq(bank), 
  Seq(createGoldRegistryCmd, createSilverRegistryCmd))
```

### Get Registry References

```scala
val registries = participant1.ledger_api.acs.of_party(bank)
  .filter(_.templateId.isModuleEntity("TokenExample", "AssetRegistry"))

val goldRegistry = registries.find(reg => 
  reg.arguments("symbol").toString.contains("GLD")).get
  
val silverRegistry = registries.find(reg => 
  reg.arguments("symbol").toString.contains("SLV")).get
```

### Mint Tokens

```scala
// Mint 100 Gold to Alice, 50 Gold to Bob
val mintAliceGoldCmd = ledger_api_utils.exercise("Mint", 
  Map("to" -> alice, "amount" -> 100), goldRegistry.event)
val mintBobGoldCmd = ledger_api_utils.exercise("Mint", 
  Map("to" -> bob, "amount" -> 50), goldRegistry.event)

participant1.ledger_api.commands.submit(Seq(bank), 
  Seq(mintAliceGoldCmd, mintBobGoldCmd))

// Mint Silver tokens similarly
val mintAliceSilverCmd = ledger_api_utils.exercise("Mint", 
  Map("to" -> alice, "amount" -> 100), silverRegistry.event)
val mintBobSilverCmd = ledger_api_utils.exercise("Mint", 
  Map("to" -> bob, "amount" -> 50), silverRegistry.event)

participant1.ledger_api.commands.submit(Seq(bank), 
  Seq(mintAliceSilverCmd, mintBobSilverCmd))
```

### Transfer Tokens

⚠️ **Important**: Include both sender and admin (bank) in `actAs` for contract visibility.

```scala
// Alice transfers 30 Gold to Bob
val transferGoldCmd = ledger_api_utils.exercise("Transfer", 
  Map("sender" -> alice, "recipient" -> bob, "amount" -> 30), 
  goldRegistry.event)

participant1.ledger_api.commands.submit(Seq(alice, bank), Seq(transferGoldCmd))

// Bob transfers 20 Silver to Alice  
val transferSilverCmd = ledger_api_utils.exercise("Transfer", 
  Map("sender" -> bob, "recipient" -> alice, "amount" -> 20), 
  silverRegistry.event)

participant1.ledger_api.commands.submit(Seq(bob, bank), Seq(transferSilverCmd))
```

### Redemption Workflow

#### Request Redemption

```scala
// Alice requests to redeem 50 Gold tokens
val redemptionReqCmd = ledger_api_utils.exercise("RequestRedemption", 
  Map("redeemer" -> alice, "amount" -> 50), goldRegistry.event)

participant1.ledger_api.commands.submit(Seq(alice, bank), Seq(redemptionReqCmd))
```

#### Admin Management

```scala
// Check pending redemptions
val pendingRedemptions = participant1.ledger_api.acs.of_party(bank)
  .filter(_.templateId.isModuleEntity("TokenExample", "RedeemRequest"))

val pendingReq = pendingRedemptions.head

// Option 1: Cancel redemption (returns tokens to user)
val cancelCmd = ledger_api_utils.exercise("Cancel", Map(), pendingReq.event)
participant1.ledger_api.commands.submit(Seq(bank), Seq(cancelCmd))

// Option 2: Accept redemption (burns tokens permanently)
val acceptCmd = ledger_api_utils.exercise("Accept", Map(), pendingReq.event)
participant1.ledger_api.commands.submit(Seq(bank), Seq(acceptCmd))
```

### Check Balances

```scala
// Check Alice's tokens
val aliceTokens = participant1.ledger_api.acs.of_party(alice)
  .filter(_.templateId.isModuleEntity("TokenExample", "Token"))
aliceTokens.foreach { token =>
  val symbol = token.arguments("symbol")
  val amount = token.arguments("amount")
  println(s"Alice has $amount $symbol tokens")
}

// Check Bob's tokens similarly
val bobTokens = participant1.ledger_api.acs.of_party(bob)
  .filter(_.templateId.isModuleEntity("TokenExample", "Token"))
bobTokens.foreach { token =>
  val symbol = token.arguments("symbol")
  val amount = token.arguments("amount")
  println(s"Bob has $amount $symbol tokens")
}
```

## 🔐 Authorization Model

### Contract Visibility Rules

1. **AssetRegistry**: Only visible to `admin` (Bank)
2. **Token**: Visible to `issuer` (Bank) and `owner` (token holder)
3. **RedeemRequest**: Visible to `admin` (Bank) and `owner` (requester)

### Key Authorization Requirement

⚠️ **Critical**: When users exercise choices on AssetRegistry (Transfer, RequestRedemption), include both the user and bank in the `actAs` list:

```scala
// ✅ Correct
participant1.ledger_api.commands.submit(Seq(alice, bank), Seq(command))

// ❌ Wrong - will fail with CONTRACT_NOT_FOUND
participant1.ledger_api.commands.submit(Seq(alice), Seq(command))
```

This is because only the Bank can see the AssetRegistry contract.

## 🎯 Supported Operations

| Operation | Controller | Description |
|-----------|------------|-------------|
| **Mint** | Admin (Bank) | Create new tokens for users |
| **Transfer** | Token Owner | Transfer tokens between users |
| **RequestRedemption** | Token Owner | Request to redeem tokens for real assets |
| **Accept** | Admin (Bank) | Approve redemption (burns tokens) |
| **Cancel** | Admin (Bank) | Reject redemption (returns tokens) |

## 📊 Token Flow Example

```
1. Bank creates AssetRegistry for Gold (GLD)
2. Bank mints 100 GLD to Alice
3. Alice transfers 30 GLD to Bob
   └── Alice: 70 GLD, Bob: 30 GLD
4. Alice requests redemption of 50 GLD
   └── 50 GLD locked, Alice: 20 GLD remaining
5. Bank accepts redemption
   └── 50 GLD burned permanently
   └── Final: Alice: 20 GLD, Bob: 30 GLD
```

## 🏷️ Contract Templates

### Token
```daml
template Token
  with
    issuer : Party    -- Bank
    owner  : Party    -- Token holder  
    name   : Text     -- "Gold Token"
    symbol : Text     -- "GLD" 
    amount : Int      -- Token quantity
```

### AssetRegistry  
```daml
template AssetRegistry
  with
    admin  : Party    -- Bank
    name   : Text     -- "Gold Token"
    symbol : Text     -- "GLD"
```

### RedeemRequest
```daml
template RedeemRequest  
  with
    admin  : Party    -- Bank
    owner  : Party    -- Requester
    name   : Text     -- "Gold Token"
    symbol : Text     -- "GLD"
    amount : Int      -- Redemption amount
```

## 🧪 Testing Scenarios

The platform includes comprehensive testing for:

- ✅ Token minting
- ✅ Token transfers between parties  
- ✅ Redemption request workflow
- ✅ Admin approval/cancellation
- ✅ Token burning on acceptance
- ✅ Balance validations
- ✅ Error handling (insufficient balance, duplicate redemptions)

## 🚨 Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `CONTRACT_NOT_FOUND` | User can't see AssetRegistry | Include Bank in `actAs` |
| `insufficient balance` | Not enough tokens to transfer | Check balance first |
| `redemption already requested` | Duplicate redemption | Wait for current request resolution |
| `amount must be > 0` | Invalid amount | Use positive integers only |

## 📁 File Structure

```
/root/canton-prod/canton-open-source-2.10.2/
├── daml/RWA/
│   ├── TokenExample.daml           # Main contract
│   └── daml.yaml                   # Project config
├── dars/
│   └── RWA.dar                     # Compiled contract
├── config/
│   ├── canton-single-participant.conf  # Canton config
│   └── scripts/
│       ├── setup-rwa-platform.canton  # Setup script
│       ├── test-rwa-complete.canton   # Test script
│       └── New.txt                     # Complete command log
└── RWA-PLATFORM-README.md         # This file
```

## 🔧 Development

### Building the Contract

```bash
cd daml/RWA
daml build
cp .daml/dist/RWA-1.0.0.dar ../../dars/RWA.dar
```

### Production Deployment

1. Configure PostgreSQL database
2. Update `canton-single-participant.conf` with production settings
3. Deploy with proper TLS and authentication
4. Set up monitoring and logging

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test thoroughly with Canton console
4. Update documentation
5. Submit pull request

## 📄 License

This RWA platform is provided as-is for educational and development purposes.

---

**🎉 Platform Status**: Production Ready ✅

The RWA platform has been thoroughly tested and is ready for production deployment with proper security configurations.