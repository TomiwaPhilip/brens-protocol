# Unichain Deployment - Command Reference

Quick reference for all deployment commands.

## Network Info
- **Chain ID**: 1301
- **RPC**: https://sepolia.unichain.org
- **PoolManager**: 0xC81462Fec8B23319F288047f8A03A57682a35C1A
- **Explorer**: https://sepolia.uniscan.xyz

## Complete Deployment

```bash
# 1. Deploy test tokens
forge script script/DeployTestTokens.s.sol:DeployTestTokens \
  --rpc-url unichain_sepolia --broadcast -vv

# Save addresses from output
export TOKEN0_ADDRESS=0x...
export TOKEN1_ADDRESS=0x...

# 2. Deploy StealthPoolHook (takes 10-15 min)
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url unichain_sepolia --broadcast --verify -vvv

# Save hook address
export HOOK_ADDRESS=0x...

# 3. Initialize pool
forge script script/InitializeStealthPool.s.sol:InitializeStealthPool \
  --rpc-url unichain_sepolia --broadcast -vv

# 4. Approve tokens
POOL_MANAGER=0xC81462Fec8B23319F288047f8A03A57682a35C1A
cast send $TOKEN0_ADDRESS "approve(address,uint256)" $POOL_MANAGER 1000000000000000000000 \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY
cast send $TOKEN1_ADDRESS "approve(address,uint256)" $POOL_MANAGER 1000000000000000000000 \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY

# 5. Add liquidity
export LIQUIDITY_AMOUNT=1000000000000000000
forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool \
  --rpc-url unichain_sepolia --broadcast -vv
```

## Verification Commands

```bash
# Check hook owner
cast call $HOOK_ADDRESS "owner()(address)" --rpc-url unichain_sepolia

# Check swap fee (should be 10)
cast call $HOOK_ADDRESS "SWAP_FEE_BASIS_POINTS()(uint256)" --rpc-url unichain_sepolia

# Check dummy reserves (should be 1M tokens each)
cast call $HOOK_ADDRESS \
  "getPublicReserves((address,address,uint24,int24,address))(uint256,uint256)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url unichain_sepolia

# Check your balance
cast call $TOKEN0_ADDRESS "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url unichain_sepolia
```

## Management Commands

```bash
# Set keeper
export KEEPER_ADDRESS=0x...
forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook \
  --rpc-url unichain_sepolia --broadcast -vv

# Withdraw protocol fees (as owner)
cast send $HOOK_ADDRESS \
  "withdrawProtocolFees((address,address,uint24,int24,address))" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY

# Rebalance (as keeper)
cast send $HOOK_ADDRESS \
  "rebalance((address,address,uint24,int24,address),uint256,bool)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  10000000000000000 true \
  --rpc-url unichain_sepolia --private-key $KEEPER_PRIVATE_KEY

# Update circuit breaker (as owner)
cast send $HOOK_ADDRESS \
  "setCircuitBreakerThresholds(uint256,uint256)" \
  8000 2000 \
  --rpc-url unichain_sepolia --private-key $PRIVATE_KEY
```

## Remove Liquidity

```bash
export LIQUIDITY_AMOUNT=1000000000000000000
forge script script/InitializeStealthPool.s.sol:RemoveLiquidityFromStealthPool \
  --rpc-url unichain_sepolia --broadcast -vv
```

## Useful Cast Commands

```bash
# Get latest block
cast block latest --rpc-url unichain_sepolia

# Get your balance
cast balance YOUR_ADDRESS --rpc-url unichain_sepolia

# Send ETH
cast send RECIPIENT --value 0.1ether --rpc-url unichain_sepolia --private-key $PRIVATE_KEY

# Get transaction receipt
cast receipt TX_HASH --rpc-url unichain_sepolia
```
