# ConstantSumHook Deployment Scripts

This directory contains deployment scripts for the ConstantSumHook on Uniswap v4.

## Scripts

### 1. `DeployConstantSumHook.s.sol`
Basic deployment script that only deploys the ConstantSumHook contract.

**Usage:**
```bash
# Base Sepolia
forge script script/DeployConstantSumHook.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast --verify

# Arbitrum Sepolia  
forge script script/DeployConstantSumHook.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast --verify

# Unichain Sepolia
forge script script/DeployConstantSumHook.s.sol --rpc-url $UNICHAIN_SEPOLIA_RPC --broadcast --verify
```

### 2. `DeployAndTestComplete.s.sol` ⭐ **Recommended**
Complete deployment script that:
1. ✅ Deploys test tokens (Token A and Token B)
2. ✅ Deploys a simple swap router
3. ✅ Deploys the ConstantSumHook with correct permissions
4. ✅ Initializes a pool at 1:1 price
5. ✅ Adds liquidity (10,000 tokens each)
6. ✅ Performs a test swap (100 tokens)
7. ✅ Displays comprehensive state and summary

**Usage:**
```bash
# Base Sepolia (recommended for testing)
forge script script/DeployAndTestComplete.s.sol:DeployAndTestComplete \
  --rpc-url $BASE_SEPOLIA_RPC \
  --broadcast \
  --verify \
  -vvvv

# Arbitrum Sepolia
forge script script/DeployAndTestComplete.s.sol:DeployAndTestComplete \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --broadcast \
  --verify \
  -vvvv

# Unichain Sepolia
forge script script/DeployAndTestComplete.s.sol:DeployAndTestComplete \
  --rpc-url $UNICHAIN_SEPOLIA_RPC \
  --broadcast \
  --verify \
  -vvvv
```

## Expected Output

When running `DeployAndTestComplete.s.sol`, you'll see:

```
=== Step 1: Deploying Test Tokens ===
Token A deployed: 0x...
Token B deployed: 0x...
Deployer balance A: 1000000 tokens
Deployer balance B: 1000000 tokens

=== Step 2: Deploying Swap Router ===
Swap router deployed: 0x...

=== Step 3: Deploying ConstantSumHook ===
ConstantSumHook deployed: 0x...
Owner: 0x...
Max imbalance ratio: 70 %
Min imbalance ratio: 30 %

=== Step 4: Initializing Pool ===
Pool initialized at 1:1 price
Pool ID: 123456789...

=== Step 5: Adding Liquidity ===
Adding 10000 of each token...
Liquidity added successfully!
  Reserve 0: 10000 tokens
  Reserve 1: 10000 tokens
  Hook claim balance 0: 10000 tokens
  Hook claim balance 1: 10000 tokens

=== Step 6: Performing Swap ===
Before swap:
  User balance A: 990000 tokens
  User balance B: 990000 tokens

Swapping 100 Token A for Token B...

After swap:
  User balance A: 989900 tokens
  User balance B: 990100 tokens
  Token A spent: 100 tokens
  Token B received: 100 tokens
  Ratio: 1:1 (no fees)

=== Step 7: Final State ===
Final reserves:
  Reserve 0: 10100 tokens
  Reserve 1: 9900 tokens
  Reserve ratio: 50 % / 49 %

=== Deployment Summary ===
Network: Base Sepolia
Pool Manager: 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829
Token A: 0x... (Token A)
Token B: 0x... (Token B)
Swap Router: 0x...
ConstantSumHook: 0x...
Pool ID: 123456789...

Hook Configuration:
  Swap Fee: 0% (pure 1:1 swaps)
  Circuit Breaker: 70/30 ratio limit
  Owner: 0x...

=== Next Steps ===
1. Add more liquidity: hook.addLiquidity(key, amount)
2. Remove liquidity: hook.removeLiquidity(key, amount)
3. Perform swaps: swapRouter.swap(key, params)
4. Update circuit breaker: hook.setCircuitBreakerThresholds(maxRatio, minRatio)
```

## Environment Variables

Create a `.env` file with:

```bash
# RPC URLs
BASE_SEPOLIA_RPC=https://sepolia.base.org
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
UNICHAIN_SEPOLIA_RPC=https://sepolia.unichain.org

# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Etherscan API keys for verification
BASESCAN_API_KEY=your_basescan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
```

Load the environment:
```bash
source .env
```

## Features

### ConstantSumHook
- **Pure 1:1 swaps** - No fees, constant sum (x + y = k) pricing
- **Circuit breaker** - Prevents excessive imbalance (default 70/30 ratio)
- **Symmetric liquidity** - Add/remove equal amounts of both tokens
- **ERC-6909 claims** - Hook holds liquidity as claim tokens

### Deployment Scripts Include
- ✅ Token deployment and setup
- ✅ Hook address mining with correct permissions
- ✅ Pool initialization at 1:1 price
- ✅ Liquidity provision
- ✅ Test swap execution
- ✅ State verification and reporting

## Supported Networks

- ✅ **Base Sepolia** (Chain ID: 84532)
- ✅ **Arbitrum Sepolia** (Chain ID: 421614)
- ✅ **Unichain Sepolia** (Chain ID: 1301)

## Troubleshooting

### "PoolManager not configured for this chain"
Make sure you're deploying to a supported testnet. Check the chain ID matches one of the supported networks.

### "Hook address mismatch"
The script uses HookMiner to find the correct hook address. This is expected behavior - the script will automatically deploy at the correct address.

### Gas estimation issues
Use `-vvvv` flag for detailed traces and ensure you have enough testnet ETH for deployment.

## Testing Locally

To test the full deployment flow locally:

```bash
# Start local node
anvil

# In another terminal, run the script
forge script script/DeployAndTestComplete.s.sol:DeployAndTestComplete \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vvvv
```

Note: For local testing, you'll need to deploy the PoolManager first and update the address in `getPoolManager()`.

## Contract Interactions

After deployment, interact with the contracts:

```solidity
// Add more liquidity
hook.addLiquidity(key, 5000 ether);

// Remove liquidity
hook.removeLiquidity(key, 2000 ether);

// Update circuit breaker (owner only)
hook.setCircuitBreakerThresholds(8000, 2000); // 80/20 ratio

// Get reserves
(uint256 reserve0, uint256 reserve1) = hook.getReserves(key);

// Perform swap through router
swapRouter.swap(key, SwapParams({
    zeroForOne: true,
    amountSpecified: -100 ether, // Negative = exact input
    sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
}));
```
