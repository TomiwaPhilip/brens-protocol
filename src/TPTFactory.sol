// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { TPT } from "./TPT.sol";
import { TPTRegistry } from "./TPTRegistry.sol";

/**
 * @title TPTFactory
 * @notice Factory for deploying TPTs with CREATE2
 */
contract TPTFactory {
    
    TPTRegistry public immutable REGISTRY;
    uint256 public launchFee;
    address public feeRecipient;
    address public owner;
    
    event TPTCreated(
        address indexed tokenAddress,
        address indexed creator,
        bytes32 salt
    );
    event LaunchFeeUpdated(uint256 newFee);
    
    error InsufficientFee();
    error TPTAlreadyExists();
    error Unauthorized();
    error InvalidParameters();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor(address _registry) {
        owner = msg.sender;
        feeRecipient = msg.sender;
        launchFee = 0;
        REGISTRY = TPTRegistry(_registry);
    }
    
    function createTPT(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        bytes32 salt
    ) public payable returns (address tptAddress) {
        if (msg.value < launchFee) revert InsufficientFee();
        if (bytes(name).length == 0 || bytes(symbol).length == 0) {
            revert InvalidParameters();
        }
        
        // Deploy with CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(TPT).creationCode,
            abi.encode(name, symbol, initialSupply, msg.sender)
        );
        
        assembly {
            tptAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(tptAddress)) {
                revert(0, 0)
            }
        }
        
        // Check if already exists
        if (REGISTRY.isTPT(tptAddress)) revert TPTAlreadyExists();
        
        // Register TPT
        REGISTRY.registerTPT(tptAddress, msg.sender, name, symbol, initialSupply);
        
        // Transfer fee if any
        if (msg.value > 0) {
            (bool success, ) = feeRecipient.call{value: msg.value}("");
            require(success, "Fee transfer failed");
        }
        
        emit TPTCreated(tptAddress, msg.sender, salt);
        return tptAddress;
    }
    
    function computeTPTAddress(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address creator,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(TPT).creationCode,
            abi.encode(name, symbol, initialSupply, creator)
        );
        
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := keccak256(add(bytecode, 32), mload(bytecode))
        }
        
        bytes memory data = abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash);
        bytes32 hash;
        assembly {
            hash := keccak256(add(data, 32), mload(data))
        }
        
        return address(uint160(uint256(hash)));
    }
    
    function setLaunchFee(uint256 newFee) external onlyOwner {
        launchFee = newFee;
        emit LaunchFeeUpdated(newFee);
    }
    
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidParameters();
        feeRecipient = newRecipient;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidParameters();
        owner = newOwner;
    }
}
