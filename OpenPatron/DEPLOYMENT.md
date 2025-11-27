# OpenPatron Deployment Guide

This guide walks through deploying OpenPatron to the Internet Computer mainnet.

## Prerequisites

Before deploying, ensure you have:

- ✅ DFX CLI installed (version 0.15.0 or later)
- ✅ ICP tokens for cycle conversion
- ✅ All tests passing
- ✅ Code audited (for production)

## Step 1: Prepare for Deployment

### 1.1 Test Locally

```bash
# Start local replica
dfx start --clean --background

# Deploy locally
dfx deploy openpatron

# Run integration tests
dfx canister call openpatron register '("test_user", opt "Testing")'
dfx canister call openpatron getProfile
dfx canister call openpatron getStats

# Stop local replica
dfx stop
```

### 1.2 Review Configuration

Check `dfx.json` and `mops.toml` for correct settings:

```json
{
  "canisters": {
    "openpatron": {
      "type": "motoko",
      "main": "main.mo"
    }
  }
}
```

### 1.3 Update Ledger Integration

In `main.mo`, update the ledger canister ID:

```motoko
// Replace with actual ICRC-1 ledger canister ID
private let ledgerId = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
```

Common ICRC-1 ledgers on mainnet:
- **ICP Ledger**: `ryjl3-tyaaa-aaaaa-aaaba-cai`
- **ckBTC Ledger**: `mxzaz-hqaaa-aaaar-qaada-cai`
- **ckETH Ledger**: (check latest from DFINITY)

## Step 2: Create Cycles Wallet

### 2.1 Check Current Identity

```bash
# View your current identity
dfx identity whoami

# View your principal ID
dfx identity get-principal

# Create new identity for production (optional)
dfx identity new production
dfx identity use production
```

### 2.2 Convert ICP to Cycles

```bash
# Check ICP balance (requires NNS dapp or command line setup)
dfx ledger balance

# Create cycles wallet (requires ICP)
# This creates a cycles wallet with 10 ICP worth of cycles
dfx wallet --network ic create --icp 10

# Check wallet balance
dfx wallet --network ic balance
```

Expected output:
```
10.0 TC (trillion cycles)
```

> **Note**: 10 ICP ≈ 10 Trillion Cycles ≈ $13 USD (at current rates)

## Step 3: Deploy to Mainnet

### 3.1 Build and Deploy

```bash
# Install dependencies
mops install

# Deploy to mainnet with initial cycles
dfx deploy --network ic openpatron --with-cycles 3000000000000

# Expected output:
# Deploying: openpatron
# Creating canister openpatron...
# Installing code for canister openpatron...
# Deployed canisters.
# URLs:
#   openpatron: https://xxxxx-xxxxx-xxxxx-xxxxx-cai.ic0.app
```

### 3.2 Verify Deployment

```bash
# Check canister status
dfx canister --network ic status openpatron

# Expected output:
# Canister status: Running
# Controllers: <your-principal-id>
# Memory allocation: 0
# Memory size: ...
# Cycles: 3_000_000_000_000
# Module hash: 0x...
```

### 3.3 Get Canister Information

```bash
# Get canister ID
CANISTER_ID=$(dfx canister --network ic id openpatron)
echo "Canister ID: $CANISTER_ID"

# Get canister URL
echo "Frontend URL: https://$CANISTER_ID.ic0.app"
echo "Candid UI: https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.ic0.app/?id=$CANISTER_ID"
```

## Step 4: Initial Configuration

### 4.1 Register Admin Account

```bash
# Register yourself as first user
dfx canister --network ic call openpatron register '("admin", opt "Platform Administrator")'

# Assign admin role
YOUR_PRINCIPAL=$(dfx identity get-principal)
dfx canister --network ic call openpatron assignRole "(
  principal \"$YOUR_PRINCIPAL\",
  variant { Admin }
)"
```

### 4.2 Top Up with Initial Cycles

```bash
# Add more cycles from your wallet
dfx canister --network ic deposit-cycles 2000000000000 openpatron

# Verify cycle balance
dfx canister --network ic call openpatron getCycleBalance
```

### 4.3 Check Health

```bash
# Run health check
dfx canister --network ic call openpatron checkHealth

# View platform stats
dfx canister --network ic call openpatron getStats
```

## Step 5: Set Up Monitoring

### 5.1 Create Monitoring Script

Create `scripts/monitor.sh`:

