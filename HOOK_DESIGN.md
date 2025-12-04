# StealthPoolHook Design Documentation

## Executive Summary

The StealthPoolHook is a Uniswap v4 hook that implements a **dark pool** architecture for private token trading. It completely bypasses Uniswap's AMM pricing mechanism, implementing instead a Constant Sum Market Maker (CSMM) with circuit breaker protection.

**Note**: This is the production-ready plaintext foundation. FHE (Fully Homomorphic Encryption) integration for fully encrypted reserves and swap amounts is planned for Phase 2.

---

## Core Design Decisions

### 1. Constant Sum Market Maker (x + y = k)

**Decision:** Use 1:1 pricing instead of dynamic pricing curves (e.g., StableSwap, Constant Product).

**Rationale:**
- **FHE Compatibility:** CSMM requires only addition/subtraction on encrypted values, whereas curves like StableSwap need iterative calculations incompatible with FHE
- **Gas Efficiency:** Simple arithmetic operations reduce gas costs significantly
- **Privacy Preservation:** 1:1 pricing doesn't reveal reserve information through price discovery
- **Use Case Fit:** Ideal for stablecoin pairs (USDC/USDT) and private token pairs (USDC/pUSDC) where parity is expected

**Trade-offs:**
- ❌ Requires external arbitrage to restore balance after depegs
- ❌ No natural price adjustment mechanism
- ✅ Simpler implementation and testing
- ✅ Predictable user experience (always 1:1 minus fees)

**Alternative Considered:** StableSwap invariant (`D³/(27xy)`)
- **Rejected because:**
  - Iterative D calculation incompatible with FHE operations
  - Price discovery mechanism reveals reserve ratios (breaks privacy)
  - Significantly higher gas costs (~30-50% more)
  - Adds complexity without alignment to privacy goals

---

### 2. Circuit Breaker Protection

**Decision:** Implement reserve ratio thresholds (70/30 split) with directional blocking.

**Implementation:**
```solidity
MAX_IMBALANCE_RATIO = 7000; // 70% in basis points
MIN_IMBALANCE_RATIO = 3000; // 30%
```

**Mechanism:**
1. Before each swap, calculate post-swap reserve ratio
2. If ratio would exceed 70% or fall below 30%, revert with `ExcessiveImbalance()`
3. **Directional blocking:** Only block swaps that worsen the imbalance
4. Allow opposite-direction swaps to naturally rebalance the pool

**Rationale:**
- **Depeg Protection:** Prevents pool drainage when one asset loses parity
- **LP Protection:** Stops arbitrageurs from converting all valuable assets to worthless ones
- **FHE Compatible:** Simple comparison operations work with encrypted thresholds
- **Automatic Recovery:** Opposite-direction swaps create arbitrage incentive for rebalancing

**Example Scenario:**
```
Initial:     10,000 USDC (50%) | 10,000 pUSDC (50%)  ✓ Balanced

After depeg: 17,000 USDC (68%) |  7,000 pUSDC (32%)  ✓ Still trading

Attack swap: 18,500 USDC (73%) |  6,500 pUSDC (27%)  ✗ Circuit breaker trips
             └─ USDC→pUSDC swaps blocked
             └─ pUSDC→USDC swaps allowed (rebalancing direction)
```

**Alternative Considered:** Dynamic pricing with slippage
- **Rejected because:**
  - Reveals reserve information through price impact
  - Doesn't fully prevent drainage (just slows it)
  - More complex math incompatible with FHE
  - Users experience unpredictable pricing

---

### 3. Custom Liquidity Provision

**Decision:** Force users through `addLiquidity()` instead of Uniswap's standard `modifyLiquidity()`.

**Implementation:**
```solidity
function _beforeAddLiquidity(...) internal pure override {
    revert AddLiquidityThroughHook();
}
```

**Custom Flow:**
1. User calls `addLiquidity(key, amountEach)`
2. Hook triggers `poolManager.unlock()` with callback data
3. `unlockCallback()` executes atomic token settlement:
   - `settle()`: Transfers tokens from user → PoolManager vault
   - `take()` with `claims=true`: Mints ERC-6909 claim tokens to hook

