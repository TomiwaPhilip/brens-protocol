// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StealthPoolHook} from "../src/StealthPoolHook.sol";

/**
 * @title SwapInStealthPool
 * @notice Script to perform a swap in the StealthPool
 * @dev Run with: forge script script/SwapStealthPool.s.sol:SwapInStealthPool --rpc-url <RPC_URL> --broadcast
 * 
 * Required environment variables:
 * - PRIVATE_KEY: Swapper private key
 * - HOOK_ADDRESS: Deployed StealthPoolHook address
 * - TOKEN0_ADDRESS: Address of token0
 * - TOKEN1_ADDRESS: Address of token1
 * - SWAP_AMOUNT: Amount to swap (in wei)
 * - ZERO_FOR_ONE: true to swap token0 for token1, false for token1 for token0
 */
contract SwapInStealthPool is Script {
    // Uniswap v4 PoolManager addresses by chain
    address constant POOLMANAGER_UNICHAIN_SEPOLIA = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
    address constant POOLMANAGER_BASE_SEPOLIA = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address constant POOLMANAGER_ARBITRUM_SEPOLIA = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;

    function run() public {
        uint256 swapperPrivateKey = vm.envUint("PRIVATE_KEY");
        address swapper = vm.addr(swapperPrivateKey);
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");
        uint256 swapAmount = vm.envUint("SWAP_AMOUNT");
        bool zeroForOne = vm.envBool("ZERO_FOR_ONE");

        console.log("Performing swap in StealthPool");
        console.log("Chain ID:", block.chainid);
        console.log("Swapper:", swapper);
        console.log("Hook:", hookAddress);
        console.log("Swap amount:", swapAmount);
        console.log("Direction:", zeroForOne ? "Token0 -> Token1" : "Token1 -> Token0");

        StealthPoolHook hook = StealthPoolHook(hookAddress);
        IPoolManager poolManager = getPoolManager();

        // Create PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        vm.startBroadcast(swapperPrivateKey);

        // Approve tokens to the hook (the hook will transfer from us)
        console.log("\nApproving tokens to hook...");
        if (zeroForOne) {
            IERC20(token0).approve(hookAddress, swapAmount);
            console.log("Approved", swapAmount, "of token0");
        } else {
            IERC20(token1).approve(hookAddress, swapAmount);
            console.log("Approved", swapAmount, "of token1");
        }

        // Get reserves before swap
        console.log("\n=== Before Swap ===");
        (uint256 reserve0Before, uint256 reserve1Before) = hook.getPublicReserves(poolKey);
        console.log("Public Reserve0:", reserve0Before);
        console.log("Public Reserve1:", reserve1Before);
        console.log("(Note: These are dummy values for privacy)");

        // Check balances before
        uint256 balance0Before = IERC20(token0).balanceOf(swapper);
        uint256 balance1Before = IERC20(token1).balanceOf(swapper);
        console.log("\nSwapper Balance Token0:", balance0Before);
        console.log("Swapper Balance Token1:", balance1Before);

        // Perform swap using the hook's swap function
        // The hook handles the swap internally via beforeSwap
        console.log("\nExecuting swap...");
        
        // We need to call poolManager.swap through the hook
        // Actually, for swaps in v4, we typically use PoolSwapTest or call unlock directly
        // Let me use the unlock pattern similar to addLiquidity
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(swapAmount), // Negative = exact input
            sqrtPriceLimitX96: zeroForOne ? 4295128739 : 1461446703485210103287273052203988822378723970342 // Min/max sqrt price limits
        });

        // Call swap on pool manager
        poolManager.unlock(
            abi.encode(
                poolKey,
                swapParams,
                swapper
            )
        );

        // Get reserves after swap
        console.log("\n=== After Swap ===");
        (uint256 reserve0After, uint256 reserve1After) = hook.getPublicReserves(poolKey);
        console.log("Public Reserve0:", reserve0After);
        console.log("Public Reserve1:", reserve1After);
        console.log("(Note: These are still dummy values)");

        // Check balances after
        uint256 balance0After = IERC20(token0).balanceOf(swapper);
        uint256 balance1After = IERC20(token1).balanceOf(swapper);
        console.log("\nSwapper Balance Token0:", balance0After);
        console.log("Swapper Balance Token1:", balance1After);

        // Calculate deltas
        int256 delta0 = int256(balance0After) - int256(balance0Before);
        int256 delta1 = int256(balance1After) - int256(balance1Before);
        console.log("\n=== Swap Results ===");
        console.log("Token0 Delta:", delta0);
        console.log("Token1 Delta:", delta1);

        vm.stopBroadcast();

        console.log("\n=== Summary ===");
        console.log("Swap completed successfully!");
        console.log("Privacy preserved: reserves remain", reserve0After, "/", reserve1After);
    }

    function getPoolManager() internal view returns (IPoolManager) {
        if (block.chainid == 1301) {
            return IPoolManager(POOLMANAGER_UNICHAIN_SEPOLIA);
        } else if (block.chainid == 84532) {
            return IPoolManager(POOLMANAGER_BASE_SEPOLIA);
        } else if (block.chainid == 421614) {
            return IPoolManager(POOLMANAGER_ARBITRUM_SEPOLIA);
        } else {
            revert("Unsupported chain");
        }
    }
}
