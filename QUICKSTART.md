# Quick Start Guide

## 🚀 Get Started with Brens Protocol TPTs

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup
cd brens-protocol
forge install
```

### Compile Contracts
```bash
forge build
```

### Run Tests
```bash
forge test --gas-report
```

## Deploy to Fhenix Testnet

### 1. Setup Environment
```bash
# Create .env file
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
RPC_URL=https://api.helium.fhenix.zone
EOF

# Load environment
source .env
```

### 2. Deploy Factory
```bash
forge script script/DeployTPTFactory.s.sol:DeployTPTFactory \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

Save the factory address from output.

### 3. Create Your First TPT
```bash
# Set factory address
export FACTORY_ADDRESS=<address_from_previous_step>

# Create a private token
forge script script/DeployTPTFactory.s.sol:CreateSampleTPT \
    --rpc-url $RPC_URL \
    --broadcast
```

## Usage Examples

### In Solidity

```solidity
// Connect to factory
TPTFactory factory = TPTFactory(FACTORY_ADDRESS);

// Create your TPT
address myTPT = factory.createTPT{value: 0.01 ether}(
    "My Private Token",
    "MPT",
    1_000_000 * 10**18,
    keccak256(abi.encodePacked("my-unique-salt", block.timestamp))
);

// Use the TPT
FHERC20 token = FHERC20(myTPT);

// Transfer (amount is encrypted)
token.transferEncrypted(recipient, encryptedAmount);

// Grant auditor access
token.grantViewKey(auditorAddress);
```

### Using Cast (CLI)

```bash
# Create a TPT
cast send $FACTORY_ADDRESS \
    "createTPT(string,string,uint256,bytes32)" \
    "Private Token" "PTK" 1000000000000000000000000 \
    $(cast keccak "my-salt") \
    --value 0.01ether \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Check total TPTs created
cast call $FACTORY_ADDRESS "getTotalTPTs()(uint256)" \
    --rpc-url $RPC_URL

# Get TPT metadata
cast call $FACTORY_ADDRESS \
    "getTPTMetadata(address)((address,address,string,string,uint256,uint256,bool))" \
    $TPT_ADDRESS \
    --rpc-url $RPC_URL
```

## Verify Your TPT

After deployment, verify on Fhenix Explorer:

1. Go to https://explorer.helium.fhenix.zone
2. Search for your factory address
3. View all created TPTs in the transactions

## Common Operations

### Check Creator's TPTs
```bash
cast call $FACTORY_ADDRESS \
    "getCreatorTPTs(address)(address[])" \
    $YOUR_ADDRESS \
    --rpc-url $RPC_URL
```

### Compute Address Before Deployment
```bash
cast call $FACTORY_ADDRESS \
    "computeTPTAddress(string,string,uint256,address,bytes32)(address)" \
    "Token Name" "SYM" 1000000 $CREATOR_ADDRESS $SALT \
    --rpc-url $RPC_URL
```

### Grant View Key to Auditor
```bash
cast send $TPT_ADDRESS \
    "grantViewKey(address)" \
    $AUDITOR_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

## Network Information

### Fhenix Helium Testnet
- **RPC**: https://api.helium.fhenix.zone
- **Chain ID**: 8008135
- **Explorer**: https://explorer.helium.fhenix.zone
- **Faucet**: https://faucet.fhenix.zone

### Get Test Tokens
Visit the faucet to get test FHE tokens for gas fees.

## Troubleshooting

### "Call to non-contract address 0x80"
This means FHE precompile is not available. Make sure you're deploying to Fhenix testnet/mainnet, not a local chain.

### "Insufficient Fee"
Increase the value sent with `createTPT`:
```solidity
factory.createTPT{value: factory.launchFee()}(...)
```

### "TPT Already Exists"
Use a different salt value:
```solidity
bytes32 salt = keccak256(abi.encodePacked("unique-string", block.timestamp));
```

## What's Next?

1. **Create wrapper contracts** to convert public tokens (USDC, ETH) to TPTs
2. **Integrate with UI** (brens-protocol-ui) for no-code launches
3. **Build Dark Pool** using Uniswap v4 hooks
4. **Add more features**:
   - Encrypted vesting
   - Encrypted staking
   - Batch transfers

## Resources

- [Brens Whitepaper](https://docs.google.com/document/d/e/2PACX-1vQMHNT-OZZK3LXuJw_uXoXHWn-kQD8_UvvUIyk69qyuE2DW7z7Zkvn9U-yCETePuYNnjIy2wKi5hWD1/pub)
- [Fhenix Docs](https://docs.fhenix.zone)
- [Full README](./README.md)
- [Implementation Details](./IMPLEMENTATION.md)

---

**Need Help?** Open an issue or reach out on Twitter [@TomiwaPhilip](https://twitter.com/TomiwaPhilip)
