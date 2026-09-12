# Ethereum Asset Manager

A comprehensive DeFi asset management system with multi-asset support, lending/borrowing capabilities, and accessibility features.

## 🎯 Use Cases

### 1. **Multi-Asset Portfolio Management**
- Track and manage multiple ERC-20 tokens and native ETH
- Real-time balance monitoring
- Automated asset allocation

### 2. **Lending & Borrowing**
- Deposit assets to earn interest
- Borrow against collateral
- Dynamic interest rate calculations

### 3. **Asset Transfers**
- Send any supported token to addresses
- Batch transfers for efficiency
- Transaction history tracking

### 4. **Accessibility Features**
- Real-time asset details display
- Portfolio health monitoring
- Risk assessment and alerts
- Historical transaction logs

## 📋 System Architecture

```
AssetManager (Main Contract)
├── Asset Registry (ERC-20 tokens)
├── User Portfolios (balances & deposits)
├── Lending Pool (interest calculations)
├── Risk Management (collateral ratios)
└── Access Control (permissions)
```

## 🚀 Quick Start

### Prerequisites
```bash
Node.js >= 16
npm or yarn
Hardhat
```

### Installation
```bash
git clone https://github.com/Gold3310/ethereum-asset-manager.git
cd ethereum-asset-manager
npm install
```

### Configuration
```bash
cp .env.example .env
# Edit .env with your keys
```

### Deploy
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Run Tests
```bash
npx hardhat test
```

## 📊 Key Features

### Asset Management
- ✅ Add/remove supported assets
- ✅ Track multiple token types
- ✅ Real-time price feeds
- ✅ Portfolio diversification

### Lending Protocol
- ✅ Deposit assets for interest
- ✅ Borrow with collateral
- ✅ Flexible interest rates
- ✅ Liquidation mechanisms

### User Experience
- ✅ Simple transfer interface
- ✅ Batch operations
- ✅ Transaction history
- ✅ Portfolio analytics

### Security
- ✅ Access control (RBAC)
- ✅ Reentrancy guards
- ✅ Input validation
- ✅ Emergency pause function

### Accessibility
- ✅ Asset details display
- ✅ Balance queries
- ✅ Transaction logs
- ✅ Portfolio reports

## 📖 Documentation

- [Smart Contracts Guide](./docs/CONTRACTS.md)
- [Interaction Guide](./docs/INTERACTION.md)
- [API Reference](./docs/API.md)
- [Testing Guide](./docs/TESTING.md)

## 🔐 Security

- All contracts are non-audited educational examples
- Use with caution on mainnet
- Test thoroughly on testnet first
- Never expose private keys

## 📄 License

MIT

---

**Created for**: Educational DeFi Development
**Network**: Ethereum (Mainnet, Sepolia, Goerli)
**Status**: Active Development