// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Test.sol";
import "../src/TPT.sol";
import "../src/TPTFactory.sol";
import "../src/TPTRegistry.sol";
import { FHE, inEuint128 } from "../lib/fhenix-contracts/contracts/FHE.sol";

/**
 * @title TPTFactoryTest
 * @notice Comprehensive tests for TPT Factory and TPT tokens
 */
contract TPTFactoryTest is Test {
    
    TPTFactory public factory;
    TPTRegistry public registry;
    address public owner;
    address public user1;
    address public user2;
    address public feeRecipient;
    
    uint256 constant LAUNCH_FEE = 0.01 ether;
    
    event TPTCreated(
        address indexed tokenAddress,
        address indexed creator,
        bytes32 salt
    );
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        feeRecipient = makeAddr("feeRecipient");
        
        // Deploy registry first
        registry = new TPTRegistry();
        
        // Deploy factory
        factory = new TPTFactory(address(registry));
        
        // Transfer registry ownership to factory
        registry.transferOwnership(address(factory));
        
        // Setup fee recipient
        factory.setFeeRecipient(feeRecipient);
        
        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function testDeployFactory() public view {
        assertEq(factory.owner(), owner);
        assertEq(factory.feeRecipient(), feeRecipient);
        assertEq(factory.launchFee(), LAUNCH_FEE);
        assertEq(registry.getTotalTPTs(), 0);
        assertEq(address(factory.registry()), address(registry));
    }
    
    function testCreateTPT() public {
        string memory name = "Private Token";
        string memory symbol = "pTKN";
        uint256 initialSupply = 1_000_000 * 10**18;
        bytes32 salt = keccak256("test-salt");
        
        vm.startPrank(user1);
        
        // Compute predicted address
        address predictedAddress = factory.computeTPTAddress(
            name,
            symbol,
            initialSupply,
            user1,
            salt
        );
        
        // Expect event
        vm.expectEmit(true, true, false, true);
        emit TPTCreated(predictedAddress, user1, salt);
        
        // Create TPT
        address tptAddress = factory.createTPT{value: LAUNCH_FEE}(
            name,
            symbol,
            initialSupply,
            salt
        );
        
        vm.stopPrank();
        
        // Assertions
        assertEq(tptAddress, predictedAddress);
        assertEq(registry.getTotalTPTs(), 1);
        assertTrue(registry.isTPT(tptAddress));
        
        // Check metadata
        TPTRegistry.TPTMetadata memory metadata = registry.getTPTMetadata(tptAddress);
        assertEq(metadata.tokenAddress, tptAddress);
        assertEq(metadata.creator, user1);
        assertEq(metadata.name, name);
        assertEq(metadata.symbol, symbol);
        assertEq(metadata.initialSupply, initialSupply);
        assertFalse(metadata.isVerified);
        
        // Check creator TPTs
        address[] memory creatorTPTs = registry.getCreatorTPTs(user1);
        assertEq(creatorTPTs.length, 1);
        assertEq(creatorTPTs[0], tptAddress);
        
        // Check fee was transferred
        assertEq(feeRecipient.balance, LAUNCH_FEE);
    }
    
    function testCreateTPTWithInsufficientFee() public {
        vm.startPrank(user1);
        
        vm.expectRevert(TPTFactory.InsufficientFee.selector);
        factory.createTPT{value: LAUNCH_FEE - 1}(
            "Test",
            "TST",
            1000,
            bytes32(0)
        );
        
        vm.stopPrank();
    }
    
    function testCreateTPTWithInvalidParameters() public {
        vm.startPrank(user1);
        
        // Empty name
        vm.expectRevert(TPTFactory.InvalidParameters.selector);
        factory.createTPT{value: LAUNCH_FEE}(
            "",
            "TST",
            1000,
            bytes32(0)
        );
        
        // Empty symbol
        vm.expectRevert(TPTFactory.InvalidParameters.selector);
        factory.createTPT{value: LAUNCH_FEE}(
            "Test",
            "",
            1000,
            bytes32(0)
        );
        
        vm.stopPrank();
    }
    
    function testCreateDuplicateTPT() public {
        bytes32 salt = keccak256("duplicate");
        
        vm.startPrank(user1);
        
        // Create first TPT
        factory.createTPT{value: LAUNCH_FEE}(
            "Test",
            "TST",
            1000,
            salt
        );
        
        // Try to create duplicate
        vm.expectRevert(TPTFactory.TPTAlreadyExists.selector);
        factory.createTPT{value: LAUNCH_FEE}(
            "Test",
            "TST",
            1000,
            salt
        );
        
        vm.stopPrank();
    }
    
    function testMultipleCreators() public {
        // User1 creates a TPT
        vm.prank(user1);
        address tpt1 = factory.createTPT{value: LAUNCH_FEE}(
            "Token1",
            "TKN1",
            1000,
            keccak256("user1-token")
        );
        
        // User2 creates a TPT
        vm.prank(user2);
        address tpt2 = factory.createTPT{value: LAUNCH_FEE}(
            "Token2",
            "TKN2",
            2000,
            keccak256("user2-token")
        );
        
        // Check totals
        assertEq(registry.getTotalTPTs(), 2);
        
        // Check creator TPTs
        assertEq(registry.getCreatorTPTs(user1).length, 1);
        assertEq(registry.getCreatorTPTs(user1)[0], tpt1);
        assertEq(registry.getCreatorTPTs(user2).length, 1);
        assertEq(registry.getCreatorTPTs(user2)[0], tpt2);
    }
    
    function testVerifyTPT() public {
        vm.prank(user1);
        address tptAddress = factory.createTPT{value: LAUNCH_FEE}(
            "Test",
            "TST",
            1000,
            bytes32(0)
        );
        
        // Verify TPT as owner (through factory)
        registry.verifyTPT(tptAddress);
        
        TPTRegistry.TPTMetadata memory metadata = registry.getTPTMetadata(tptAddress);
        assertTrue(metadata.isVerified);
    }
    
    function testVerifyTPTUnauthorized() public {
        vm.prank(user1);
        address tptAddress = factory.createTPT{value: LAUNCH_FEE}(
            "Test",
            "TST",
            1000,
            bytes32(0)
        );
        
        // Try to verify as non-owner
        vm.prank(user2);
        vm.expectRevert(TPTRegistry.Unauthorized.selector);
        registry.verifyTPT(tptAddress);
    }
    
    function testSetLaunchFee() public {
        uint256 newFee = 0.05 ether;
        factory.setLaunchFee(newFee);
        assertEq(factory.launchFee(), newFee);
    }
    
    function testSetLaunchFeeUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert(TPTFactory.Unauthorized.selector);
        factory.setLaunchFee(0.05 ether);
    }
    
    function testBatchCreateTPTs() public {
        vm.startPrank(user1);
        
        for (uint256 i = 0; i < 3; i++) {
            factory.createTPT{value: LAUNCH_FEE}(
                string(abi.encodePacked("Token", i)),
                string(abi.encodePacked("TKN", i)),
                1000 * (i + 1),
                keccak256(abi.encodePacked(i))
            );
        }
        
        vm.stopPrank();
        
        assertEq(registry.getTotalTPTs(), 3);
        assertEq(registry.getCreatorTPTs(user1).length, 3);
    }
    
    function testTransferOwnership() public {
        factory.transferOwnership(user1);
        assertEq(factory.owner(), user1);
    }
    
    function testTransferOwnershipUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert(TPTFactory.Unauthorized.selector);
        factory.transferOwnership(user2);
    }
}

