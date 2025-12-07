# Brens Protocol - ConstantSumHook

> **Zero-fee, zero-slippage swaps for pegged assets on Uniswap v4**

## Overview

A gas-efficient Constant Sum Market Maker (CSMM) hook for Uniswap v4 that provides 1:1 swaps with automatic rebalancing for stablecoins and pegged assets, with circuit breaker protection against depeg events.

## What is CSMM?

Unlike traditional AMMs that use `x * y = k` (constant product), CSMM uses `x + y = k` (constant sum):

- **Traditional AMM**: Price changes with every trade (slippage)
- **CSMM**: Always 1:1 pricing (zero slippage for pegged assets)

This makes CSMM perfect for:
- **Stablecoin pairs**: USDC/USDT, DAI/USDC, FRAX/USDC
- **Wrapped/native pairs**: WETH/ETH, wBTC/renBTC
- **Liquid staking tokens**: stETH/ETH, rETH/ETH
- **Synthetic pegged assets**: Any 1:1 pegged token pairs

## Key Features

### ✅ Zero Slippage, Zero Fees
- Perfect 1:1 swaps regardless of trade size
- **No swap fees** - pure 1:1 exchange
- Ideal for large trades without price impact

### ✅ Keeper-Based Auto-Rebalancing
- Trusted keeper bots automatically rebalance pools when imbalanced
- Owner or keeper can trigger rebalancing
- Only adds to deficient side (gas efficient)
- View function to check if rebalancing needed

### ✅ Circuit Breaker Protection
Prevents pool drainage during depeg events:
- Blocks swaps when reserves exceed 70/30 imbalance (default)
- Configurable thresholds by owner (50-95% range)
- Directional: only stops swaps that worsen imbalance (allows arbitrage back to peg)

### ✅ Gas-Efficient ERC-6909
Uses Uniswap v4's native claim token system for optimal gas usage.

## Quick Start

### Installation
```bash
git clone https://github.com/TomiwaPhilip/brens-protocol
cd brens-protocol
forge install
```

### Run Tests
All 18 tests are passing ✅

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run with gas reports
forge test --gas-report
```

### Basic Usage
```solidity
// Add liquidity (equal amounts)
hook.addLiquidity(poolKey, 1_000_000 * 1e18);

// Swap 100 USDC for 100 USDT (zero fees, 1:1)
token0.approve(address(hook), 100 * 1e18);
// Swap happens automatically at 1:1 ratio

// Remove liquidity
hook.removeLiquidity(poolKey, 500_000 * 1e18);

// Set keeper for auto-rebalancing (owner only)
hook.setKeeper(keeperAddress);

// Check if pool needs rebalancing
(bool needsRebalance, uint256 amount0, uint256 amount1) = hook.checkRebalanceNeeded(poolKey);

// Rebalance pool (keeper or owner)
hook.rebalancePool(poolKey);
```

## How It Works

### Liquidity Provision
```solidity
// Add equal amounts of both tokens
hook.addLiquidity(poolKey, 1_000_000 * 1e18);

// Receive ERC-6909 claim tokens representing your share
// Can withdraw at any time by burning claim tokens
```

### Swaps
```solidity
// Pure 1:1 pricing with ZERO fees
Input:  100 USDC
Output: 100 USDT (no fees, perfect 1:1)

// Circuit breaker activates if reserves become too imbalanced
// Example: Prevents USDC depeg from draining all USDT
```

### Auto-Rebalancing
```solidity
// Keeper monitors pool balance
(bool needsRebalance, uint256 amount0ToAdd, uint256 amount1ToAdd) = hook.checkRebalanceNeeded(poolKey);

if (needsRebalance) {
    // Keeper adds only the deficient token
    token.approve(address(hook), amount);
    hook.rebalancePool(poolKey);
    // Pool returns to 50/50 balance
}
```

## Circuit Breaker

### How It Works
1. **Track Reserves**: Hook maintains accurate reserve counts
2. **Calculate Ratio**: Check if swap would create imbalance > 70/30 (default)
3. **Block if Needed**: Prevent swaps that worsen imbalance
4. **Allow Arbitrage**: Permit swaps that restore balance
5. **Auto-Rebalance**: Keeper bots can rebalance when needed

### Example Scenario
```
Current: 60% USDC, 40% USDT  (acceptable)
Swap:    100 USDC → 100 USDT
Result:  61% USDC, 39% USDT  ✅ Allowed (still under 70%)

Current: 69% USDC, 31% USDT  (near limit)
Swap:    100 USDC → 99.9 USDT  
Result:  70% USDC, 30% USDT  ❌ BLOCKED (hits threshold)

// But arbitrage in opposite direction is allowed:
Swap:    100 USDT → 99.9 USDC
Result:  68% USDC, 32% USDT  ✅ Allowed (improves balance)
```

## Deployment

### Prerequisites
```bash
forge install
```

### Option 1: Using Deployment Scripts (Recommended)

Deployment scripts are available in the `script/` directory:

```bash
# Deploy hook only
forge script script/DeployConstantSumHook.s.sol --rpc-url <RPC_URL> --broadcast

