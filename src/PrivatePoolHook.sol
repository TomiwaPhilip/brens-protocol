// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

contract PrivatePoolHook is BaseHook {
    using CurrencySettler for Currency;

    error AddLiquidityThroughHook();
    error InsufficientLiquidity();

    uint256 public constant SWAP_FEE_BASIS_POINTS = 10; // 0.1% fee
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    event HookSwap(
        bytes32 indexed id, // v4 pool id
        address indexed sender, // router of the swap
        int128 amount0,
        int128 amount1,
        uint128 hookLPfeeAmount0,
        uint128 hookLPfeeAmount1
    );

    event HookModifyLiquidity(
        bytes32 indexed id, // v4 pool id
        address indexed sender, // router address
        int128 amount0,
        int128 amount1
    );

    struct CallbackData {
        uint256 amountEach;
        Currency currency0;
        Currency currency1;
        address sender;
    }

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true, // Don't allow adding liquidity normally
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true, // Override how swaps are done
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal pure override returns (bytes4) {
        revert AddLiquidityThroughHook();
    }

    function addLiquidity(PoolKey calldata key, uint256 amountEach) external {
        poolManager.unlock(
            abi.encode(
                CallbackData({
                    amountEach: amountEach,
                    currency0: key.currency0,
                    currency1: key.currency1,
                    sender: msg.sender
                })
            )
        );

        int128 liquidityAmount = int128(uint128(amountEach));
        emit HookModifyLiquidity(
            PoolId.unwrap(key.toId()),
            address(this),
            liquidityAmount,
            liquidityAmount
        );
    }

    function unlockCallback(
        bytes calldata data
    ) external onlyPoolManager returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        callbackData.currency0.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
        );
        callbackData.currency1.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
        );

        callbackData.currency0.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
        );
        callbackData.currency1.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
        );

        return "";
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        bool isExactInput = params.amountSpecified < 0;

        int128 absInputAmount;
        int128 absOutputAmount;
        int128 feeAmount;
        BeforeSwapDelta beforeSwapDelta;
        
        if (isExactInput) {
            // User specifies exact input, hook deducts fee and provides less output
            absInputAmount = int128(-params.amountSpecified);
            feeAmount = int128(uint128((uint128(absInputAmount) * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR));
            absOutputAmount = absInputAmount - feeAmount;

            beforeSwapDelta = toBeforeSwapDelta(
                absInputAmount,
                -absOutputAmount
            );
        } else {
            // User specifies exact output, hook charges more input (includes fee)
            absOutputAmount = int128(params.amountSpecified);
            feeAmount = int128(uint128((uint128(absOutputAmount) * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR));
            absInputAmount = absOutputAmount + feeAmount;

            beforeSwapDelta = toBeforeSwapDelta(
                -absInputAmount,
                absOutputAmount
            );
        }

        // Check hook's claim token balance for output currency
        Currency outputCurrency = params.zeroForOne ? key.currency1 : key.currency0;
        uint256 hookBalance = poolManager.balanceOf(address(this), outputCurrency.toId());
        
        if (hookBalance < uint256(uint128(absOutputAmount))) {
            revert InsufficientLiquidity();
        }

        if (params.zeroForOne) {
            key.currency0.take(
                poolManager,
                address(this),
                uint256(uint128(absInputAmount)),
                true
            );

            key.currency1.settle(
                poolManager,
                address(this),
                uint256(uint128(absOutputAmount)),
                true
            );

            emit HookSwap(
                PoolId.unwrap(key.toId()),
                sender,
                -absInputAmount,
                absOutputAmount,
                uint128(feeAmount),
                0
            );
        } else {
            key.currency0.settle(
                poolManager,
                address(this),
                uint256(uint128(absOutputAmount)),
                true
            );
            key.currency1.take(
                poolManager,
                address(this),
                uint256(uint128(absInputAmount)),
                true
            );

            emit HookSwap(
                PoolId.unwrap(key.toId()),
                sender,
                absOutputAmount,
                -absInputAmount,
                0,
                uint128(feeAmount)
            );
        }

        return (this.beforeSwap.selector, beforeSwapDelta, 0);
    }
}