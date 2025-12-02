# 🚀 Brens Protocol Deployments

## Base Sepolia Testnet

**Network**: Base Sepolia  
**Chain ID**: 84532  
**RPC URL**: https://sepolia.base.org  
**Explorer**: https://sepolia.basescan.org  
**Deployment Date**: December 2, 2025

### Contract Addresses

| Contract | Address | Status | Explorer |
|----------|---------|--------|----------|
| TPTRegistry | `0x61A3CE93923Cce39Aa2d77E18199C65F5496238F` | ✅ Verified | [View](https://sepolia.basescan.org/address/0x61a3ce93923cce39aa2d77e18199c65f5496238f) |
| TPTFactory | `0x61A4011769CAA686F7beE90c4B69F6dfa1971Ab3` | ✅ Verified | [View](https://sepolia.basescan.org/address/0x61a4011769caa686f7bee90c4b69f6dfa1971ab3) |

### Configuration

- **Deployer**: `0xEC891A037F932493624184970a283ab87398e0A6`
- **Factory Owner**: `0xEC891A037F932493624184970a283ab87398e0A6`
- **Launch Fee**: 0 ETH
- **Solidity Version**: 0.8.30
- **Optimizer**: Enabled (200 runs)
- **TPT Decimals**: 6 (USDC-style)

### Deployment Transactions

```bash
# Registry Deployment
TX: 0xd637d9a3a04a9c7a75c154f4ee93a4821dba59b3cb892646f0502f519cd76a09
Gas Used: 807,605
Block: 34451118

# Factory Deployment  
TX: 0x17d9d7f517739f857c6c07c1f4c641b9723fa637de6b7b104ce69bc38802fd11
Gas Used: 3,029,101
Block: 34451118

# Ownership Transfer
TX: 0x5bd811d24735050d4deef0373d40c0b50c04837b309c437b4093621ce80a84bf
Gas Used: 27,051
Block: 34451118
```

### Usage

#### Create a TPT

```bash
# Set environment variables
export FACTORY_ADDRESS=0x61A4011769CAA686F7beE90c4B69F6dfa1971Ab3
export RPC_URL=https://sepolia.base.org
export PRIVATE_KEY=your_private_key

# Create a sample TPT
forge script script/DeployTPTFactory.s.sol:CreateSampleTPT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --legacy
```

#### Interact with Factory

```solidity
// In your contract or script
TPTFactory factory = TPTFactory(0x61A4011769CAA686F7beE90c4B69F6dfa1971Ab3);

// Create a new TPT
address tptAddress = factory.createTPT{value: 0}(
    "Private USD Coin",
    "pUSDC",
    1_000_000, // 1M tokens with 6 decimals
    keccak256("my-unique-salt")
);
```

---

## Fhenix Helium Testnet (Coming Soon)

**Network**: Fhenix Helium  
**Chain ID**: TBD  
**RPC URL**: https://api.helium.fhenix.zone  
**Deployment Date**: Pending

This will be the primary deployment for full FHE functionality.

### Why Fhenix?
- Full FHE support with CoFHE precompiles
- Encrypted operations on-chain
- True privacy-preserving token transfers
- Compatible with FHERC20 standard

---

## Contract ABI & Integration

### TPTFactory ABI

Key functions for integration:

```solidity
interface ITPTFactory {
    function createTPT(
        string memory name,
        string memory symbol,
        uint64 initialSupply,
        bytes32 salt
    ) external payable returns (address);
    
    function computeTPTAddress(
        string memory name,
        string memory symbol,
        uint64 initialSupply,
        address creator,
        bytes32 salt
    ) external view returns (address);
    
    function launchFee() external view returns (uint256);
    
    function REGISTRY() external view returns (address);
}
```

### TPTRegistry ABI

```solidity
interface ITPTRegistry {
    struct TPTMetadata {
        address tokenAddress;
        address creator;
        string name;
        string symbol;
        uint64 initialSupply;
        uint256 createdAt;
        bool isVerified;
    }
    
    function getTPTMetadata(address tptAddress) 
        external view returns (TPTMetadata memory);
    
    function getCreatorTPTs(address creator) 
        external view returns (address[] memory);
    
    function getTotalTPTs() external view returns (uint256);
    
    function isTPT(address tokenAddress) external view returns (bool);
}
```

---

## Frontend Integration Guide

### 1. Connect to Factory

```typescript
import { createPublicClient, http } from 'viem';
import { baseSepolia } from 'viem/chains';

const client = createPublicClient({
  chain: baseSepolia,
  transport: http()
});

const FACTORY_ADDRESS = '0x61A4011769CAA686F7beE90c4B69F6dfa1971Ab3';
```

### 2. Create a TPT

```typescript
import { parseAbi } from 'viem';

const factoryAbi = parseAbi([
  'function createTPT(string,string,uint64,bytes32) payable returns (address)',
  'function launchFee() view returns (uint256)'
]);

// Get current launch fee
const fee = await client.readContract({
  address: FACTORY_ADDRESS,
  abi: factoryAbi,
  functionName: 'launchFee'
});

// Create TPT
const hash = await walletClient.writeContract({
  address: FACTORY_ADDRESS,
  abi: factoryAbi,
  functionName: 'createTPT',
  args: ['Private Token', 'pTKN', 1000000n, saltBytes],
  value: fee
});
```

### 3. Query Registry

```typescript
const registryAbi = parseAbi([
  'function getTotalTPTs() view returns (uint256)',
  'function getTPTMetadata(address) view returns (tuple)',
  'function getCreatorTPTs(address) view returns (address[])'
]);

const REGISTRY_ADDRESS = '0x61A3CE93923Cce39Aa2d77E18199C65F5496238F';

// Get total TPTs
const total = await client.readContract({
  address: REGISTRY_ADDRESS,
  abi: registryAbi,
  functionName: 'getTotalTPTs'
});

// Get user's TPTs
const userTPTs = await client.readContract({
  address: REGISTRY_ADDRESS,
  abi: registryAbi,
  functionName: 'getCreatorTPTs',
  args: [userAddress]
});
```

---

## Security & Auditing

### Contract Verification Status
- ✅ TPTRegistry: Verified on BaseScan
- ✅ TPTFactory: Verified on BaseScan
- ⏳ Security Audit: Pending
- ⏳ Formal Verification: Planned

### Known Considerations
1. **Immutable Contracts**: No upgrade mechanism by design
2. **Registry Ownership**: Owned by factory contract
3. **Launch Fee**: Currently set to 0 ETH (configurable by owner)
4. **CREATE2 Predictability**: Addresses are deterministic with salt

---

## Monitoring & Support

### Block Explorers
- Base Sepolia: https://sepolia.basescan.org
- Fhenix (upcoming): https://explorer.fhenix.zone

### Contract Events

```solidity
// TPTFactory Events
event TPTCreated(address indexed tokenAddress, address indexed creator, bytes32 salt);
event LaunchFeeUpdated(uint256 newFee);

// TPTRegistry Events
event TPTRegistered(address indexed tokenAddress, address indexed creator);
event TPTVerified(address indexed tokenAddress);
```

Monitor these events for TPT creation and registry updates.

---

**Last Updated**: December 2, 2025  
**Status**: Active on Base Sepolia Testnet
