# StealthPoolHook Unichain Deployment Guide

## About Unichain

Unichain is Uniswap's native Layer 2 chain, optimized for DeFi with:
- **Native Uniswap v4 support** with the best liquidity
- **1 second block times** for fast transactions
- **MEV protection** with Flashblocks
- **Low fees** optimized for trading

## Prerequisites

### 1. Get Unichain Sepolia ETH

**Option A: Bridge from Sepolia**
- Bridge Sepolia ETH to Unichain Sepolia via the official bridge
- Bridge: https://bridge.unichain.org

**Option B: Faucet** (if available)
- Check Unichain documentation for testnet faucets
- https://docs.unichain.org

### 2. Setup Environment

```bash
cp .env.example .env
```

Add to your `.env`:
```bash
PRIVATE_KEY=your_private_key_without_0x
UNICHAIN_SEPOLIA_RPC_URL=https://sepolia.unichain.org
UNISCAN_API_KEY=your_api_key  # Optional, for verification
```

### 3. Verify RPC Connection

```bash
cast block latest --rpc-url https://sepolia.unichain.org
```

## Deployment Steps

### Step 1: Deploy StealthPoolHook

This process uses HookMiner to find a valid address with the required hook permissions. **It takes 5-15 minutes** as it searches for a matching salt.

```bash
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url unichain_sepolia \
  --broadcast \
  --verify \
  -vvvv
```

**Expected Output:**
```
Deployer: 0x...
Chain ID: 1301
PoolManager: 0xC81462Fec8B23319F288047f8A03A57682a35C1A
Required hook flags: ...
Mining for hook address...
This may take a while...
Found valid hook address: 0x...
Salt: 0x...
StealthPoolHook deployed at: 0x...
Owner: 0x...
```

**Important:** Save these values!
```bash
export HOOK_ADDRESS=0x...  # Your deployed hook address
```

### Step 2: Configure Hook (Optional)

Set a keeper address for rebalancing operations:

```bash
export KEEPER_ADDRESS=0x...  # Can be your address initially

forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vvvv
```

### Step 3: Deploy or Get Test Tokens

You need two ERC20 tokens where `token0 < token1` (sorted by address).

**Option A: Deploy Simple Test Tokens**

Create `script/DeployTestTokens.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol, 18) 
    {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract DeployTestTokens is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(privateKey);
        
        TestToken tokenA = new TestToken("Test Token A", "TTA");
        TestToken tokenB = new TestToken("Test Token B", "TTB");
        
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        
        // Sort addresses
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        console.log("\nSorted:");
        console.log("TOKEN0:", token0);
        console.log("TOKEN1:", token1);
        
        vm.stopBroadcast();
    }
}
```

Deploy:
```bash
forge script script/DeployTestTokens.s.sol:DeployTestTokens \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vvvv
```

Save the addresses:
```bash
export TOKEN0_ADDRESS=0x...  # Lower address
export TOKEN1_ADDRESS=0x...  # Higher address
```

### Step 4: Initialize Pool

```bash
forge script script/InitializeStealthPool.s.sol:InitializeStealthPool \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vvvv
```

**Expected Output:**
```
Pool initialized successfully!
Pool ID: 0x...
Public Reserve0: 1000000000000000000000000
Public Reserve1: 1000000000000000000000000
(Note: Public reserves are dummy values for privacy)
```

### Step 5: Approve Tokens

Approve the PoolManager to spend your tokens:

```bash
POOL_MANAGER=0xC81462Fec8B23319F288047f8A03A57682a35C1A

# Approve token0
cast send $TOKEN0_ADDRESS \
  "approve(address,uint256)" \
  $POOL_MANAGER \
  1000000000000000000000 \
  --rpc-url unichain_sepolia \
  --private-key $PRIVATE_KEY

# Approve token1
cast send $TOKEN1_ADDRESS \
  "approve(address,uint256)" \
  $POOL_MANAGER \
  1000000000000000000000 \
  --rpc-url unichain_sepolia \
  --private-key $PRIVATE_KEY
```

### Step 6: Add Liquidity

```bash
export LIQUIDITY_AMOUNT=1000000000000000000  # 1 token

forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vvvv
```

## Verification

### Check Deployment

```bash
# Check owner
cast call $HOOK_ADDRESS "owner()(address)" --rpc-url unichain_sepolia

# Check keeper
cast call $HOOK_ADDRESS "keeper()(address)" --rpc-url unichain_sepolia

# Check swap fee (should be 10 basis points = 0.1%)
cast call $HOOK_ADDRESS "SWAP_FEE_BASIS_POINTS()(uint256)" --rpc-url unichain_sepolia

# Check protocol fee share (should be 1000 = 10%)
cast call $HOOK_ADDRESS "PROTOCOL_FEE_SHARE()(uint256)" --rpc-url unichain_sepolia
```

