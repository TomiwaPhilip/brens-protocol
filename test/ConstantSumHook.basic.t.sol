// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ConstantSumHook} from "../src/ConstantSumHook.sol";
import {PoolManager} from "v4-core/PoolManager.sol";

contract ConstantSumHookBasicTest is Test {
    ConstantSumHook hook;
    PoolManager manager;

    function setUp() public {
        manager = new PoolManager(address(this));
        hook = new ConstantSumHook(manager);
    }

    function test_deployment() public view {
        assertEq(address(hook.poolManager()), address(manager));
        assertEq(hook.owner(), address(this));
    }

    function test_circuitBreakerDefaults() public view {
        assertEq(hook.maxImbalanceRatio(), 7000); // 70%
        assertEq(hook.minImbalanceRatio(), 3000); // 30%
    }

    function test_setCircuitBreaker() public {
        hook.setCircuitBreakerThresholds(8000, 2000);
        assertEq(hook.maxImbalanceRatio(), 8000);
        assertEq(hook.minImbalanceRatio(), 2000);
    }

    function test_ownership() public {
        address newOwner = address(0x123);
        hook.transferOwnership(newOwner);
        assertEq(hook.owner(), newOwner);
    }
}