/**
 * @title TPTTest
 * @notice Tests for TPT token functionality
 * @dev Note: Some tests are simplified as full FHE testing requires Fhenix runtime
 */
contract TPTTest is Test {
    
    TPT public token;
    address public creator;
    address public user1;
    address public user2;
    
    function setUp() public {
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy token
        vm.prank(creator);
        token = new TPT(
            "Private Token",
            "pTKN",
            1_000_000 * 10**18,
            creator
        );
    }
    
    function testTokenMetadata() public view {
        assertEq(token.name(), "Private Token");
        assertEq(token.symbol(), "pTKN");
        assertEq(token.decimals(), 18);
    }
    
    function testViewKeyManagement() public {
        vm.startPrank(user1);
        
        // Grant view key
        token.grantViewKey(user2);
        assertTrue(token.hasViewKey(user1, user2));
        
        // Revoke view key
        token.revokeViewKey(user2);
        assertFalse(token.hasViewKey(user1, user2));
        
        vm.stopPrank();
    }
    
    function testGrantViewKeyInvalidAddress() public {
        vm.startPrank(user1);
        vm.expectRevert(TPT.InvalidAddress.selector);
        token.grantViewKey(address(0));
        vm.stopPrank();
    }
    
    function testMultipleViewKeys() public {
        vm.startPrank(user1);
        
        address auditor1 = makeAddr("auditor1");
        address auditor2 = makeAddr("auditor2");
        
        token.grantViewKey(auditor1);
        token.grantViewKey(auditor2);
        
        assertTrue(token.hasViewKey(user1, auditor1));
        assertTrue(token.hasViewKey(user1, auditor2));
        
        vm.stopPrank();
    }
}
