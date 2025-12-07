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

/**
 * @title ConstantSumHook
 * @notice Uniswap v4 hook implementing Constant Sum Market Maker (CSMM) with circuit breaker
 * @dev Implements x+y=k pricing (1:1 swaps) ideal for stablecoin pairs with protective measures
 * 
 * KEY FEATURES:
 * ✅ 1:1 pricing (no slippage on swaps)
 * ✅ 0.1% swap fee (90% to LPs, 10% to protocol)
 * ✅ Circuit breaker (prevents drainage during depegs)
 * ✅ ERC-6909 claim token liquidity management
 * ✅ Owner controls for fee collection and parameter updates
 */
contract ConstantSumHook is BaseHook {
    using CurrencySettler for Currency;

    error AddLiquidityThroughHook();
    error InsufficientLiquidity();
    error ExcessiveImbalance();
    error Unauthorized();

    // Fee configuration
    uint256 public constant SWAP_FEE_BASIS_POINTS = 10; // 0.1% = 10 bps
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant PROTOCOL_FEE_SHARE = 1000; // 10% of swap fees to protocol

    // Circuit breaker: prevent swaps when reserves become too imbalanced
    uint256 public maxImbalanceRatio = 7000; // 70% max (default)
    uint256 public minImbalanceRatio = 3000; // 30% min (default)

    // Access control
    address public owner;

    // Reserve tracking for circuit breaker
    mapping(PoolId => uint256[2]) public reserves;
    mapping(PoolId => bool) public initialized;

    // Protocol fee accumulation (withdrawable by owner)
    mapping(PoolId => uint256[2]) public protocolFees;

    event Swap(
        PoolId indexed poolId,
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount,
        bool zeroForOne
    );

    event LiquidityAdded(
        PoolId indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1
    );

    event LiquidityRemoved(
        PoolId indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1
    );

    struct CallbackData {
        uint256 amountEach;
        PoolKey key;
        address sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(IPoolManager poolManager) BaseHook(poolManager) {
        owner = msg.sender;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: true, // Force custom liquidity function
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true, // Implement CSMM pricing
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true, // Return custom 1:1 deltas
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /**
     * @notice Update circuit breaker thresholds
     * @param newMaxRatio Maximum reserve ratio in basis points (e.g., 7000 = 70%)
     * @param newMinRatio Minimum reserve ratio in basis points (e.g., 3000 = 30%)
     */
    function setCircuitBreakerThresholds(
        uint256 newMaxRatio,
        uint256 newMinRatio
    ) external onlyOwner {
        require(
            newMaxRatio > 5000 && newMaxRatio <= 9500,
            "Max ratio must be 50-95%"
        );
        require(
            newMinRatio >= 500 && newMinRatio < 5000,
            "Min ratio must be 5-50%"
        );
        require(
            newMaxRatio + newMinRatio == BASIS_POINTS_DIVISOR,
            "Ratios must sum to 100%"
        );

        maxImbalanceRatio = newMaxRatio;
        minImbalanceRatio = newMinRatio;
    }

    /**
     * @notice Withdraw accumulated protocol fees
     * @param key Pool key
     */
    function withdrawProtocolFees(PoolKey calldata key) external onlyOwner {
        PoolId poolId = key.toId();
        uint256 fee0 = protocolFees[poolId][0];
        uint256 fee1 = protocolFees[poolId][1];

        if (fee0 > 0) {
            protocolFees[poolId][0] = 0;
            // Burn claim tokens and take real tokens
            key.currency0.settle(poolManager, address(this), fee0, true);
            key.currency0.take(poolManager, owner, fee0, false);
        }
        if (fee1 > 0) {
            protocolFees[poolId][1] = 0;
            key.currency1.settle(poolManager, address(this), fee1, true);
            key.currency1.take(poolManager, owner, fee1, false);
        }
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Get current reserves for a pool
     * @param key Pool key
     * @return reserve0 Amount of currency0
     * @return reserve1 Amount of currency1
     */
    function getReserves(
        PoolKey calldata key
    ) external view returns (uint256 reserve0, uint256 reserve1) {
        PoolId poolId = key.toId();
        return (reserves[poolId][0], reserves[poolId][1]);
    }

    // ========== POOL INITIALIZATION ==========

    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        initialized[poolId] = true;
        return this.beforeInitialize.selector;
    }

    // ========== LIQUIDITY MANAGEMENT ==========

    /**
     * @notice Disable direct liquidity additions through PoolManager
     */
    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal pure override returns (bytes4) {
        revert AddLiquidityThroughHook();
    }

    /**
     * @notice Add symmetric liquidity (equal amounts of both tokens)
     * @param key Pool key
     * @param amountEach Amount of each token to deposit
     */
    function addLiquidity(
        PoolKey calldata key,
        uint256 amountEach
    ) external {
        poolManager.unlock(
            abi.encode(
                CallbackData({
                    amountEach: amountEach,
                    key: key,
                    sender: msg.sender
                })
            )
        );

        emit LiquidityAdded(
            key.toId(),
            msg.sender,
            amountEach,
            amountEach
        );
    }

    /**
     * @notice Remove symmetric liquidity
     * @param key Pool key
     * @param amountEach Amount of each token to withdraw
     */
    function removeLiquidity(
        PoolKey calldata key,
        uint256 amountEach
    ) external {
        PoolId poolId = key.toId();

        // Check hook has sufficient reserves
        if (reserves[poolId][0] < amountEach || reserves[poolId][1] < amountEach) {
            revert InsufficientLiquidity();
        }

        // Update reserves
        reserves[poolId][0] -= amountEach;
        reserves[poolId][1] -= amountEach;

        // Burn claim tokens from hook
        poolManager.burn(address(this), key.currency0.toId(), amountEach);
        poolManager.burn(address(this), key.currency1.toId(), amountEach);

        // Transfer real tokens to user
        key.currency0.take(poolManager, msg.sender, amountEach, false);
        key.currency1.take(poolManager, msg.sender, amountEach, false);

        emit LiquidityRemoved(poolId, msg.sender, amountEach, amountEach);
    }

    /**
     * @notice Callback for unlock() - handles liquidity deposits
     */
    function unlockCallback(
        bytes calldata data
    ) external onlyPoolManager returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        // Settle: transfer tokens from user to PoolManager (creates debit)
        callbackData.key.currency0.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false // Actually transfer tokens, not burn claims
        );
        callbackData.key.currency1.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
        );

        // Take: mint claim tokens to hook (creates credit, balances debit)
        // The hook holds the liquidity as ERC-6909 claim tokens
        callbackData.key.currency0.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true // Mint claim tokens
        );
        callbackData.key.currency1.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
        );

        // Update reserves for circuit breaker
        PoolId poolId = callbackData.key.toId();

        reserves[poolId][0] += callbackData.amountEach;
        reserves[poolId][1] += callbackData.amountEach;

        return "";
    }

    // ========== SWAP LOGIC ==========

    /**
     * @notice Implement 1:1 CSMM pricing with fees and circuit breaker
     */
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        bool isExactInput = params.amountSpecified < 0;

        // Calculate amounts with 0.1% fee
        uint128 absInputAmount;
        uint128 absOutputAmount;
        uint128 feeAmount;

        if (isExactInput) {
            absInputAmount = uint128(uint256(-int256(params.amountSpecified)));
            // Fee = input * 0.1%
            feeAmount = uint128((uint256(absInputAmount) * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR);
            absOutputAmount = absInputAmount - feeAmount; // 1:1 minus fee
        } else {
            absOutputAmount = uint128(uint256(int256(params.amountSpecified)));
            // To get X output, need X / 0.999 input (accounting for 0.1% fee)
            absInputAmount = uint128((uint256(absOutputAmount) * BASIS_POINTS_DIVISOR) / (BASIS_POINTS_DIVISOR - SWAP_FEE_BASIS_POINTS));
            feeAmount = absInputAmount - absOutputAmount;
        }

        // Circuit breaker: check if swap would create excessive imbalance
        _checkCircuitBreaker(poolId, params.zeroForOne, absInputAmount, absOutputAmount);

        // Create BeforeSwapDelta for 1:1 swap
        BeforeSwapDelta beforeSwapDelta;
        if (isExactInput) {
            beforeSwapDelta = toBeforeSwapDelta(int128(absInputAmount), -int128(absOutputAmount));
        } else {
            beforeSwapDelta = toBeforeSwapDelta(-int128(absInputAmount), int128(absOutputAmount));
        }

        // Execute swap and update reserves
        _executeSwap(poolId, key, params.zeroForOne, absInputAmount, absOutputAmount, feeAmount);

        emit Swap(poolId, sender, absInputAmount, absOutputAmount, feeAmount, params.zeroForOne);

        return (this.beforeSwap.selector, beforeSwapDelta, 0);
    }

    /**
     * @notice Check circuit breaker constraints
     */
    function _checkCircuitBreaker(
        PoolId poolId,
        bool zeroForOne,
        uint128 absInputAmount,
        uint128 absOutputAmount
    ) internal view {
        uint256 reserve0 = reserves[poolId][0];
        uint256 reserve1 = reserves[poolId][1];

        uint256 newReserve0;
        uint256 newReserve1;

        if (zeroForOne) {
            if (reserve1 < absOutputAmount) revert InsufficientLiquidity();
            newReserve0 = reserve0 + absInputAmount;
            newReserve1 = reserve1 - absOutputAmount;
        } else {
            if (reserve0 < absOutputAmount) revert InsufficientLiquidity();
            newReserve0 = reserve0 - absOutputAmount;
            newReserve1 = reserve1 + absInputAmount;
        }

        // Check imbalance ratio
        uint256 totalReserves = newReserve0 + newReserve1;
        if (totalReserves > 0) {
            uint256 ratio0 = (newReserve0 * BASIS_POINTS_DIVISOR) / totalReserves;
            if (ratio0 > maxImbalanceRatio || ratio0 < minImbalanceRatio) {
                revert ExcessiveImbalance();
            }
        }
    }

    /**
     * @notice Execute swap and update reserves/fees
     */
    function _executeSwap(
        PoolId poolId,
        PoolKey calldata key,
        bool zeroForOne,
        uint128 absInputAmount,
        uint128 absOutputAmount,
        uint128 feeAmount
    ) internal {
        uint128 protocolFee = uint128((uint256(feeAmount) * PROTOCOL_FEE_SHARE) / BASIS_POINTS_DIVISOR);
        uint128 lpFee = feeAmount - protocolFee;

        if (zeroForOne) {
            // User sells currency0 for currency1
            key.currency0.take(poolManager, address(this), absInputAmount, true);
            key.currency1.settle(poolManager, address(this), absOutputAmount, true);

            reserves[poolId][0] = reserves[poolId][0] + absInputAmount + lpFee;
            reserves[poolId][1] = reserves[poolId][1] - absOutputAmount;
            protocolFees[poolId][0] = protocolFees[poolId][0] + protocolFee;
        } else {
            // User sells currency1 for currency0
            key.currency0.settle(poolManager, address(this), absOutputAmount, true);
            key.currency1.take(poolManager, address(this), absInputAmount, true);

            reserves[poolId][0] = reserves[poolId][0] - absOutputAmount;
            reserves[poolId][1] = reserves[poolId][1] + absInputAmount + lpFee;
            protocolFees[poolId][1] = protocolFees[poolId][1] + protocolFee;
        }
    }
}