```bash
#!/bin/bash
CANISTER_ID="your-canister-id"
NETWORK="ic"

echo "=== OpenPatron Health Check ==="
echo ""

# Cycle balance
echo "Cycle Balance:"
dfx canister --network $NETWORK call $CANISTER_ID getCycleBalance

# Health status
echo ""
echo "Health Status:"
dfx canister --network $NETWORK call $CANISTER_ID checkHealth

# Platform stats
echo ""
echo "Platform Stats:"
dfx canister --network $NETWORK call $CANISTER_ID getStats

# Canister status
echo ""
echo "Canister Status:"
dfx canister --network $NETWORK status $CANISTER_ID
```

```bash
chmod +x scripts/monitor.sh
./scripts/monitor.sh
```

### 5.2 Set Up Cycle Alert

Create a cron job to check cycles daily:

```bash
# Add to crontab (crontab -e)
0 9 * * * /path/to/scripts/monitor.sh | mail -s "OpenPatron Daily Report" your@email.com
```

## Step 6: Security Configuration

### 6.1 Review Controllers

```bash
# List current controllers
dfx canister --network ic info openpatron

# Add additional controller (for backup)
dfx canister --network ic update-settings openpatron \
  --add-controller <backup-principal-id>
```

### 6.2 Set Freezing Threshold

```bash
# Set freezing threshold (seconds of operation before freeze)
dfx canister --network ic update-settings openpatron \
  --freezing-threshold 7776000  # 90 days in seconds
```

## Step 7: Post-Deployment Checklist

- [ ] Canister deployed and running
- [ ] Initial cycles funded (3T+)
- [ ] Admin account registered
- [ ] Health checks passing
- [ ] Monitoring script configured
- [ ] Controllers configured
- [ ] Freezing threshold set
- [ ] Ledger integration verified
- [ ] Documentation updated with canister ID
- [ ] Team notified of deployment

## Step 8: Ongoing Maintenance

### Daily Tasks
- Check cycle balance
- Review logs for errors
- Monitor active subscriptions

### Weekly Tasks
- Review platform stats
- Check for necessary upgrades
- Analyze usage patterns

### Monthly Tasks
- Security review
- Performance optimization
- Feature planning

## Upgrading the Canister

When you need to deploy updates:

```bash
# Make changes to code

# Test locally first
dfx start --clean --background
dfx deploy openpatron
# Test changes...
dfx stop

# Deploy upgrade to mainnet
dfx deploy --network ic openpatron --mode upgrade

# Verify upgrade
dfx canister --network ic call openpatron getStats
dfx canister --network ic call openpatron getLogs '(10 : nat)'
```

## Emergency Procedures

### If Canister Runs Out of Cycles

```bash
# Top up immediately
dfx canister --network ic deposit-cycles 5000000000000 openpatron

# Check if canister is frozen
dfx canister --network ic status openpatron

# If frozen, it will restart after top-up
```

### If Canister Traps

```bash
# Check logs
dfx canister --network ic call openpatron getLogs '(50 : nat)'

# If needed, upgrade with fix
dfx deploy --network ic openpatron --mode upgrade
```

## Cost Monitoring

Track your monthly costs:

```bash
# Current cycle balance
CURRENT=$(dfx canister --network ic call openpatron getCycleBalance | grep -o '[0-9]*')

# Calculate daily burn rate
# Run this daily and compare
echo "Cycles remaining: $CURRENT"
echo "Estimated days remaining: $((CURRENT / 100000000000))"  # Assuming 100B/day burn
```

## Advanced: DAO Governance (Chapter 13)

Once your platform is mature, consider transitioning to DAO governance:

```bash
# Install SNS tools
dfx extension install sns

# Initialize SNS configuration
dfx sns init

# Deploy SNS (testnet first)
dfx sns deploy --network ic --testnet

# See Chapter 13 for full SNS integration
```

## Troubleshooting

### Problem: Deployment Fails

```bash
# Check network connectivity
dfx ping ic

# Verify wallet has cycles
dfx wallet --network ic balance

# Try with explicit wallet
dfx deploy --network ic openpatron --wallet <wallet-canister-id>
```

### Problem: "Out of Cycles" Error

```bash
# Immediately top up
dfx wallet --network ic send <canister-id> 3000000000000
```

### Problem: Upgrade Fails

```bash
# Check stable variables are properly configured
# Ensure preupgrade/postupgrade hooks are correct

# Deploy in upgrade mode with verbose output
dfx deploy --network ic openpatron --mode upgrade -vv
```

## Resources

- [Internet Computer Documentation](https://internetcomputer.org/docs/)
- [DFX Command Reference](https://internetcomputer.org/docs/current/developer-docs/setup/install/)
- [Cycles Management](https://internetcomputer.org/docs/current/developer-docs/production/cycles/)
- [Canister Upgrades](https://internetcomputer.org/docs/current/developer-docs/production/upgrade-canisters/)

---

**Last Updated**: 2025
**OpenPatron Version**: 1.0.0