**Rationale:**
- **Symmetric Deposits:** Enforces equal amounts of both currencies (maintains balance)
- **Claim Token Tracking:** Hook owns liquidity as ERC-6909 tokens, enabling precise accounting
- **FHE Migration Path:** ERC-6909 balances can be replaced with `euint64` encrypted reserves
- **Simplified LP Shares:** Avoids complex tick-based positions from standard v4 liquidity

**Benefits:**
- No tick ranges or concentrated liquidity complexity
- Direct 1:1 correspondence between deposits and claim tokens
- Hook controls all reserves (enables private pool behavior)
- Future encrypted LP share calculation

---

### 4. Fee Mechanism (0.1%)

**Decision:** 10 basis points (0.001) swap fee with differential calculation based on swap type.

**Implementation:**

**Exact Input Swaps** (user specifies amount to sell):
```solidity
absInputAmount = 1000 USDC
feeAmount = 1000 * 10 / 10000 = 1 USDC
absOutputAmount = 1000 - 1 = 999 pUSDC
```
User receives **less output** (fee deducted from output side).

**Exact Output Swaps** (user specifies amount to receive):
```solidity
absOutputAmount = 1000 pUSDC (desired)
feeAmount = 1000 * 10 / 10000 = 1 USDC
absInputAmount = 1000 + 1 = 1001 USDC
```
User pays **more input** (fee added to input side).

**Rationale:**
- **LP Revenue:** Generates yield for liquidity providers without AMM volatility
- **Competitive Rate:** 0.1% matches Uniswap v3 stablecoin pools
- **Compounding:** Fees accumulate in reserves, automatically increasing LP shares' value
- **Event Tracking:** `HookSwap` event logs fees for off-chain LP accounting

**Fee Accumulation Model:**
- Fees remain in the pool as claim tokens
- Each swap leaves slightly more input currency than output currency
- LPs proportionally own accumulated fees via their claim token balances
- No complex fee withdrawal mechanism needed (fees auto-compound)

---

### 5. BeforeSwap Delta Override

**Decision:** Use `beforeSwapReturnDelta` permission to completely bypass Uniswap's AMM pricing.

**How It Works:**
```solidity
getHookPermissions() returns Hooks.Permissions({
    beforeSwap: true,              // Hook executes before swap
    beforeSwapReturnDelta: true,   // Hook provides custom amounts
    ...
});

function _beforeSwap(...) returns (bytes4, BeforeSwapDelta, uint24) {
    BeforeSwapDelta delta = toBeforeSwapDelta(absInputAmount, -absOutputAmount);
    return (this.beforeSwap.selector, delta, 0);
}
```

**Delta Sign Convention:**
- **Positive:** User owes the pool (user pays)
- **Negative:** Pool owes the user (user receives)

**Example:**
```
Swap 100 USDC → pUSDC (exact input):
├─ BeforeSwapDelta(100, -99)
│   ├─ Specified (input):   +100 USDC  → User pays 100 USDC
│   └─ Unspecified (output): -99 pUSDC → User receives 99 pUSDC
└─ Uniswap's AMM calculation is SKIPPED
```

**Rationale:**
- **Complete Control:** Hook defines pricing logic, not the AMM curve
- **CSMM Implementation:** Enables 1:1 swaps instead of `x * y = k`
- **Future Flexibility:** Can implement any pricing model (FHE calculations, oracles, etc.)
- **Gas Savings:** Skips Uniswap's swap math when not needed

**Critical Note:**
Without `beforeSwapReturnDelta: true`, the hook would only observe swaps but couldn't override pricing. This permission is **essential** for dark pool functionality.

---

## Token Settlement Flow

