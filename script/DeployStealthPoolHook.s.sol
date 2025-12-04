// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {StealthPoolHook} from "../src/StealthPoolHook.sol";

/**
 * @title DeployStealthPoolHook
 * @notice Deployment script for the StealthPoolHook (Uniswap v4 Hook)
 * @dev Run with: forge script script/DeployStealthPoolHook.s.sol:DeployStealthPoolHook --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployStealthPoolHook is Script {
    // CREATE2 Deployer (deterministic deployment across chains)
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    // Uniswap v4 PoolManager addresses by chain
    // Unichain Sepolia (1301)
    address constant POOLMANAGER_UNICHAIN_SEPOLIA = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
    
    // Base Sepolia (84532)
    address constant POOLMANAGER_BASE_SEPOLIA = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    
    // Arbitrum Sepolia (421614)
    address constant POOLMANAGER_ARBITRUM_SEPOLIA = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        // Get the correct PoolManager for the current chain
        IPoolManager poolManager = getPoolManager();
        console.log("PoolManager:", address(poolManager));

        // Hook must have specific flags encoded in the address
        // Must match the getHookPermissions() in StealthPoolHook.sol
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | 
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        console.log("Required hook flags:", flags);

        bytes memory constructorArgs = abi.encode(poolManager);

        console.log("Mining for hook address...");
        console.log("This may take a while...");

        // Mine a salt that will produce a hook address with the correct flags
        // Use CREATE2_DEPLOYER because Forge's new{salt} uses it automatically
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(StealthPoolHook).creationCode,
            constructorArgs
        );

        console.log("Found valid hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the hook using CREATE2
        // Forge's new{salt: salt} syntax uses CREATE2_DEPLOYER automatically
        StealthPoolHook hook = new StealthPoolHook{salt: salt}(poolManager);
        require(address(hook) == hookAddress, "DeployStealthPoolHook: hook address mismatch");

        console.log("StealthPoolHook deployed at:", address(hook));
        console.log("Owner:", hook.owner());
        console.log("Keeper:", hook.keeper());
        console.log("Swap Fee (basis points):", hook.SWAP_FEE_BASIS_POINTS());
        console.log("Protocol Fee Share (basis points):", hook.PROTOCOL_FEE_SHARE());
        console.log("Max Imbalance Ratio:", hook.maxImbalanceRatio());
        console.log("Min Imbalance Ratio:", hook.minImbalanceRatio());

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("StealthPoolHook:", address(hook));
        console.log("PoolManager:", address(poolManager));
        console.log("Owner (deployer):", deployer);
        console.log("Salt:", vm.toString(salt));
    }

    function getPoolManager() internal view returns (IPoolManager) {
        if (block.chainid == 1301) {
            // Unichain Sepolia
            return IPoolManager(POOLMANAGER_UNICHAIN_SEPOLIA);
        } else if (block.chainid == 84532) {
            // Base Sepolia
            return IPoolManager(POOLMANAGER_BASE_SEPOLIA);
        } else if (block.chainid == 421614) {
            // Arbitrum Sepolia
            return IPoolManager(POOLMANAGER_ARBITRUM_SEPOLIA);
        } else {
            revert("Unsupported chain");
        }
    }
}

/**
 * @title SetupStealthPoolHook
 * @notice Script to configure the deployed StealthPoolHook (optional post-deployment setup)
 * @dev Run with: forge script script/DeployStealthPoolHook.s.sol:SetupStealthPoolHook --rpc-url unichain_sepolia --broadcast
 * 
 * This script is OPTIONAL. Use it to:
 * - Set a different keeper address (default is owner)
 * - Adjust circuit breaker thresholds
 * - Transfer ownership
 * 
 * Required environment variables:
 * - PRIVATE_KEY: Current owner's private key
 * - HOOK_ADDRESS: Deployed StealthPoolHook address
 * - KEEPER_ADDRESS: Address to set as keeper (optional, defaults to msg.sender)
 */
contract SetupStealthPoolHook is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        // Keeper address is optional - if not set, current keeper remains
        address keeperAddress;
        try vm.envAddress("KEEPER_ADDRESS") returns (address addr) {
            keeperAddress = addr;
        } catch {
            keeperAddress = address(0);
        }

        console.log("\n=== Configuring StealthPoolHook ===");
        console.log("Hook Address:", hookAddress);

        vm.startBroadcast(deployerPrivateKey);

        StealthPoolHook hook = StealthPoolHook(hookAddress);

        console.log("\nCurrent Configuration:");
        console.log("Owner:", hook.owner());
        console.log("Keeper:", hook.keeper());
        console.log("Max Imbalance Ratio:", hook.maxImbalanceRatio());
        console.log("Min Imbalance Ratio:", hook.minImbalanceRatio());

        // Set the keeper if a new address was provided
        if (keeperAddress != address(0) && keeperAddress != hook.keeper()) {
            console.log("\nSetting new keeper to:", keeperAddress);
            hook.setKeeper(keeperAddress);
            console.log("[OK] Keeper updated");
        } else {
            console.log("\nNo keeper change requested");
        }

        // Optionally adjust circuit breaker thresholds
        // Uncomment and modify these values if needed:
        // console.log("\nUpdating circuit breaker thresholds...");
        // hook.setCircuitBreakerThresholds(8000, 2000); // 80% max, 20% min
        // console.log("[OK] Circuit breaker thresholds updated");

        vm.stopBroadcast();

        console.log("\n=== Configuration Complete ===");
        console.log("Owner:", hook.owner());
        console.log("Keeper:", hook.keeper());
        console.log("\nNote: You can also use cast commands for individual updates:");
        console.log("  cast send $HOOK_ADDRESS 'setKeeper(address)' $NEW_KEEPER");
        console.log("  cast send $HOOK_ADDRESS 'setCircuitBreakerThresholds(uint256,uint256)' 8000 2000");
    }
}