# Deploy and test everything (hook + tokens + pool)
forge script script/DeployAndTestComplete.s.sol --rpc-url <RPC_URL> --broadcast
```

See [script/README.md](./script/README.md) for detailed deployment instructions.

### Option 2: Manual Deployment

You can also deploy the hook manually:

```solidity
// 1. Mine address with correct permissions
uint160 flags = uint160(
    Hooks.BEFORE_INITIALIZE_FLAG |
    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
    Hooks.BEFORE_SWAP_FLAG |
    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
);

(address hookAddress, bytes32 salt) = HookMiner.find(
    deployer,
    flags,
    type(ConstantSumHook).creationCode,
    abi.encode(poolManager)
);

// 2. Deploy with correct address
ConstantSumHook hook = new ConstantSumHook{salt: salt}(poolManager);
```

### Initialize Pool
```solidity
PoolKey memory key = PoolKey({
    currency0: Currency.wrap(address(token0)),
    currency1: Currency.wrap(address(token1)),
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(address(hook))
});

poolManager.initialize(key, SQRT_PRICE_1_1);
```
## Notes 

**No partner integrations**

## API Reference

### For Liquidity Providers

#### addLiquidity
```solidity
function addLiquidity(PoolKey calldata key, uint256 amountEach) external
```
Deposit equal amounts of both tokens and receive ERC-6909 claim tokens.

#### removeLiquidity
```solidity
function removeLiquidity(PoolKey calldata key, uint256 amountEach) external
```
Burn claim tokens and withdraw tokens.

#### getReserves
```solidity
function getReserves(PoolKey calldata key) external view returns (uint256, uint256)
```
View current pool reserves.

### For Keeper Bots

#### checkRebalanceNeeded
```solidity
function checkRebalanceNeeded(PoolKey calldata key) 
    external view 
    returns (bool needsRebalance, uint256 amount0ToAdd, uint256 amount1ToAdd)
```
Check if pool needs rebalancing and how much to add.

#### rebalancePool
```solidity
function rebalancePool(PoolKey calldata key) external
```
Rebalance pool by adding to deficient side (keeper or owner only).

### For Protocol Owner

#### setKeeper
```solidity
function setKeeper(address newKeeper) external onlyOwner
```
Set trusted keeper address for auto-rebalancing.

#### setCircuitBreakerThresholds
```solidity
function setCircuitBreakerThresholds(uint256 newMaxRatio, uint256 newMinRatio) external onlyOwner
```
Update circuit breaker thresholds (must sum to 100%).

#### transferOwnership
```solidity
function transferOwnership(address newOwner) external onlyOwner
```
Transfer ownership to new address.
```
Collect accumulated protocol fees.

#### setCircuitBreakerThresholds
```solidity
function setCircuitBreakerThresholds(uint256 newMaxRatio, uint256 newMinRatio) external onlyOwner
```
Update circuit breaker parameters (in basis points).

#### transferOwnership
```solidity
function transferOwnership(address newOwner) external onlyOwner
```
Transfer contract ownership.

## Testing

✅ All 18 tests passing

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run with gas reports
forge test --gas-report

# Test specific functionality
forge test --match-test testSwap -vvv

# Test keeper functionality
forge test --match-test test_rebalance -vvv
```

### Test Coverage
- ✅ Liquidity provision (add/remove)
- ✅ Swaps (exact input/output)
- ✅ Circuit breaker protection
- ✅ Keeper rebalancing
- ✅ Access control
- ✅ Edge cases and error handling

## Gas Costs

| Operation | Gas Cost |
|-----------|----------|
| Add Liquidity | ~169k |
| Remove Liquidity | ~101k |
| Swap (exact input) | ~143k |
| Swap (exact output) | ~143k |
| Rebalance Pool | ~525k |
| Check Rebalance | ~146k (view) |

## Security

### ✅ Protections
- Circuit breaker prevents depeg drainage
- Owner controls for emergency adjustments
- Symmetric liquidity requirements
- Keeper-based rebalancing with access control
- Zero fees eliminate fee manipulation
- Unlock callback pattern for safety

### ⚠️ Considerations
- Keeper must be trusted (owner can revoke)
- Requires keeper bot for automatic rebalancing
- No price discovery (assumes external peg)
- Owner trust (consider timelock for production)

### Audit Status
⚠️ Not audited - use at your own risk

## Repository Structure

```
brens-protocol/
├── src/
│   ├── ConstantSumHook.sol         # Main hook implementation
│   ├── TPT.sol                      # TokenizedPosition (unused)
│   ├── TPTFactory.sol              # Factory (unused)
│   ├── TPTRegistry.sol             # Registry (unused)
│   └── PrivatePoolHook.sol         # Private pool (unused)
├── test/
│   └── ConstantSumHook.t.sol       # Comprehensive test suite (18 tests)
├── script/
│   ├── DeployConstantSumHook.s.sol      # Basic deployment
│   ├── DeployAndTestComplete.s.sol      # Full deployment + test
│   └── README.md                         # Deployment guide
├── DEPLOYMENTS.md                   # Deployment addresses
└── README.md                        # This file
```

## Live Deployments

See [DEPLOYMENTS.md](./DEPLOYMENTS.md) for all contract addresses on:
- ✅ Unichain Sepolia (Active)
- More networks coming soon...

## License

MIT

## Resources

- [Uniswap v4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Hook Examples](https://github.com/Uniswap/v4-periphery)

## Contributing

Contributions welcome! Please open an issue or PR.
