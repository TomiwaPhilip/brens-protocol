// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Script.sol";
import "../src/TPTFactory.sol";
import "../src/TPTRegistry.sol";
import "../src/FHERC20.sol";

/**
 * @title DeployTPTFactory
 * @notice Deployment script for the TPT Factory (split architecture)
 * @dev Run with: forge script script/DeployTPTFactory.s.sol:DeployTPTFactory --rpc-url <RPC_URL> --broadcast
 */
contract DeployTPTFactory is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Registry first
        TPTRegistry registry = new TPTRegistry();
        console.log("TPTRegistry deployed at:", address(registry));
        
        // Deploy Factory
        TPTFactory factory = new TPTFactory(address(registry));
        console.log("TPTFactory deployed at:", address(factory));
        
        // Transfer registry ownership to factory
        registry.transferOwnership(address(factory));
        console.log("Registry ownership transferred to factory");
        
        console.log("Owner:", factory.owner());
        console.log("Launch Fee:", factory.launchFee());
        
        vm.stopBroadcast();
    }
}

/**
 * @title CreateSampleTPT
 * @notice Script to create a sample TPT
 * @dev Run with: forge script script/DeployTPTFactory.s.sol:CreateSampleTPT --rpc-url <RPC_URL> --broadcast
 */
contract CreateSampleTPT is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TPTFactory factory = TPTFactory(factoryAddress);
        
        // Create a sample TPT
        string memory name = "Private USD Coin";
        string memory symbol = "pUSDC";
        uint256 initialSupply = 1_000_000 * 10**18; // 1 million tokens
        bytes32 salt = keccak256(abi.encodePacked("brens-pusdc-v1"));
        
        // Compute address before deployment
        address predictedAddress = factory.computeTPTAddress(
            name,
            symbol,
            initialSupply,
            msg.sender,
            salt
        );
        
        console.log("Predicted TPT address:", predictedAddress);
        
        // Create the TPT
        address tptAddress = factory.createTPT{value: factory.launchFee()}(
            name,
            symbol,
            initialSupply,
            salt
        );
        
        console.log("TPT created at:", tptAddress);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Initial Supply:", initialSupply);
        
        // Verify it matches predicted address
        require(tptAddress == predictedAddress, "Address mismatch!");
        
        vm.stopBroadcast();
    }
}

/**
 * @title BatchCreateTPTs
 * @notice Script to batch create multiple TPTs for testing
 */
contract BatchCreateTPTs is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TPTFactory factory = TPTFactory(factoryAddress);
        
        // Prepare batch data
        string[] memory names = new string[](3);
        names[0] = "Private Ethereum";
        names[1] = "Private Bitcoin";
        names[2] = "Private Stable";
        
        string[] memory symbols = new string[](3);
        symbols[0] = "pETH";
        symbols[1] = "pBTC";
        symbols[2] = "pUSD";
        
        uint256[] memory supplies = new uint256[](3);
        supplies[0] = 21_000_000 * 10**18;
        supplies[1] = 21_000_000 * 10**18;
        supplies[2] = 1_000_000_000 * 10**18;
        
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = keccak256("pETH");
        salts[1] = keccak256("pBTC");
        salts[2] = keccak256("pUSD");
        
        // Create each TPT
        console.log("Batch created TPTs:", names.length);
        for (uint256 i = 0; i < names.length; i++) {
            address tptAddress = factory.createTPT{value: factory.launchFee()}(
                names[i],
                symbols[i],
                supplies[i],
                salts[i]
            );
            console.log("TPT", i);
            console.log("Symbol:", symbols[i]);
            console.log("Address:", tptAddress);
        }
        
        vm.stopBroadcast();
    }
}
