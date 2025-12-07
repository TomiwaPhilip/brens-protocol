// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {ConstantSumHook} from "../src/ConstantSumHook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

contract ConstantSumHookTest is Test, Deployers {
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;

    ConstantSumHook hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo("ConstantSumHook.sol", abi.encode(manager), hookAddress);
        hook = ConstantSumHook(hookAddress);

        (key, ) = initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);

        // Add some initial liquidity through the custom `addLiquidity` function
        // Approve the HOOK address, not the manager, since the hook will call settle
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(
            address(hook),
            1000 ether
        );
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(
            address(hook),
            1000 ether
        );

        hook.addLiquidity(key, 1000e18);
    }

    function test_claimTokenBalances() public view {
        // We add 1000 * (10^18) of liquidity of each token to the CSMM pool
        // The actual tokens will move into the PM
        // But the hook should get equivalent amount of claim tokens for each token
        uint256 token0ClaimId = CurrencyLibrary.toId(currency0);
        uint256 token1ClaimId = CurrencyLibrary.toId(currency1);

        uint256 token0ClaimsBalance = manager.balanceOf(
            address(hook),
            token0ClaimId
        );
        uint256 token1ClaimsBalance = manager.balanceOf(
            address(hook),
            token1ClaimId
        );

        assertEq(token0ClaimsBalance, 1000e18);
        assertEq(token1ClaimsBalance, 1000e18);
    }

    function test_reserves() public view {
        // Check that reserves are tracked correctly
        (uint256 reserve0, uint256 reserve1) = hook.getReserves(key);
        assertEq(reserve0, 1000e18);
        assertEq(reserve1, 1000e18);
    }

    function test_cannotModifyLiquidity() public {
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1e18,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_swap_exactInput_zeroForOne() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Swap exact input 100 Token A -> ~99.9 Token B (0.1% fee)
        uint balanceOfTokenABefore = key.currency0.balanceOfSelf();
        uint balanceOfTokenBBefore = key.currency1.balanceOfSelf();
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );
        uint balanceOfTokenAAfter = key.currency0.balanceOfSelf();
        uint balanceOfTokenBAfter = key.currency1.balanceOfSelf();

        // With no fees: 100 input -> 100 output (1:1)
        assertEq(balanceOfTokenBAfter - balanceOfTokenBBefore, 100e18);
        assertEq(balanceOfTokenABefore - balanceOfTokenAAfter, 100e18);
    }

    function test_swap_exactOutput_zeroForOne() public {

        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Swap for exact output 100 Token B -> need ~100.1 Token A (0.1% fee)
        uint balanceOfTokenABefore = key.currency0.balanceOfSelf();
        uint balanceOfTokenBBefore = key.currency1.balanceOfSelf();
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );
        uint balanceOfTokenAAfter = key.currency0.balanceOfSelf();
        uint balanceOfTokenBAfter = key.currency1.balanceOfSelf();

        assertEq(balanceOfTokenBAfter - balanceOfTokenBBefore, 100e18);
        // With no fees: to get 100 output, need exactly 100 input (1:1)
        assertEq(balanceOfTokenABefore - balanceOfTokenAAfter, 100e18);
    }

    function test_swap_oneForZero() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Swap Token B for Token A
        uint balanceOfTokenABefore = key.currency0.balanceOfSelf();
        uint balanceOfTokenBBefore = key.currency1.balanceOfSelf();
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ZERO_BYTES
        );
        uint balanceOfTokenAAfter = key.currency0.balanceOfSelf();
        uint balanceOfTokenBAfter = key.currency1.balanceOfSelf();

        // With no fees: 100 input -> 100 output (1:1)
        assertEq(balanceOfTokenAAfter - balanceOfTokenABefore, 100e18);
        assertEq(balanceOfTokenBBefore - balanceOfTokenBAfter, 100e18);
    }

    function test_circuitBreaker() public {
        // Swap enough to trigger circuit breaker (70/30 imbalance)
        // Current: 1000/1000 (50/50)
        // Need to get to 70/30: 1400/600 (total 2000)
        // So swap 400 from currency0 to currency1
        
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // First swap should work
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -300e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Second swap should trigger circuit breaker
        vm.expectRevert();
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -200e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );
    }

    function test_circuitBreaker_allowsRebalancing() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Create imbalance (close to 70/30)
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -350e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Swap in opposite direction should still work (rebalancing)
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ZERO_BYTES
        );
    }

    function test_removeLiquidity() public {
        // Remove half the liquidity
        hook.removeLiquidity(key, 500e18);

        // Check reserves updated
        (uint256 reserve0, uint256 reserve1) = hook.getReserves(key);
        assertEq(reserve0, 500e18);
        assertEq(reserve1, 500e18);

        // Check claim tokens burned from hook
        uint256 token0ClaimId = CurrencyLibrary.toId(currency0);
        uint256 token1ClaimId = CurrencyLibrary.toId(currency1);

        uint256 token0ClaimsBalance = manager.balanceOf(
            address(hook),
            token0ClaimId
        );
        uint256 token1ClaimsBalance = manager.balanceOf(
            address(hook),
            token1ClaimId
        );

        // Hook should have 500e18 claims remaining (1000 - 500)
        assertEq(token0ClaimsBalance, 500e18);
        assertEq(token1ClaimsBalance, 500e18);
    }

    function test_addMoreLiquidity() public {
        // Add more liquidity
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(
            address(hook),
            500 ether
        );
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(
            address(hook),
            500 ether
        );

        hook.addLiquidity(key, 500e18);

        // Check reserves updated
        (uint256 reserve0, uint256 reserve1) = hook.getReserves(key);
        assertEq(reserve0, 1500e18);
        assertEq(reserve1, 1500e18);
    }

    function test_ownership() public {
        // Check initial owner
        assertEq(hook.owner(), address(this));

        // Transfer ownership
        address newOwner = address(0x123);
        hook.transferOwnership(newOwner);
        assertEq(hook.owner(), newOwner);

        // Old owner cannot change thresholds
        vm.expectRevert(ConstantSumHook.Unauthorized.selector);
        hook.setCircuitBreakerThresholds(8000, 2000);
    }

    function test_updateCircuitBreaker() public {
        // Update thresholds
        hook.setCircuitBreakerThresholds(8000, 2000);

        assertEq(hook.maxImbalanceRatio(), 8000);
        assertEq(hook.minImbalanceRatio(), 2000);
    }

    function test_setKeeper() public {
        // Initially no keeper set
        assertEq(hook.keeper(), address(0));

        // Set keeper
        address keeper = address(0x456);
        hook.setKeeper(keeper);
        assertEq(hook.keeper(), keeper);

        // Non-owner cannot set keeper
        vm.prank(keeper);
        vm.expectRevert(ConstantSumHook.Unauthorized.selector);
        hook.setKeeper(address(0x789));
    }

    function test_checkRebalanceNeeded() public {
        // Initially balanced pool
        (bool needsRebalance, uint256 amount0ToAdd, uint256 amount1ToAdd) = hook.checkRebalanceNeeded(key);
        assertFalse(needsRebalance);
        assertEq(amount0ToAdd, 0);
        assertEq(amount1ToAdd, 0);

        // Perform swap to create imbalance
        swap(key, true, -100e18, ZERO_BYTES);

        // Check if rebalance needed
        (needsRebalance, amount0ToAdd, amount1ToAdd) = hook.checkRebalanceNeeded(key);
        assertTrue(needsRebalance);
        assertEq(amount0ToAdd, 0);
        assertEq(amount1ToAdd, 200e18); // Need to add 200 to balance (1100 vs 900)
    }

    function test_rebalancePool() public {
        // Set keeper
        address keeper = address(0x456);
        hook.setKeeper(keeper);

        // Mint tokens to keeper
        deal(Currency.unwrap(key.currency0), keeper, 1000e18);
        deal(Currency.unwrap(key.currency1), keeper, 1000e18);

        // Perform swap to create imbalance (1100:900)
        swap(key, true, -100e18, ZERO_BYTES);

        // Verify imbalance
        (uint256 reserve0Before, uint256 reserve1Before) = hook.getReserves(key);
        assertEq(reserve0Before, 1100e18);
        assertEq(reserve1Before, 900e18);

        // Keeper rebalances - approve hook not manager
        vm.startPrank(keeper);
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(address(hook), 1000e18);
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(address(hook), 1000e18);
        hook.rebalancePool(key);
        vm.stopPrank();

        // Verify pool is balanced
        (uint256 reserve0After, uint256 reserve1After) = hook.getReserves(key);
        assertEq(reserve0After, 1100e18);
        assertEq(reserve1After, 1100e18); // Added 200 to currency1
    }

    function test_rebalancePool_ownerCanRebalance() public {
        // Owner can rebalance without being set as keeper
        deal(Currency.unwrap(key.currency0), address(this), 1000e18);
        deal(Currency.unwrap(key.currency1), address(this), 1000e18);

        // Create imbalance
        swap(key, true, -100e18, ZERO_BYTES);

        // Owner rebalances - approve hook not manager
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(address(hook), 1000e18);
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(address(hook), 1000e18);
        hook.rebalancePool(key);

        // Verify balanced
        (uint256 reserve0, uint256 reserve1) = hook.getReserves(key);
        assertEq(reserve0, reserve1);
    }

    function test_rebalancePool_revertsWhenAlreadyBalanced() public {
        // Set keeper
        address keeper = address(0x456);
        hook.setKeeper(keeper);

        // Try to rebalance already balanced pool
        vm.prank(keeper);
        vm.expectRevert(ConstantSumHook.PoolAlreadyBalanced.selector);
        hook.rebalancePool(key);
    }

    function test_rebalancePool_revertsForUnauthorized() public {
        address unauthorized = address(0x999);
        
        // Create imbalance
        swap(key, true, -100e18, ZERO_BYTES);

        // Unauthorized user tries to rebalance
        vm.prank(unauthorized);
        vm.expectRevert(ConstantSumHook.Unauthorized.selector);
        hook.rebalancePool(key);
    }
}

