# Brens Protocol - Smart Contracts

## Overview

This repository contains the core smart contracts for **Brens Protocol**, implementing the **Tradeable Private Token (TPT)** standard using Fully Homomorphic Encryption (FHE).

## Architecture

### Core Contracts

#### 1. **FHERC20.sol** - The TPT Standard
The base implementation of Tradeable Private Tokens with the following features:

- **Encrypted Balances**: Uses `euint128` (Encrypted Uint128) for all balance storage
- **Zero-Replacement Logic**: Failed transfers don't revert - they transfer 0 instead (prevents balance disclosure)
- **Encrypted Transfers**: `transferEncrypted()` and `transferFromEncrypted()` functions
- **Encrypted Allowances**: `approveEncrypted()` for spending permissions
- **View Key System**: Selective disclosure for compliance and auditing
- **Indicated Balances**: Optional range-based balance display for UX

#### 2. **TPTFactory.sol** - Token Launcher
Factory contract for deploying TPTs with CREATE2:

- **Deterministic Deployment**: Uses CREATE2 for predictable token addresses
- **TPT Registry**: Maintains metadata and registry of all deployed TPTs
- **Launch Fees**: Configurable fee mechanism for token creation
- **Batch Creation**: Deploy multiple TPTs in a single transaction
- **Verification System**: Admin verification for trusted tokens
- **Creator Tracking**: Track all tokens created by each address

#### 3. **IFHERC20.sol** - TPT Interface
Standard interface for all TPT implementations.

## Key Features

### Privacy by Design
```solidity
// Balances are encrypted - never visible on-chain
mapping(address => euint128) internal _encBalances;

// Zero-replacement prevents balance disclosure
euint128 amountToSend = FHE.select(
    amount.lte(senderBalance),
    amount,
    FHE.asEuint128(0)
);
```

### Selective Disclosure (Compliance)
```solidity
// Grant view access to auditors/regulators
function grantViewKey(address viewer) public;

// Revoke access
function revokeViewKey(address viewer) public;

// View balance with authorization
function viewBalanceWithKey(address account, Permission memory permission) 
    public view returns (string memory);
```

### Deterministic Deployment (CREATE2)
```solidity
// Compute address before deployment
address predictedAddress = factory.computeTPTAddress(
    name,
    symbol,
    initialSupply,
    creator,
    salt
);

// Deploy with CREATE2
address tptAddress = factory.createTPT{value: factory.launchFee()}(
    name,
    symbol,
    initialSupply,
    salt
);
```

## Deployment

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
```

### Deploy to Fhenix Testnet

1. **Set environment variables**:
```bash
export PRIVATE_KEY=your_private_key
export RPC_URL=https://api.helium.fhenix.zone
```

2. **Deploy the Factory**:
```bash
forge script script/DeployTPTFactory.s.sol:DeployTPTFactory \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

3. **Create a sample TPT**:
```bash
export FACTORY_ADDRESS=deployed_factory_address

forge script script/DeployTPTFactory.s.sol:CreateSampleTPT \
    --rpc-url $RPC_URL \
    --broadcast
```

## Usage Examples

### Creating a TPT

```solidity
// Deploy factory
TPTFactory factory = new TPTFactory();

// Create a private stablecoin
address tptAddress = factory.createTPT{value: 0.01 ether}(
    "Private USD Coin",
    "pUSDC",
    1_000_000 * 10**18,  // 1M initial supply
    keccak256("my-salt")
);

FHERC20 pUSDC = FHERC20(tptAddress);
```

### Using a TPT

```solidity
// Transfer encrypted amount
inEuint128 memory encryptedAmount = FHE.asEuint128(100 * 10**18);
pUSDC.transferEncrypted(recipient, encryptedAmount);

// Approve encrypted spending
pUSDC.approveEncrypted(spender, encryptedAmount);

// Grant view key for compliance
pUSDC.grantViewKey(auditorAddress);
```

### Viewing Encrypted Balances

```solidity
// User generates permission with their public key
Permission memory permission = Permission({
    publicKey: userPublicKey,
    signature: userSignature
});

// Get sealed (encrypted) balance
string memory sealedBalance = pUSDC.balanceOfEncrypted(
    userAddress,
    permission
);

// User decrypts on client side with private key
```

## Development

### Build

```bash
forge build
```

### Test

```bash
# Note: FHE tests require Fhenix runtime
forge test --gas-report
```

### Format

```bash
forge fmt
```

### Project Structure
```
brens-protocol/
├── src/
│   ├── FHERC20.sol          # TPT implementation
│   ├── TPTFactory.sol       # Factory with CREATE2
│   └── IFHERC20.sol         # TPT interface
├── script/
│   └── DeployTPTFactory.s.sol  # Deployment scripts
├── test/
│   └── TPTFactory.t.sol     # Test suite
├── lib/
│   ├── forge-std/           # Foundry standard library
│   ├── fhenix-contracts/    # FHE operations library
│   └── v4-periphery/        # Uniswap v4 (StealthPoolHook - FHE integration planned)
└── foundry.toml             # Foundry configuration
```

## Security Considerations

### FHE Security
- **Mathematical Privacy**: Based on Learning With Errors (LWE) problem hardness
- **No Hardware Trust**: Unlike TEEs, no trusted hardware required
- **Ciphertext Arithmetic**: All operations on encrypted values

### Smart Contract Security
- **Zero-Replacement Logic**: Prevents balance disclosure through reverts
- **No Public Balance Exposure**: All balances encrypted at rest
- **View Key Management**: Explicit authorization required for balance viewing
- **CREATE2 Safety**: Deterministic deployment with salt uniqueness check

## Resources

- [Brens Protocol Whitepaper](https://docs.google.com/document/d/e/2PACX-1vQMHNT-OZZK3LXuJw_uXoXHWn-kQD8_UvvUIyk69qyuE2DW7z7Zkvn9U-yCETePuYNnjIy2wKi5hWD1/pub)
- [Fhenix Documentation](https://docs.fhenix.zone)
- [Foundry Book](https://book.getfoundry.sh/)

## License

MIT
