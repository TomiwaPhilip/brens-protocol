// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { TPT } from "../src/TPT.sol";

/**
 * @title DeploySimpleTPT
 * @notice Simple deployment script for testing TPT on Fhenix Helium testnet
 */
contract DeploySimpleTPT is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TPT with fixed supply
        TPT token = new TPT(
            "Private USD Coin",
            "pUSDC",
            1_000_000, // 1M tokens (with 6 decimals like USDC)
            deployer
        );
        
        console.log("TPT deployed at:", address(token));
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        
        vm.stopBroadcast();
    }
}
