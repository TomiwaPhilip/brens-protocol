# StealthPoolHook Deployment Checklist

## Pre-Deployment

- [ ] Copy `.env.example` to `.env`
- [ ] Add `PRIVATE_KEY` to `.env` (without 0x prefix)
- [ ] Get testnet ETH from faucets:
  - [ ] Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet  
  - [ ] Arbitrum Sepolia: https://faucet.quicknode.com/arbitrum/sepolia
- [ ] Add RPC URLs to `.env` (or use public RPCs)
- [ ] Add Etherscan API keys for verification (optional)

## Step 1: Deploy StealthPoolHook

### Base Sepolia Deployment

```bash
# This will take 5-15 minutes due to HookMiner searching for valid address
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url base_sepolia \
  --broadcast \
  --verify \
  -vvvv
```

**Save the deployed address!**
- [ ] Copy `StealthPoolHook` address to `.env` as `HOOK_ADDRESS`
- [ ] Note the `Salt` value from output (for reference)
- [ ] Verify deployment on BaseScan: https://sepolia.basescan.org/address/YOUR_HOOK_ADDRESS

### Alternative: Arbitrum Sepolia Deployment

```bash
forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify \
  -vvvv
```

## Step 2: Configure Hook (Optional)

If you want a separate keeper address:

```bash
# Add KEEPER_ADDRESS to .env first
forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook \
  --rpc-url base_sepolia \
  --broadcast \
  -vvvv
```

- [ ] Keeper address set (can be same as owner initially)

## Step 3: Get Test Tokens

You need two ERC20 tokens with `token0 < token1`. Options:

### Option A: Use Existing Testnet Tokens
- Base Sepolia test tokens: Check block explorer
- Ensure you have both tokens in your wallet

### Option B: Deploy Simple Test Tokens

Create a simple ERC20 script or use existing token faucets.

```solidity
// SimpleTestToken.sol
contract TestToken is ERC20 {
    constructor() ERC20("Test Token A", "TTA") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
```

- [ ] Have TOKEN0_ADDRESS (lower address)
- [ ] Have TOKEN1_ADDRESS (higher address)  
- [ ] Add both to `.env`

## Step 4: Initialize Pool

```bash
forge script script/InitializeStealthPool.s.sol:InitializeStealthPool \
  --rpc-url base_sepolia \
  --broadcast \
  -vvvv
```

**Expected Output:**
```
Pool initialized successfully!
Pool ID: 0x...
Public Reserve0: 1000000000000000000000000
Public Reserve1: 1000000000000000000000000
```

- [ ] Pool initialized
- [ ] Note `Pool ID` for reference
- [ ] Verify public reserves show dummy values

## Step 5: Approve Tokens

Before adding liquidity, approve the PoolManager to spend your tokens:

```bash
# Get PoolManager address (Base Sepolia)
POOL_MANAGER=0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829

# Approve token0
cast send $TOKEN0_ADDRESS \
  "approve(address,uint256)" \
  $POOL_MANAGER \
  1000000000000000000000 \
  --rpc-url base_sepolia \
  --private-key $PRIVATE_KEY

# Approve token1
cast send $TOKEN1_ADDRESS \
  "approve(address,uint256)" \
  $POOL_MANAGER \
  1000000000000000000000 \
  --rpc-url base_sepolia \
  --private-key $PRIVATE_KEY
```

- [ ] Token0 approved
- [ ] Token1 approved

## Step 6: Add Liquidity

```bash
# Set liquidity amount in .env
export LIQUIDITY_AMOUNT=1000000000000000000  # 1 token (18 decimals)

forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool \
  --rpc-url base_sepolia \
  --broadcast \
  -vvvv
```

- [ ] Liquidity added successfully
- [ ] Received claim tokens (check PoolManager)

## Verification & Testing

### Check Hook Configuration

```bash
HOOK_ADDRESS=<your_hook_address>

# Check owner
cast call $HOOK_ADDRESS "owner()(address)" --rpc-url base_sepolia

# Check keeper
cast call $HOOK_ADDRESS "keeper()(address)" --rpc-url base_sepolia

# Check swap fee
cast call $HOOK_ADDRESS "SWAP_FEE_BASIS_POINTS()(uint256)" --rpc-url base_sepolia

# Check protocol fee share
cast call $HOOK_ADDRESS "PROTOCOL_FEE_SHARE()(uint256)" --rpc-url base_sepolia
```

- [ ] Owner is correct
- [ ] Keeper is set
- [ ] Fees are as expected (10 bp swap, 10% protocol)

### Check Pool Reserves (Privacy Test)

```bash
# This should return dummy values (1M tokens each)
cast call $HOOK_ADDRESS \
  "getPublicReserves((address,address,uint24,int24,address))(uint256,uint256)" \
  "($TOKEN0_ADDRESS,$TOKEN1_ADDRESS,3000,60,$HOOK_ADDRESS)" \
  --rpc-url base_sepolia
```

Expected: `1000000000000000000000000, 1000000000000000000000000`

- [ ] Public reserves return dummy values ✅

### Check Claim Tokens

```bash
# Get currency IDs
TOKEN0_ID=$(cast call $POOL_MANAGER \
  "currencyToId(address)(uint256)" \
  $TOKEN0_ADDRESS \
  --rpc-url base_sepolia)

TOKEN1_ID=$(cast call $POOL_MANAGER \
  "currencyToId(address)(uint256)" \
  $TOKEN1_ADDRESS \
  --rpc-url base_sepolia)

# Check your claim balances
YOUR_ADDRESS=<your_address>

cast call $POOL_MANAGER \
  "balanceOf(address,uint256)(uint256)" \
  $YOUR_ADDRESS \
  $TOKEN0_ID \
  --rpc-url base_sepolia
```

- [ ] Claim tokens received correctly

## Post-Deployment

### Documentation
- [ ] Note deployed addresses in a file
- [ ] Save deployment transaction hashes
- [ ] Document Pool ID for UI integration

### Security
- [ ] Verify contract on block explorer
- [ ] Test all admin functions (as owner)
- [ ] Test keeper functions (as keeper)
- [ ] Monitor for any unexpected behavior

### Integration
- [ ] Can perform test swaps (via Uniswap v4 interface)
- [ ] Verify privacy (observers see dummy reserves)
- [ ] Test liquidity add/remove
- [ ] Test keeper rebalancing

## Troubleshooting

### HookMiner Timeout
If deployment times out:
- Run again - it will try different salts
- Ensure you have enough gas
- Consider increasing timeout limits

### Hook Address Invalid
- Check that CREATE2_DEPLOYER is correct: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- Ensure no existing code at target address
- Verify hook flags match requirements

### Pool Initialization Failed
- Verify TOKEN0 < TOKEN1
- Check hook address is correct
- Ensure pool doesn't already exist

### Transaction Reverts
- Check gas limits
- Verify approvals are set
- Ensure sufficient token balances
- Check you're using correct role (owner/keeper)

## Next Steps

After successful deployment:

1. **Test Swaps**: Use Uniswap v4 router or custom swap scripts
2. **Monitor Privacy**: Verify external queries always see dummy values
3. **Setup Keeper**: Configure automated rebalancing if needed
4. **UI Integration**: Integrate with your frontend
5. **Mainnet Preparation**: If testing succeeds, prepare for mainnet deployment

## Deployment Record

Network: ________________
Hook Address: ________________
Pool ID: ________________
Token0: ________________
Token1: ________________
Deployment Date: ________________
Deployed By: ________________
Transaction Hash: ________________
