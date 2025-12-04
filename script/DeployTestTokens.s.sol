// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

/**
 * @title TestToken
 * @notice Simple ERC20 token for testing
 */
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol, 18) 
    {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }
}

/**
 * @title DeployTestTokens
 * @notice Deploy two test tokens for StealthPool testing
 * @dev Run with: forge script script/DeployTestTokens.s.sol:DeployTestTokens --rpc-url unichain_sepolia --broadcast
 */
contract DeployTestTokens is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy two test tokens
        TestToken tokenA = new TestToken("Test Token A", "TTA");
        TestToken tokenB = new TestToken("Test Token B", "TTB");
        
        console.log("\n=== Deployed Tokens ===");
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        
        // Sort addresses (Uniswap requires token0 < token1)
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        console.log("\n=== Sorted Addresses (for PoolKey) ===");
        console.log("TOKEN0:", token0);
        console.log("TOKEN1:", token1);
        
        // Check balances
        console.log("\n=== Token Balances ===");
        console.log("TTA Balance:", tokenA.balanceOf(deployer));
        console.log("TTB Balance:", tokenB.balanceOf(deployer));
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Export these addresses:");
        console.log("   export TOKEN0_ADDRESS=" , token0);
        console.log("   export TOKEN1_ADDRESS=" , token1);
        console.log("2. Initialize your pool with InitializeStealthPool script");
        console.log("3. Approve PoolManager before adding liquidity");
    }
}