### Liquidity Addition
```
USER                    HOOK                     POOLMANAGER
 |                       |                            |
 |--addLiquidity(1000)-->|                            |
 |                       |--unlock(callbackData)----->|
 |                       |                            |
 |                       |<--unlockCallback(data)-----|
 |                       |                            |
 |                       |--settle(USDC, 1000)------->|
 |                       |   (Transfer from user)     |
 |                       |--settle(pUSDC, 1000)------>|
 |                       |   (Transfer from user)     |
 |                       |                            |
 |                       |--take(USDC, 1000, claims)->|
 |                       |   (Mint claim tokens)      |
 |                       |--take(pUSDC, 1000, claims)->
 |                       |   (Mint claim tokens)      |
 |                       |                            |
 |<--HookModifyLiquidity event                        |
```

### Swap Execution (USDC → pUSDC)
```
USER                    HOOK                     POOLMANAGER
 |                       |                            |
 |--swap(-100 USDC)----->|                            |
 |                       |--_beforeSwap()             |
 |                       |  Calculate:                |
 |                       |  - Input: 100 USDC         |
 |                       |  - Fee: 1 USDC (0.1%)      |
 |                       |  - Output: 99 pUSDC        |
 |                       |                            |
 |                       |  Check reserves:           |
 |                       |  - balance1 >= 99 ✓        |
 |                       |                            |
 |                       |  Check circuit breaker:    |
 |                       |  - newRatio0 <= 70% ✓      |
 |                       |                            |
 |                       |--take(USDC, 100, claims)-->|
 |                       |   Hook receives +100 USDC  |
 |                       |                            |
 |                       |--settle(pUSDC, 99, claims)->
 |                       |   Hook burns -99 pUSDC     |
 |                       |   User receives 99 pUSDC   |
 |                       |                            |
 |<--99 pUSDC received---|                            |
 |                       |                            |
 |   RESULT: Hook now has +1 USDC fee in reserves    |
```

---

## FHE Migration Path

### Current State (Plaintext)
```solidity
uint256 balance0 = poolManager.balanceOf(address(this), currency0.toId());
uint256 balance1 = poolManager.balanceOf(address(this), currency1.toId());
```

### Future State (Encrypted)
```solidity
euint64 encryptedBalance0; // Stored in contract state
euint64 encryptedBalance1;

// Circuit breaker with encrypted comparison
euint64 encryptedRatio = FHE.div(encryptedBalance0, totalReserves);
ebool exceedsMax = FHE.gt(encryptedRatio, encryptedMaxRatio);
require(!FHE.decrypt(exceedsMax), "ExcessiveImbalance");

// Encrypted swap amounts
euint64 encryptedInput = FHE.asEuint64(inputAmount);
euint64 encryptedFee = FHE.div(FHE.mul(encryptedInput, feeBasisPoints), divisor);
euint64 encryptedOutput = FHE.sub(encryptedInput, encryptedFee);
```

**Why Current Design Enables FHE:**
1. **Simple arithmetic:** Addition/subtraction work on encrypted values
2. **No iterations:** CSMM doesn't need Newton-Raphson or other iterative methods
3. **Threshold checks:** Circuit breaker comparisons translate to FHE boolean operations
4. **State tracking:** ERC-6909 balances easily replaced with `euint64` state variables

---

## Security Considerations

### 1. Depeg Attack Prevention
**Threat:** Attacker buys depegged token cheap, swaps 1:1 for valuable token.

**Mitigation:**
- Circuit breaker stops swaps at 70/30 threshold
- InsufficientLiquidity check prevents overdrafts
- Directional blocking allows natural rebalancing

### 2. Liquidity Locking
**Threat:** Users cannot withdraw liquidity (no remove function yet).

**Status:** Future implementation needed for LP withdrawals.

**Mitigation Plan:**
- Add `removeLiquidity()` function with proportional share calculation
- Implement pro-rata claim token burning
- Consider timelock for large withdrawals

### 3. Fee Manipulation
**Threat:** MEV bots sandwich attacks around large swaps.

**Mitigation:**
- Fixed 0.1% fee (not dynamic)
- 1:1 pricing provides no arbitrage opportunity
- Private mempool integration (future with FHE)

### 4. Reserve Observation
**Threat:** Attackers query reserve ratios via failed transactions.

**Current State:** Reserves are public (ERC-6909 balances).

**Future Mitigation:**
- Encrypt all reserve data with FHE
- Circuit breaker checks happen on encrypted values
- Swap events emit encrypted amounts only

