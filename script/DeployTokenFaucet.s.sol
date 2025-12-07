// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TokenFaucet} from "../src/TokenFaucet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployTokenFaucet
 * @notice Deploys TokenFaucet and funds it with 100K of each token
 * @dev Run with: forge script script/DeployTokenFaucet.s.sol:DeployTokenFaucet --rpc-url unichain_sepolia --broadcast
 * 
 * Required environment variables:
 * - PRIVATE_KEY: Deployer's private key
 * - TOKEN_A_ADDRESS: Address of TokenA
 * - TOKEN_B_ADDRESS: Address of TokenB
 */
contract DeployTokenFaucet is Script {
    uint256 constant FUNDING_AMOUNT = 100_000 ether; // 100K tokens with 18 decimals
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address tokenA = vm.envAddress("TOKEN_A_ADDRESS");
        address tokenB = vm.envAddress("TOKEN_B_ADDRESS");
        
        console.log("=== Deployment Configuration ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("TokenA:", tokenA);
        console.log("TokenB:", tokenB);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TokenFaucet
        TokenFaucet faucet = new TokenFaucet(tokenA, tokenB);
        console.log("\n=== Deployed Contract ===");
        console.log("TokenFaucet:", address(faucet));
        
        // Check deployer's token balances
        uint256 balanceA = IERC20(tokenA).balanceOf(deployer);
        uint256 balanceB = IERC20(tokenB).balanceOf(deployer);
        
        console.log("\n=== Deployer Token Balances ===");
        console.log("TokenA Balance:", balanceA / 1e18, "tokens");
        console.log("TokenB Balance:", balanceB / 1e18, "tokens");
        
        require(balanceA >= FUNDING_AMOUNT, "Insufficient TokenA balance");
        require(balanceB >= FUNDING_AMOUNT, "Insufficient TokenB balance");
        
        // Transfer 100K of each token to the faucet
        console.log("\n=== Funding Faucet ===");
        console.log("Transferring", FUNDING_AMOUNT / 1e18, "TokenA...");
        bool successA = IERC20(tokenA).transfer(address(faucet), FUNDING_AMOUNT);
        require(successA, "TokenA transfer failed");
        
        console.log("Transferring", FUNDING_AMOUNT / 1e18, "TokenB...");
        bool successB = IERC20(tokenB).transfer(address(faucet), FUNDING_AMOUNT);
        require(successB, "TokenB transfer failed");
        
        // Verify faucet balances
        (uint256 faucetBalanceA, uint256 faucetBalanceB) = faucet.getRemainingBalances();
        console.log("\n=== Faucet Balances ===");
        console.log("TokenA:", faucetBalanceA / 1e18, "tokens");
        console.log("TokenB:", faucetBalanceB / 1e18, "tokens");
        console.log("Can serve", faucetBalanceA / faucet.CLAIM_AMOUNT(), "users");
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Faucet Address:", address(faucet));
        console.log("Claim Amount: 1000 tokens each");
        console.log("Total Funded: 100,000 tokens each");
        console.log("Max Claims: 100 users");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Add to UI constants:");
        console.log("   FAUCET_ADDRESS:", address(faucet));
        console.log("2. Update DEPLOYMENTS.md");
        console.log("3. Test claiming from UI");
    }
}
