# OpenPatron

A fully decentralized, censorship-resistant membership platform built on the Internet Computer.

## Overview

OpenPatron is a production-grade example from the "Mastering Motoko" book that demonstrates advanced patterns for building decentralized applications on the Internet Computer Protocol (ICP).

## Features

### ✅ Identity & Access Control (Chapter 5)
- **Internet Identity Integration**: Cryptographically authenticated users
- **Role-Based Access Control**: Patron, Creator, and Admin roles
- **Profile Management**: User registration, profiles, and updates
- **Privacy-Preserving**: Principal-based identity without tracking

### ✅ Tokenomics & Ledger Integration (Chapter 6)
- **ICRC-1 Token Standard**: Compatible with ICP ledger
- **Deposit Pattern**: Secure subaccount-based deposits
- **Virtual Accounting**: Efficient internal balance management
- **Withdrawals**: Safe, reentrancy-protected transfers
- **Platform Fees**: Configurable revenue model

### ✅ Autonomous Subscriptions (Chapter 7)
- **Recurring Payments**: Automated subscription billing
- **Timer-Based Processing**: Self-executing payment cycles
- **Subscription Management**: Create, cancel, and track subscriptions
- **Cadence Flexibility**: Daily, weekly, monthly, or custom intervals

### ✅ Asynchronous Safety (Chapter 8)
- **Reentrancy Protection**: Optimistic accounting pattern
- **State Consistency**: Safe inter-canister calls
- **Rollback on Failure**: Automatic refunds on transfer errors

### ✅ Cycle Management (Chapter 12)
- **Self-Sustaining**: Platform fees fund canister operations
- **Health Monitoring**: Cycle balance tracking
- **Upgrade Safety**: Stable variables for state persistence

### ✅ Comprehensive Logging
- **Event Tracking**: All critical operations logged
- **Debugging**: Query logs for troubleshooting
- **Audit Trail**: Immutable operation history

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  OpenPatron                     │
├─────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │       Identity & Access Control          │  │
│  │   - User Registration                    │  │
│  │   - Profile Management                   │  │
│  │   - Role-Based Permissions               │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │       Tokenomics & Payments              │  │
│  │   - ICRC-1 Ledger Integration            │  │
│  │   - Deposit/Withdrawal                   │  │
│  │   - Virtual Accounting                   │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │       Subscription Engine                │  │
│  │   - Recurring Billing                    │  │
│  │   - Timer-Based Processing               │  │
│  │   - Subscription Lifecycle               │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │       Platform Economics                 │  │
│  │   - Platform Fees                        │  │
│  │   - Treasury Management                  │  │
│  │   - Cycle Management                     │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
              ▲                    ▲
              │                    │
         ┌────┴────┐          ┌───┴────┐
         │ ICRC-1  │          │ Users  │
         │ Ledger  │          │Frontend│
         └─────────┘          └────────┘
```

## Installation

### Prerequisites

- [DFX](https://internetcomputer.org/docs/current/developer-docs/setup/install) (Internet Computer SDK)
- [Node.js](https://nodejs.org/) (for frontend integration)
- [Mops](https://mops.one/) (Motoko package manager)

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd OpenPatron

# Install Mops (if not already installed)
npm install -g ic-mops

# Install dependencies
mops install

# Start local replica
dfx start --clean --background

# Deploy canister
dfx deploy openpatron

# Check canister status
dfx canister status openpatron
```

## Usage

### User Registration

```bash
# Register a new user
dfx canister call openpatron register '("alice", opt "Content creator")'

# Get your profile
dfx canister call openpatron getProfile
```

### Deposits & Withdrawals

```bash
# Get deposit address
dfx canister call openpatron getDepositAddress

# Notify after depositing tokens
dfx canister call openpatron notifyDeposit '(1_000_000 : nat)'

# Check balance
dfx canister call openpatron getBalance '(principal "your-principal-id")'

# Withdraw tokens
dfx canister call openpatron withdraw '(500_000 : nat)'
```

### Subscriptions

