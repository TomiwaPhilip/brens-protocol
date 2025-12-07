// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ConstantSumHook} from "../src/ConstantSumHook.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

// Simple test token
contract TestToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol, 18) {
        _mint(msg.sender, initialSupply);
    }
}

// Simple swap router for testing
contract SimpleSwapRouter {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;

    IPoolManager public immutable poolManager;

    struct SwapCallbackData {
        address sender;
        PoolKey key;
        SwapParams params;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function swap(
        PoolKey memory key,
        SwapParams memory params
    ) external returns (BalanceDelta delta) {
        delta = abi.decode(
            poolManager.unlock(abi.encode(SwapCallbackData({
                sender: msg.sender,
                key: key,
                params: params
            }))),
            (BalanceDelta)
        );
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "Only pool manager");

        SwapCallbackData memory swapData = abi.decode(data, (SwapCallbackData));
        BalanceDelta delta = poolManager.swap(swapData.key, swapData.params, "");

        // Settle the deltas
        if (swapData.params.zeroForOne) {
            if (delta.amount0() < 0) {
                swapData.key.currency0.settle(poolManager, swapData.sender, uint128(-delta.amount0()), false);
            }
            if (delta.amount1() > 0) {
                swapData.key.currency1.take(poolManager, swapData.sender, uint128(delta.amount1()), false);
            }
        } else {
            if (delta.amount1() < 0) {
                swapData.key.currency1.settle(poolManager, swapData.sender, uint128(-delta.amount1()), false);
            }
            if (delta.amount0() > 0) {
                swapData.key.currency0.take(poolManager, swapData.sender, uint128(delta.amount0()), false);
            }
        }

        return abi.encode(delta);
    }
}