### Verify Privacy (Public Reserves are Dummy)

```bash
# Should return 1,000,000 tokens for both reserves (dummy values)
cast call $HOOK_ADDRESS \
  "getPublicReserves((address,address,uint24,int24,address))(uint256,uint256)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url unichain_sepolia
```

Expected: `1000000000000000000000000, 1000000000000000000000000`

### Check Your Claim Tokens

```bash
POOL_MANAGER=0xC81462Fec8B23319F288047f8A03A57682a35C1A
YOUR_ADDRESS=0x...

# Get currency ID for token0
cast call $TOKEN0_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url unichain_sepolia

# Check claim balance (ERC-6909 tokens in PoolManager)
cast call $POOL_MANAGER \
  "balanceOf(address,uint256)(uint256)" \
  $YOUR_ADDRESS \
  $(cast to-uint256 $TOKEN0_ADDRESS) \
  --rpc-url unichain_sepolia
```

## Testing Swaps

You can test swaps using the Uniswap v4 Router or create a custom swap script.

### Quick Swap Test (via cast)

```bash
# This requires understanding Uniswap v4's swap interface
# For full testing, use the Uniswap v4 Router contract
```

## Network Information

### Unichain Sepolia (Testnet)
- **Chain ID**: 1301
- **RPC URL**: https://sepolia.unichain.org
- **PoolManager**: `0xC81462Fec8B23319F288047f8A03A57682a35C1A`
- **Block Explorer**: https://sepolia.uniscan.xyz
- **Bridge**: https://bridge.unichain.org
- **Documentation**: https://docs.unichain.org

### Hook Configuration
- **Swap Fee**: 10 basis points (0.1%)
- **Protocol Fee Share**: 10% of swap fees
- **Circuit Breaker**: 70/30 to 50/50 ratio limits
- **Privacy**: Public reserves always return 1M dummy tokens

## Troubleshooting

### HookMiner Taking Too Long
- The mining process can take 10-20 minutes
- It's searching through 160k iterations for a valid salt
- If it times out, try running again - it will search different salts
- Consider running overnight if needed

### Insufficient Funds
- Ensure you have enough Unichain Sepolia ETH for gas
- Bridge from Sepolia ETH using https://bridge.unichain.org
- Gas fees on Unichain are very low (~0.001-0.01 ETH total)

### Pool Already Exists
If you get an error about pool already existing:
- The pool with these exact parameters exists
- Either use different tokens or different fee/tick spacing
- Or skip initialization and just add liquidity

### Token Approvals
If transactions revert:
- Double-check approvals are set for PoolManager
- Verify you have sufficient token balance
- Check token addresses are correct and sorted

## Next Steps

After successful deployment:

### 1. Test Privacy Features
```bash
# External observers should only see dummy reserves
cast call $HOOK_ADDRESS "getPublicReserves(...)" --rpc-url unichain_sepolia
```

### 2. Perform Test Swaps
- Use Uniswap v4 interfaces
- Verify fees are collected
- Check circuit breaker activates on large swaps

### 3. Test Keeper Functions
```bash
# As keeper, test rebalancing
cast send $HOOK_ADDRESS \
  "rebalance((address,address,uint24,int24,address),uint256,bool)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  10000000000000000 \
  true \
  --rpc-url unichain_sepolia \
  --private-key $KEEPER_PRIVATE_KEY
```

### 4. Withdraw Protocol Fees
```bash
# As owner
cast send $HOOK_ADDRESS \
  "withdrawProtocolFees((address,address,uint24,int24,address))" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url unichain_sepolia \
  --private-key $PRIVATE_KEY
```

### 5. Monitor Events
Watch for hook events:
- `LiquidityAdded`
- `LiquidityRemoved`
- `StealthSwap`
- `Rebalanced`

### 6. Integration
- Build UI for your stealth pool
- Integrate with Uniswap v4 widgets
- Add monitoring and analytics

## Why Unichain?

Deploying on Unichain gives you:

1. **Native v4 Support**: Best-in-class liquidity and routing
2. **Fast Finality**: 1-second blocks for quick swaps
3. **MEV Protection**: Flashblocks prevent frontrunning
4. **Low Costs**: Optimized for DeFi transactions
5. **Future-Proof**: Built specifically for Uniswap v4

Your StealthPoolHook is now live on Unichain, providing privacy-preserving swaps with dummy reserve reporting! 🎉

## Resources

- Unichain Docs: https://docs.unichain.org
- Uniswap v4 Docs: https://docs.uniswap.org/contracts/v4
- Hook Development: https://github.com/Uniswap/v4-periphery
- Block Explorer: https://sepolia.uniscan.xyz
