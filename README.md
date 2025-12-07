# Brens Protocol - ConstantSumHook

> **Simple 1:1 stablecoin swaps on Uniswap v4**

## Overview

A gas-efficient Constant Sum Market Maker (CSMM) hook for Uniswap v4 that provides 1:1 swaps ideal for stablecoin pairs with circuit breaker protection against depeg events.

## What is CSMM?

Unlike traditional AMMs that use `x * y = k` (constant product), CSMM uses `x + y = k` (constant sum):

- **Traditional AMM**: Price changes with every trade (slippage)
- **CSMM**: Always 1:1 pricing (zero slippage for pegged assets)

This makes CSMM perfect for:
- Stablecoin pairs (USDC/USDT, DAI/USDC)
- Wrapped/native pairs (WETH/ETH, wBTC/renBTC)
- Synthetic pegged assets

## Key Features

### ✅ Zero Slippage 1:1 Pricing
Every swap maintains exact 1:1 ratio regardless of trade size.

### ✅ 0.1% Swap Fee
- 90% goes to liquidity providers
- 10% goes to protocol (withdrawable by owner)
- Fees compound in LP reserves

### ✅ Circuit Breaker Protection
Prevents pool drainage during depeg events:
- Blocks swaps when reserves exceed 70/30 imbalance
- Configurable thresholds by owner
- Directional: only stops swaps that worsen imbalance (allows arbitrage)

### ✅ Gas-Efficient ERC-6909
Uses Uniswap v4's native claim token system for optimal gas usage.

## Quick Start

### Installation
```bash
git clone https://github.com/TomiwaPhilip/brens-protocol
cd brens-protocol
forge install
```

### Basic Usage
```solidity
// Add liquidity (equal amounts)
hook.addLiquidity(poolKey, 1_000_000 * 1e18);

// Swap 100 USDC for ~99.9 USDT (0.1% fee)
token0.approve(address(hook), 100 * 1e18);
hook.performSwap(poolKey, true, 100 * 1e18);

// Remove liquidity
hook.removeLiquidity(poolKey, 500_000 * 1e18);
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
// 1:1 pricing with 0.1% fee
Input:  100 USDC
Output: 99.9 USDT  (0.1 USDC fee)

// Circuit breaker activates if reserves become too imbalanced
// Example: Prevents USDC depeg from draining all USDT
```

## Circuit Breaker

### How It Works
1. **Track Reserves**: Hook maintains accurate reserve counts
2. **Calculate Ratio**: Check if swap would create imbalance > 70/30
3. **Block if Needed**: Prevent swaps that worsen imbalance
4. **Allow Arbitrage**: Permit swaps that restore balance

### Example Scenario
```
Current: 60% USDC, 40% USDT  (acceptable)
Swap:    100 USDC → 99.9 USDT
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

### Deploy Hook
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

### For Protocol Owner

#### withdrawProtocolFees
```solidity
function withdrawProtocolFees(PoolKey calldata key) external onlyOwner
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

```bash
# Run all tests
forge test

# Run with gas reports
forge test --gas-report

# Test specific functionality
forge test --match-test testSwap -vvv
```

## Gas Costs

| Operation | Gas Cost |
|-----------|----------|
| Add Liquidity | ~150k |
| Remove Liquidity | ~120k |
| Swap (first time) | ~100k |
| Swap (subsequent) | ~80k |

## Security

### ✅ Protections
- Circuit breaker prevents depeg drainage
- Owner controls for emergency adjustments
- Symmetric liquidity requirements
- Fee accounting prevents manipulation

### ⚠️ Considerations
- Requires external arbitrage bots
- No price discovery (assumes external peg)
- Owner trust (consider timelock for production)

### Audit Status
⚠️ Not audited - use at your own risk

## Repository Structure

```
brens-protocol/
├── src/
│   └── ConstantSumHook.sol
├── test/
│   └── utils/
└── README.md
```

## License

MIT

## Resources

- [Uniswap v4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Hook Examples](https://github.com/Uniswap/v4-periphery)

## Contributing

Contributions welcome! Please open an issue or PR.
