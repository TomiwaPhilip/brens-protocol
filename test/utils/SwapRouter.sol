// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

contract SwapRouter {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    struct SwapTestSettings {
        bool takeClaims;
        bool settleUsingBurn;
    }

    struct CallbackData {
        address sender;
        SwapTestSettings testSettings;
        PoolKey key;
        SwapParams params;
        bytes hookData;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        bool zeroForOne,
        PoolKey memory poolKey,
        bytes memory hookData,
        address receiver,
        uint256 deadline
    ) external returns (BalanceDelta swapDelta) {
        require(block.timestamp <= deadline, "Transaction too old");

        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });

        SwapTestSettings memory testSettings = SwapTestSettings({takeClaims: false, settleUsingBurn: false});

        swapDelta = abi.decode(
            poolManager.unlock(
                abi.encode(CallbackData(msg.sender, testSettings, poolKey, params, hookData))
            ),
            (BalanceDelta)
        );

        uint256 amountOut = zeroForOne ? uint256(int256(-swapDelta.amount1())) : uint256(int256(-swapDelta.amount0()));
        require(amountOut >= amountOutMin, "Insufficient output amount");

        return swapDelta;
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(poolManager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        BalanceDelta delta = poolManager.swap(data.key, data.params, data.hookData);

        if (data.params.zeroForOne) {
            if (delta.amount0() < 0) {
                _settle(data.key.currency0, data.sender, uint256(int256(-delta.amount0())));
            }
            if (delta.amount1() > 0) {
                _take(data.key.currency1, data.sender, uint256(int256(delta.amount1())));
            }
        } else {
            if (delta.amount1() < 0) {
                _settle(data.key.currency1, data.sender, uint256(int256(-delta.amount1())));
            }
            if (delta.amount0() > 0) {
                _take(data.key.currency0, data.sender, uint256(int256(delta.amount0())));
            }
        }

        return abi.encode(delta);
    }

    function _settle(Currency currency, address sender, uint256 amount) internal {
        poolManager.sync(currency);
        IERC20Minimal(Currency.unwrap(currency)).transferFrom(sender, address(poolManager), amount);
        poolManager.settle();
    }

    function _take(Currency currency, address sender, uint256 amount) internal {
        poolManager.take(currency, sender, amount);
    }
}