contract DeployAndTestComplete is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    IPoolManager poolManager;
    ConstantSumHook hook;
    TestToken tokenA;
    TestToken tokenB;
    SimpleSwapRouter swapRouter;
    PoolKey key;

    function run() external {
        // Get pool manager address for the chain
        address poolManagerAddress = getPoolManager();
        require(poolManagerAddress != address(0), "PoolManager not configured for this chain");
        poolManager = IPoolManager(poolManagerAddress);

        vm.startBroadcast();

        // Step 1: Deploy test tokens
        console.log("\n=== Step 1: Deploying Test Tokens ===");
        tokenA = new TestToken("Token A", "TKA", 1_000_000 ether);
        tokenB = new TestToken("Token B", "TKB", 1_000_000 ether);
        
        // Ensure tokenA < tokenB for Currency ordering
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        
        console.log("Token A deployed:", address(tokenA));
        console.log("Token B deployed:", address(tokenB));
        console.log("Deployer balance A:", tokenA.balanceOf(msg.sender) / 1 ether, "tokens");
        console.log("Deployer balance B:", tokenB.balanceOf(msg.sender) / 1 ether, "tokens");

        // Step 2: Deploy swap router
        console.log("\n=== Step 2: Deploying Swap Router ===");
        swapRouter = new SimpleSwapRouter(poolManager);
        console.log("Swap router deployed:", address(swapRouter));

        // Step 3: Deploy ConstantSumHook with correct address
        console.log("\n=== Step 3: Deploying ConstantSumHook ===");
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        bytes memory constructorArgs = abi.encode(address(poolManager));

        // Mine for hook address with correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(ConstantSumHook).creationCode,
            constructorArgs
        );

        hook = new ConstantSumHook{salt: salt}(poolManager);
        require(address(hook) == hookAddress, "Hook address mismatch");
        
        console.log("ConstantSumHook deployed:", address(hook));
        console.log("Owner:", hook.owner());
        console.log("Max imbalance ratio:", hook.maxImbalanceRatio() / 100, "%");
        console.log("Min imbalance ratio:", hook.minImbalanceRatio() / 100, "%");

        // Step 4: Initialize pool
        console.log("\n=== Step 4: Initializing Pool ===");
        key = PoolKey({
            currency0: Currency.wrap(address(tokenA)),
            currency1: Currency.wrap(address(tokenB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });

        poolManager.initialize(key, TickMath.getSqrtPriceAtTick(0)); // 1:1 price
        PoolId poolId = key.toId();
        console.log("Pool initialized at 1:1 price");
        console.log("Pool ID:", uint256(PoolId.unwrap(poolId)));

        // Step 5: Add liquidity
        console.log("\n=== Step 5: Adding Liquidity ===");
        uint256 liquidityAmount = 10_000 ether;
        
        // Approve hook to spend tokens
        tokenA.approve(address(hook), type(uint256).max);
        tokenB.approve(address(hook), type(uint256).max);
        
        console.log("Adding", liquidityAmount / 1 ether, "of each token...");
        hook.addLiquidity(key, liquidityAmount);
        
        (uint256 reserve0, uint256 reserve1) = hook.getReserves(key);
        console.log("Liquidity added successfully!");
        console.log("  Reserve 0:", reserve0 / 1 ether, "tokens");
        console.log("  Reserve 1:", reserve1 / 1 ether, "tokens");

        // Check claim token balances
        uint256 claimBalance0 = poolManager.balanceOf(address(hook), key.currency0.toId());
        uint256 claimBalance1 = poolManager.balanceOf(address(hook), key.currency1.toId());
        console.log("  Hook claim balance 0:", claimBalance0 / 1 ether, "tokens");
        console.log("  Hook claim balance 1:", claimBalance1 / 1 ether, "tokens");

        // Step 6: Perform swap
        console.log("\n=== Step 6: Performing Swap ===");
        uint256 swapAmount = 100 ether;
        
        uint256 balanceA_before = tokenA.balanceOf(msg.sender);
        uint256 balanceB_before = tokenB.balanceOf(msg.sender);
        console.log("Before swap:");
        console.log("  User balance A:", balanceA_before / 1 ether, "tokens");
        console.log("  User balance B:", balanceB_before / 1 ether, "tokens");

        // Approve swap router
        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        console.log("\nSwapping", swapAmount / 1 ether, "Token A for Token B...");
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(swapAmount), // Negative = exact input
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params);

        uint256 balanceA_after = tokenA.balanceOf(msg.sender);
        uint256 balanceB_after = tokenB.balanceOf(msg.sender);
        
        console.log("\nAfter swap:");
        console.log("  User balance A:", balanceA_after / 1 ether, "tokens");
        console.log("  User balance B:", balanceB_after / 1 ether, "tokens");
        console.log("  Token A spent:", (balanceA_before - balanceA_after) / 1 ether, "tokens");
        console.log("  Token B received:", (balanceB_after - balanceB_before) / 1 ether, "tokens");
        console.log("  Ratio: 1:1 (no fees)");

        // Step 7: Display final state
        console.log("\n=== Step 7: Final State ===");
        (reserve0, reserve1) = hook.getReserves(key);
        console.log("Final reserves:");
        console.log("  Reserve 0:", reserve0 / 1 ether, "tokens");
        console.log("  Reserve 1:", reserve1 / 1 ether, "tokens");
        
        uint256 ratio = (reserve0 * 100) / (reserve0 + reserve1);
        console.log("  Reserve ratio:", ratio);
        console.log("  (approx % split):", ratio, "/", 100 - ratio);

        console.log("\n=== Deployment Summary ===");
        console.log("Network:", getNetworkName());
        console.log("Pool Manager:", address(poolManager));
        console.log("Token A:", address(tokenA));
        console.log("Token A name:", tokenA.name());
        console.log("Token B:", address(tokenB));
        console.log("Token B name:", tokenB.name());
        console.log("Swap Router:", address(swapRouter));
        console.log("ConstantSumHook:", address(hook));
        console.log("Pool ID:", uint256(PoolId.unwrap(poolId)));
        console.log("\nHook Configuration:");
        console.log("  Swap Fee: 0% (pure 1:1 swaps)");
        console.log("  Circuit Breaker: 70/30 ratio limit");
        console.log("  Owner:", hook.owner());

        vm.stopBroadcast();

        console.log("\n=== Next Steps ===");
        console.log("1. Add more liquidity: hook.addLiquidity(key, amount)");
        console.log("2. Remove liquidity: hook.removeLiquidity(key, amount)");
        console.log("3. Perform swaps: swapRouter.swap(key, params)");
        console.log("4. Update circuit breaker: hook.setCircuitBreakerThresholds(maxRatio, minRatio)");
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

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1301) return "Unichain Sepolia";
        if (chainId == 84532) return "Base Sepolia";
        if (chainId == 421614) return "Arbitrum Sepolia";
        if (chainId == 31337) return "Local (Anvil)";
        
        return "Unknown Network";
    }
}
