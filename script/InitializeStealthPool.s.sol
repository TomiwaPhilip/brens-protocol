// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {StealthPoolHook} from "../src/StealthPoolHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title InitializeStealthPool
 * @notice Script to initialize a pool with the StealthPoolHook
 * @dev Run with: forge script script/InitializeStealthPool.s.sol:InitializeStealthPool --rpc-url <RPC_URL> --broadcast
 * 
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - HOOK_ADDRESS: Deployed StealthPoolHook address
 * - TOKEN0_ADDRESS: Address of token0 (must be < token1)
 * - TOKEN1_ADDRESS: Address of token1 (must be > token0)
 */
contract InitializeStealthPool is Script {
    using PoolIdLibrary for PoolKey;

    // Uniswap v4 PoolManager addresses by chain
    address constant POOLMANAGER_UNICHAIN_SEPOLIA = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
    address constant POOLMANAGER_BASE_SEPOLIA = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address constant POOLMANAGER_ARBITRUM_SEPOLIA = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");

        console.log("Initializing pool with StealthPoolHook");
        console.log("Chain ID:", block.chainid);
        console.log("Hook:", hookAddress);
        console.log("Token0:", token0);
        console.log("Token1:", token1);

        require(token0 < token1, "Token0 must be < Token1");

        vm.startBroadcast(deployerPrivateKey);

        StealthPoolHook hook = StealthPoolHook(hookAddress);
        IPoolManager poolManager = getPoolManager();

        // Create PoolKey with 0.3% fee tier (3000) and tick spacing of 60
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        PoolId poolId = poolKey.toId();
        console.log("Pool ID:", vm.toString(PoolId.unwrap(poolId)));

        // Initialize pool at 1:1 price (SQRT_PRICE_1_1)
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        console.log("Pool initialized successfully!");
        console.log("Pool ID:", vm.toString(PoolId.unwrap(poolId)));

        // Get public reserves (should be dummy)
        (uint256 reserve0, uint256 reserve1) = hook.getPublicReserves(poolKey);
        console.log("Public Reserve0:", reserve0);
        console.log("Public Reserve1:", reserve1);
        console.log("(Note: Public reserves are dummy values for privacy)");

        vm.stopBroadcast();

        console.log("\n=== Pool Initialization Summary ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Pool ID:", vm.toString(PoolId.unwrap(poolId)));
        console.log("Hook:", hookAddress);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Fee: 3000 (0.3%)");
        console.log("Tick Spacing: 60");
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

/**
 * @title AddLiquidityToStealthPool
 * @notice Script to add liquidity to a StealthPool
 * @dev Run with: forge script script/InitializeStealthPool.s.sol:AddLiquidityToStealthPool --rpc-url <RPC_URL> --broadcast
 * 
 * Required environment variables:
 * - PRIVATE_KEY: LP private key
 * - HOOK_ADDRESS: Deployed StealthPoolHook address
 * - TOKEN0_ADDRESS: Address of token0
 * - TOKEN1_ADDRESS: Address of token1
 * - LIQUIDITY_AMOUNT: Amount of each token to add (in wei)
 */
contract AddLiquidityToStealthPool is Script {
    function run() public {
        uint256 lpPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");
        uint256 liquidityAmount = vm.envUint("LIQUIDITY_AMOUNT");

        console.log("Adding liquidity to StealthPool");
        console.log("LP:", vm.addr(lpPrivateKey));
        console.log("Hook:", hookAddress);
        console.log("Amount each:", liquidityAmount);

        vm.startBroadcast(lpPrivateKey);

        StealthPoolHook hook = StealthPoolHook(hookAddress);

        // Create PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        // Approve tokens
        // IMPORTANT: Approve the HOOK, not the PoolManager, because the hook calls transferFrom
        IPoolManager poolManager = hook.poolManager();
        
        console.log("Approving tokens to hook...");
        IERC20(token0).approve(hookAddress, liquidityAmount);
        IERC20(token1).approve(hookAddress, liquidityAmount);
        console.log("Tokens approved!");

        console.log("Adding liquidity...");
        hook.addLiquidity(poolKey, liquidityAmount);

        console.log("Liquidity added successfully!");
        console.log("Received claim tokens (check PoolManager balances)");

        vm.stopBroadcast();
    }
}

/**
 * @title RemoveLiquidityFromStealthPool  
 * @notice Script to remove liquidity from a StealthPool
 */
contract RemoveLiquidityFromStealthPool is Script {
    function run() public {
        uint256 lpPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");
        uint256 liquidityAmount = vm.envUint("LIQUIDITY_AMOUNT");

        console.log("Removing liquidity from StealthPool");
        console.log("LP:", vm.addr(lpPrivateKey));
        console.log("Amount each:", liquidityAmount);

        vm.startBroadcast(lpPrivateKey);

        StealthPoolHook hook = StealthPoolHook(hookAddress);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        hook.removeLiquidity(poolKey, liquidityAmount);

        console.log("Liquidity removed successfully!");

        vm.stopBroadcast();
    }
}