---

## Performance Analysis

### Gas Costs (Estimated)

| Operation | Gas Cost | Comparison |
|-----------|----------|------------|
| `addLiquidity()` | ~180,000 | Standard v4: ~200,000 |
| `swap()` (no circuit trip) | ~140,000 | Standard v4: ~120,000 |
| `swap()` (circuit breaker hit) | ~150,000 | +10k for ratio calc |
| Reserve check | ~5,000 | 2 SLOAD + arithmetic |
| Circuit breaker calc | ~3,000 | Simple division |

**Optimization Notes:**
- `via_ir = true` enabled for complex functions (avoids stack-too-deep)
- `optimizer_runs = 800` balances deployment vs execution costs
- ERC-6909 claim tokens cheaper than position NFTs

---

## Design Evolution

### Phase 1: Current (Plaintext Foundation) ✅
- CSMM with 1:1 pricing
- Circuit breaker protection
- Custom liquidity provision
- 0.1% fees
- ERC-6909 claim token accounting

### Phase 2: FHE Integration (Next) 🔄
- Replace `uint256` with `euint64` for reserves
- Encrypt swap amounts with `FHE.asEuint64()`
- Encrypted circuit breaker comparisons
- Private event emissions

### Phase 3: Advanced Features (Future) 📋
- Encrypted LP share tracking
- Time-weighted average reserves (TWAR) for oracles
- Multi-hop private routing
- Cross-chain FHE bridges

---

## Comparison: StealthPoolHook vs Alternatives

| Feature | StealthPoolHook | Uniswap v4 Standard | Curve StableSwap |
|---------|----------------|---------------------|------------------|
| **Pricing Model** | CSMM (1:1) | Constant Product | Hybrid Curve |
| **Gas Cost** | Medium | Low | High |
| **Privacy** | FHE-ready | Public | Public |
| **Depeg Protection** | Circuit breaker | None | Slippage |
| **LP Complexity** | Simple (claim tokens) | Complex (positions) | Medium (gauges) |
| **Fee Model** | Fixed 0.1% | Dynamic tiers | Dynamic (A param) |
| **FHE Compatible** | ✅ Yes | ❌ No | ❌ No |

---

## Testing Recommendations

### Unit Tests
```solidity
// Test circuit breaker triggers at exactly 70/30
testCircuitBreakerThreshold()

// Test directional blocking (opposite swaps still work)
testDirectionalBlocking()

// Test fee calculations for exact input vs exact output
testFeeCalculations()

// Test insufficient liquidity protection
testInsufficientLiquidity()
```

### Integration Tests
```solidity
// Test depeg scenario with multiple swaps
testDepegProtection()

// Test liquidity provision and claim token minting
testLiquidityFlow()

// Test event emissions for LP accounting
testEventTracking()
```

### Fuzz Tests
```solidity
// Random swap amounts within reasonable bounds
testFuzzSwapAmounts(uint256 amount)

// Random reserve states
testFuzzCircuitBreaker(uint256 bal0, uint256 bal1)
```

---

## Deployment Checklist

- [ ] Deploy on testnet (Base Sepolia) first
- [ ] Verify circuit breaker works at thresholds
- [ ] Test with actual TPT (pUSDC) tokens
- [ ] Monitor event emissions for accuracy
- [ ] Audit circuit breaker logic
- [ ] Deploy on Fhenix Helium for FHE testing
- [ ] Integrate with frontend UI
- [ ] Document LP withdrawal mechanism (Phase 2)

---

## References

- [Uniswap v4 Hook Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [ERC-6909 Specification](https://eips.ethereum.org/EIPS/eip-6909)
- [Fhenix FHE Documentation](https://docs.fhenix.zone/)
- [Curve StableSwap Paper](https://curve.fi/files/stableswap-paper.pdf) (for comparison)

---

## Contact & Contributions

**Maintainer:** Brens Protocol Team  
**License:** MIT  
**Version:** 1.0.0 (Plaintext Foundation)

For questions about design decisions, please open a GitHub discussion.
