# 🚀 Quick Start: Deploy StealthPoolHook on Unichain

This is the fastest path to deploying your StealthPoolHook on Unichain Sepolia testnet.

## Prerequisites (2 minutes)

1. **Get some Unichain Sepolia ETH**
   - Bridge from Sepolia: https://bridge.unichain.org
   - Or use a faucet if available

2. **Setup your environment**
   ```bash
   cd /Users/admin/Documents/coding/brens-protocol
   cp .env.example .env
   ```

3. **Add your private key to `.env`**
   ```bash
   PRIVATE_KEY=your_private_key_without_0x_prefix
   ```

## Deploy in 4 Commands (15-20 minutes)

### 1. Deploy Test Tokens (30 seconds)

```bash
forge script script/DeployTestTokens.s.sol:DeployTestTokens \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vv
```

**Save the output:**
```bash
export TOKEN0_ADDRESS=0x...  # Copy from output
export TOKEN1_ADDRESS=0x...  # Copy from output
```

### 2. Deploy StealthPoolHook (10-15 minutes)

⚠️ **This takes time** - HookMiner searches for a valid address with correct permissions

```bash
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vvv
```

**Save the hook address:**
```bash
export HOOK_ADDRESS=0x...  # Copy from "StealthPoolHook deployed at:" output
```

**Note:** The deployer is automatically set as both owner and keeper. If you want a separate keeper, use the optional SetupStealthPoolHook script after deployment.

### 3. Initialize Pool (30 seconds)

This creates the pool in the PoolManager:

```bash
forge script script/InitializeStealthPool.s.sol:InitializeStealthPool \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vv
```

### 4. Approve & Add Liquidity (1 minute)

```bash
# Approve tokens
POOL_MANAGER=0xC81462Fec8B23319F288047f8A03A57682a35C1A

cast send $TOKEN0_ADDRESS \
  "approve(address,uint256)" $POOL_MANAGER 1000000000000000000000 \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY

cast send $TOKEN1_ADDRESS \
  "approve(address,uint256)" $POOL_MANAGER 1000000000000000000000 \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY

# Add liquidity
export LIQUIDITY_AMOUNT=1000000000000000000

forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vv
```

## ✅ Verify Deployment

```bash
# Check privacy - should return dummy reserves (1M tokens each)
cast call $HOOK_ADDRESS \
  "getPublicReserves((address,address,uint24,int24,address))(uint256,uint256)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url unichain_sepolia
```

Expected: `1000000000000000000000000, 1000000000000000000000000`

## 🎉 You're Done!

Your StealthPoolHook is now live on Unichain with:
- ✅ Privacy-preserving dummy reserves
- ✅ 0.1% swap fee (10 basis points)
- ✅ Circuit breaker protection
- ✅ Keeper rebalancing capability
- ✅ Initial liquidity added

## View Your Deployment

- **Explorer**: https://sepolia.uniscan.xyz/address/YOUR_HOOK_ADDRESS
- **Network**: Unichain Sepolia (Chain ID: 1301)
- **PoolManager**: 0xC81462Fec8B23319F288047f8A03A57682a35C1A

## Troubleshooting

**HookMiner is slow**: This is normal! It's searching for a valid address. Can take 10-20 minutes.

**Transaction reverts**: 
- Check you have enough Unichain Sepolia ETH
- Verify TOKEN0 < TOKEN1 (addresses sorted)
- Ensure approvals are set before adding liquidity

**Pool already exists**: 
- Try different tokens
- Or use different fee tier/tick spacing

## Full Documentation

For detailed instructions, see:
- [Complete Unichain Guide](./UNICHAIN_DEPLOYMENT.md)
- [General Deployment Checklist](./DEPLOYMENT_CHECKLIST.md)

## Next Steps

1. **Test swaps** using Uniswap v4 interfaces
2. **Set keeper** for automated rebalancing
3. **Withdraw fees** as they accumulate
4. **Build your UI** for users to interact with your pool

## Optional: Post-Deployment Configuration

### Set a Separate Keeper (Optional)

By default, the deployer is both owner and keeper. If you want a separate keeper address:

```bash
export KEEPER_ADDRESS=0x...  # Your keeper address

forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook \
  --rpc-url unichain_sepolia \
  --broadcast \
  -vv
```

### Adjust Circuit Breaker (Optional)

To change the circuit breaker thresholds from default (70/30):

```bash
# Edit script/DeployStealthPoolHook.s.sol SetupStealthPoolHook
# Uncomment the setCircuitBreakerThresholds lines and set your values
# Then run the script
```

Or use cast directly:
```bash
cast send $HOOK_ADDRESS \
  "setCircuitBreakerThresholds(uint256,uint256)" \
  8000 2000 \
  --rpc-url unichain_sepolia \
  --private-key $PRIVATE_KEY
```

## Understanding the Scripts

- **DeployTestTokens** - Deploy two ERC20 test tokens
- **DeployStealthPoolHook** - Mine and deploy the hook (sets deployer as owner & keeper)
- **InitializeStealthPool** - Create the pool in PoolManager with proper PoolKey
- **AddLiquidityToStealthPool** - Add liquidity to your pool
- **SetupStealthPoolHook** - (Optional) Configure keeper and circuit breaker post-deployment
- ~~CreateStealthPool~~ - Deprecated, use InitializeStealthPool instead

Happy building! 🛠️