```bash
# Subscribe to a creator (10 tokens, monthly)
dfx canister call openpatron subscribe '(
  principal "creator-principal",
  10_000_000 : nat,
  2_592_000_000_000_000 : int
)'

# View subscription
dfx canister call openpatron getSubscription '(0 : nat32)'

# Cancel subscription
dfx canister call openpatron cancelSubscription '(0 : nat32)'

# Get all active subscriptions
dfx canister call openpatron getActiveSubscriptions
```

### Platform Monitoring

```bash
# Check platform stats
dfx canister call openpatron getStats

# Check cycle balance and health
dfx canister call openpatron checkHealth

# View recent logs
dfx canister call openpatron getLogs '(10 : nat)'
```

## Project Structure

```
OpenPatron/
├── main.mo           # Main actor implementation
├── types.mo          # Centralized type definitions
├── README.md         # This file
├── dfx.json          # DFX configuration
└── test/             # Test files (optional)
```

## Key Concepts

### Virtual Accounting

OpenPatron uses an efficient internal accounting system:
- Users deposit tokens once into the platform
- Subscription payments happen instantly within the canister
- Creators withdraw accumulated earnings when needed
- This approach minimizes expensive ledger calls

### Timer-Based Automation

Unlike Ethereum's keeper pattern, OpenPatron is fully autonomous:
- A recurring timer checks subscriptions daily
- Payments are processed automatically
- No external infrastructure required
- True "set it and forget it" automation

### Optimistic Accounting Pattern

To prevent reentrancy attacks:
1. **Check** - Verify sufficient balance
2. **Update** - Modify state immediately
3. **Interact** - Make external calls
4. **Rollback** - Refund on failure

This ensures state consistency even during async operations.

## Security Considerations

- ✅ Reentrancy protection via optimistic accounting
- ✅ Role-based access control
- ✅ Anonymous caller rejection
- ✅ Input validation on all public methods
- ✅ Secure subaccount derivation
- ✅ Cycle balance monitoring

## Testing

```bash
# Unit tests (if implemented)
mops test

# Integration tests with PocketIC (Python)
pytest tests/

# Manual testing via DFX
dfx canister call openpatron <method> '<args>'
```

## Deployment to Mainnet

```bash
# Create cycles wallet
dfx wallet --network ic create --icp 10

# Deploy to mainnet with cycles
dfx deploy --network ic openpatron --with-cycles 3000000000000

# Verify deployment
dfx canister --network ic status openpatron

# Get canister URL
echo "https://$(dfx canister --network ic id openpatron).ic0.app"
```

## Cost Estimates

### Monthly Operating Costs (approximation)

- **1,000 users**: ~$1/month
- **50,000 users**: ~$49/month
- **1,000,000 users**: ~$978/month

The reverse gas model means users interact for free, while the platform covers computational costs through subscription fees.

## Governance & Decentralization

For production deployment, consider:
- **Black Holing**: Make code immutable (irreversible)
- **SNS (Service Nervous System)**: Transfer control to a DAO
- **Multi-Sig**: Require multiple approvers for upgrades

See Chapter 13 in "Mastering Motoko" for SNS integration.

## Book Reference

This implementation is the complete example from **"Mastering Motoko: Building Production-Grade Decentralized Applications on the Internet Computer"**.

Chapters covered:
- **Chapter 5**: Identity and Access Control
- **Chapter 6**: Tokenomics and Ledger Integration
- **Chapter 7**: Autonomous Subscriptions via Timers
- **Chapter 8**: Asynchronous Safety and Reentrancy
- **Chapter 9**: External Integrations
- **Chapter 10**: Frontend Integration & Asset Storage
- **Chapter 11**: Ecosystem Tools and Testing
- **Chapter 12**: The Economics of Deployment
- **Chapter 13**: The Service Nervous System (SNS)

## License

This code is provided as educational material from the "Mastering Motoko" book.

## Contributing

This is a reference implementation from the book. For production use, consider:
- Comprehensive test coverage
- Security audits
- Load testing
- Monitoring infrastructure
- Gradual rollout strategy

## Support

For questions about this implementation:
- Read the full "Mastering Motoko" book
- Visit the [Internet Computer Developer Forum](https://forum.dfinity.org/)

---

**⚠️ Educational Code**: This is a learning example. For production deployment, ensure proper testing, auditing, and security reviews.

