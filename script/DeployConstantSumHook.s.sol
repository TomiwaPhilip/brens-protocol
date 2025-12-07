// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ConstantSumHook} from "../src/ConstantSumHook.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployConstantSumHook is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() external {
        // Get pool manager address for the chain
        address poolManager = getPoolManager();
        require(poolManager != address(0), "PoolManager not configured for this chain");

        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        bytes memory constructorArgs = abi.encode(poolManager);

        // Mine for hook address with correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(ConstantSumHook).creationCode,
            constructorArgs
        );

        vm.broadcast();
        ConstantSumHook hook = new ConstantSumHook{salt: salt}(IPoolManager(poolManager));
        
        require(address(hook) == hookAddress, "Hook address mismatch");
        
        console.log("Deployed ConstantSumHook at:", address(hook));
        console.log("Owner:", hook.owner());
    }

    function getPoolManager() internal view returns (address) {
        uint256 chainId = block.chainid;
        
        // Unichain Sepolia
        if (chainId == 1301) {
            return 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
        }
        // Base Sepolia  
        if (chainId == 84532) {
            return 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
        }
        // Arbitrum Sepolia
        if (chainId == 421614) {
            return 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;
        }
        
        return address(0);
    }
}
