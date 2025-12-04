# StealthPoolHook Testnet Deployment Guide

## Prerequisites

1. **Wallet with testnet ETH**
   - Base Sepolia: Get ETH from [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
   - Arbitrum Sepolia: Get ETH from [Arbitrum Sepolia Faucet](https://faucet.quicknode.com/arbitrum/sepolia)

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your private key and other values
   ```

3. **Test Tokens** (Optional - for creating test pools)
   - You can use existing testnet tokens or deploy your own ERC20s

## Deployment Steps

### Step 1: Deploy StealthPoolHook

The deployment uses HookMiner to find a valid address with the required hook permissions. **This process can take 5-15 minutes** as it searches for a valid salt.

#### Deploy to Base Sepolia (Chain ID: 84532)

```bash
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  -vvvv
```

#### Deploy to Arbitrum Sepolia (Chain ID: 421614)

```bash
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY \
  -vvvv
```

**Note**: The HookMiner will search for a valid hook address. This process:
- Iterates up to 160,444 times
- Finds an address where the bottom 14 bits match the required hook flags
- May take 5-15 minutes depending on luck

**Expected Output**:
```
Mining for hook address...
This may take a while...
Found valid hook address: 0x...
Salt: 0x...
StealthPoolHook deployed at: 0x...
Owner: 0x...
```

Save the deployed `HOOK_ADDRESS` to your `.env` file.

### Step 2: Configure the Hook (Optional)

Set a keeper address for rebalancing operations:

```bash
forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

### Step 3: Initialize a Pool

Create a pool with your StealthPoolHook. You need two ERC20 token addresses where `token0 < token1`.

```bash
# Set environment variables
export HOOK_ADDRESS=0x...  # From Step 1
export TOKEN0_ADDRESS=0x... # Lower address
export TOKEN1_ADDRESS=0x... # Higher address

forge script script/InitializeStealthPool.s.sol:InitializeStealthPool \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

**Expected Output**:
```
Pool initialized successfully!
Pool ID: 0x...
Public Reserve0: 1000000000000000000000000
Public Reserve1: 1000000000000000000000000
(Note: Public reserves are dummy values for privacy)
```

### Step 4: Add Liquidity

Add initial liquidity to your pool:

```bash
# First approve tokens
# Call approve() on both token contracts:
# token0.approve(POOL_MANAGER_ADDRESS, LIQUIDITY_AMOUNT)
# token1.approve(POOL_MANAGER_ADDRESS, LIQUIDITY_AMOUNT)

export LIQUIDITY_AMOUNT=1000000000000000000  # 1 token with 18 decimals

forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Network Information

### Base Sepolia (Chain ID: 84532)
- **PoolManager**: `0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829`
- **Block Explorer**: https://sepolia.basescan.org
- **Faucet**: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet

### Arbitrum Sepolia (Chain ID: 421614)
- **PoolManager**: `0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A`
- **Block Explorer**: https://sepolia.arbiscan.io
- **Faucet**: https://faucet.quicknode.com/arbitrum/sepolia

## Hook Features

The deployed StealthPoolHook has:

### Privacy Features
- **Dummy Reserves**: Public queries return constant dummy values (1M tokens)
- **Dummy Delta**: Swap deltas are masked from external observers
- **Real accounting**: Internal reserves track actual liquidity privately

### Configuration
- **Swap Fee**: 10 basis points (0.1%)
- **Protocol Fee**: 10% of swap fees
- **Circuit Breaker**: 90/10 to 50/50 ratio limits (prevents excessive imbalance)
- **Owner Control**: Can update keeper, withdraw fees, adjust circuit breaker

### Functions
- `addLiquidity(PoolKey, uint256 amountEach)` - Add symmetric liquidity
- `removeLiquidity(PoolKey, uint256 amountEach)` - Remove liquidity
- `rebalance(PoolKey, uint256 amountIn, bool zeroForOne)` - Keeper-only rebalancing
- `getPublicReserves(PoolKey)` - Returns dummy reserves
- `withdrawProtocolFees(PoolKey)` - Owner withdraws accumulated fees

## Testing Your Deployment

### 1. Check Deployment

```bash
cast call $HOOK_ADDRESS "owner()(address)" --rpc-url $BASE_SEPOLIA_RPC_URL
cast call $HOOK_ADDRESS "keeper()(address)" --rpc-url $BASE_SEPOLIA_RPC_URL
cast call $HOOK_ADDRESS "SWAP_FEE_BASIS_POINTS()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 2. Verify Pool Initialization

```bash
# Check if pool exists in PoolManager
cast call $POOL_MANAGER_ADDRESS "pools(bytes32)(address,uint256,...)" $POOL_ID --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 3. Check Public Reserves (Should be dummy)

```bash
cast call $HOOK_ADDRESS \
  "getPublicReserves((address,address,uint24,int24,address))(uint256,uint256)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

Should return: `1000000000000000000000000, 1000000000000000000000000` (dummy values)

## Troubleshooting

### HookMiner Taking Too Long
- The mining process can legitimately take 10-20 minutes
- If it times out, try running again - it will find a different salt
- Consider increasing gas limit if needed

### Hook Address Validation Failed
- Ensure the address has the correct flags in the bottom 14 bits
- Verify you're using CREATE2_DEPLOYER: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- Check that no code exists at the target address before deployment

### Pool Initialization Failed
- Verify TOKEN0 < TOKEN1 (addresses sorted)
- Ensure hook address is valid
- Check that pool doesn't already exist with these parameters

### Transaction Reverted
- Check you have sufficient testnet ETH for gas
- Verify token approvals are set correctly
- Ensure you're the owner/keeper for restricted functions

## Next Steps

After deployment:

1. **Add Liquidity**: Use the AddLiquidityToStealthPool script
2. **Test Swaps**: Use Uniswap v4 interfaces to perform swaps
3. **Monitor Privacy**: Verify public reserves always return dummy values
4. **Setup Keeper**: Configure automated rebalancing if needed
5. **Withdraw Fees**: Owner can withdraw accumulated protocol fees

## Security Notes

- Store private keys securely (use hardware wallet for mainnet)
- Test all functions on testnet before mainnet deployment
- Verify contracts on block explorer
- Set a different keeper address than the owner
- Monitor circuit breaker events for unusual activity
- Remember: This is experimental hook technology - audit before production use

## Support

For issues or questions:
- Check the [StealthPoolHook source code](../src/StealthPoolHook.sol)
- Review [test files](../test/StealthPoolHook.t.sol) for usage examples
- See Uniswap v4 documentation: https://docs.uniswap.org/contracts/v4/overview
