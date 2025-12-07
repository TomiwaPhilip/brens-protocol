# ConstantSumHook Deployments

This document tracks all deployments of the ConstantSumHook protocol across different networks.

## Unichain Sepolia

### Deployment #2 - December 7, 2025 (with Keeper Functionality)

**Contracts:**
- **ConstantSumHook**: `0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888`
- **Token A**: `0x4eccff261b376277C521b25aEdC2446239e777Df` (Token B)
- **Token B**: `0x70F648C883566493fbaaD3D329815eABbDE8AB31` (Token A)
- **SimpleSwapRouter**: `0x0ae5F4aFe70f0A9351D8c0fd017183722437eEdf`
- **Pool Manager**: `0x00B036B58a818B1BC34d502D3fE730Db729e62AC` (Protocol Contract)

**Pool Configuration:**
- **Pool ID**: `0xca8a8c8aff8c5cc19c46c5c4a2ae8d8dc32e28e0e5ecab74c3a3d40ab97d3524`
- **Initial Liquidity**: 10,000 tokens each side
- **Swap Fee**: 0% (pure 1:1 swaps)
- **Circuit Breaker**: 70/30 ratio limit
- **Owner**: `0x4e59b44847b379578588920cA78FbF26c0B4956C` (CREATE2_DEPLOYER)
- **Keeper**: Not set (address(0))

**Features:**
- ✅ 1:1 constant sum pricing
- ✅ Zero swap fees
- ✅ Circuit breaker protection
- ✅ Symmetric liquidity management
- ✅ **NEW: Keeper-based auto-rebalancing**

**Current State:**
- Reserve 0: 10,100 tokens
- Reserve 1: 9,900 tokens
- Status: Active and operational

**Test Swap:**
- Swapped 100 Token A → 100 Token B
- Perfect 1:1 execution with no fees

**Gas Used:** 6,040,646 gas (~0.00061 ETH at 0.101 gwei)

---

### Deployment #1 - December 7, 2025 (Initial)

**Contracts:**
- **ConstantSumHook**: `0xFfFCBDce1Ae3Aca35Bd94996207D5589271f6888`
- **Token A**: `0x11900586D3Fc89dF8B66436e7F460AC51577DcED`
- **Token B**: `0x1388B7EE387e50B3dc76CFfd15aae0db531C78B8`
- **SimpleSwapRouter**: `0x5F00C4dcc1EB251c38936AFccF1A0dEb9d579E46`
- **Pool Manager**: `0x00B036B58a818B1BC34d502D3fE730Db729e62AC`

**Pool Configuration:**
- **Pool ID**: `0x30963638a1b03acdf598ad6263601a180f325c95068822e9559382b85061479e`
- **Initial Liquidity**: 10,000 tokens each side
- **Swap Fee**: 0%
- **Circuit Breaker**: 70/30 ratio limit
- **Owner**: `0x4e59b44847b379578588920cA78FbF26c0B4956C`

**Gas Used:** 5,801,910 gas (~0.00058 ETH at 0.101 gwei)

---

## Network Information

### Unichain Sepolia
- **Chain ID**: 1301
- **RPC URL**: https://sepolia.unichain.org
- **Explorer**: https://unichain-sepolia.blockscout.com
- **Pool Manager**: `0x00B036B58a818B1BC34d502D3fE730Db729e62AC`

---

## Keeper Integration Guide

For the latest deployment with keeper functionality:

### Set Keeper Address
```bash
cast send 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "setKeeper(address)" <KEEPER_ADDRESS> \
  --rpc-url https://sepolia.unichain.org \
  --private-key $PRIVATE_KEY
```

### Check Rebalance Status
```bash
cast call 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "checkRebalanceNeeded((address,address,uint24,int24,address))" \
  "(0x4eccff261b376277C521b25aEdC2446239e777Df,0x70F648C883566493fbaaD3D329815eABbDE8AB31,3000,60,0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888)" \
  --rpc-url https://sepolia.unichain.org
```

### Rebalance Pool
```bash
# First approve tokens to hook
cast send 0x4eccff261b376277C521b25aEdC2446239e777Df \
  "approve(address,uint256)" 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 <AMOUNT> \
  --rpc-url https://sepolia.unichain.org \
  --private-key $KEEPER_PRIVATE_KEY

# Then rebalance
cast send 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "rebalancePool((address,address,uint24,int24,address))" \
  "(0x4eccff261b376277C521b25aEdC2446239e777Df,0x70F648C883566493fbaaD3D329815eABbDE8AB31,3000,60,0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888)" \
  --rpc-url https://sepolia.unichain.org \
  --private-key $KEEPER_PRIVATE_KEY
```

---

## Contract Interactions

### Add Liquidity
```bash
cast send 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "addLiquidity((address,address,uint24,int24,address),uint256)" \
  "(0x4eccff261b376277C521b25aEdC2446239e777Df,0x70F648C883566493fbaaD3D329815eABbDE8AB31,3000,60,0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888)" \
  "1000000000000000000000" \
  --rpc-url https://sepolia.unichain.org \
  --private-key $PRIVATE_KEY
```

### Get Reserves
```bash
cast call 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "getReserves((address,address,uint24,int24,address))" \
  "(0x4eccff261b376277C521b25aEdC2446239e777Df,0x70F648C883566493fbaaD3D329815eABbDE8AB31,3000,60,0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888)" \
  --rpc-url https://sepolia.unichain.org
```

### Update Circuit Breaker
```bash
cast send 0x6145f3Cba8c95A572548e3Cf47C8CEc729CC2888 \
  "setCircuitBreakerThresholds(uint256,uint256)" \
  8000 2000 \
  --rpc-url https://sepolia.unichain.org \
  --private-key $PRIVATE_KEY
```

---

## Version History

- **v2.0** (Dec 7, 2025): Added keeper-based auto-rebalancing, checkRebalanceNeeded view function
- **v1.0** (Dec 7, 2025): Initial deployment with basic CSMM, circuit breaker, and liquidity management

---

## Security Notes

- Owner is set to CREATE2_DEPLOYER (`0x4e59b44847b379578588920cA78FbF26c0B4956C`)
- Consider transferring ownership to a multisig for production
- Keeper address should be a trusted bot or service
- Circuit breaker prevents >70% or <30% reserve ratios
- All liquidity operations use unlock callback pattern for safety

---

## Links

- **Repository**: https://github.com/TomiwaPhilip/brens-protocol
- **Documentation**: [README.md](./README.md)
- **Deployment Scripts**: [script/README.md](./script/README.md)
- **Tests**: [test/ConstantSumHook.t.sol](./test/ConstantSumHook.t.sol)
