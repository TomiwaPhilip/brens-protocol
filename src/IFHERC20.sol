// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { inEuint128 } from "../lib/fhenix-contracts/contracts/FHE.sol";
import { Permission } from "../lib/fhenix-contracts/contracts/access/Permissioned.sol";

/**
 * @title IFHERC20
 * @notice Interface for Tradeable Private Token (TPT) standard
 */
interface IFHERC20 {
    
    // Token metadata
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    
    // Core TPT functions
    function balanceOfEncrypted(address account, Permission memory permission) external view returns (string memory);
    function transferEncrypted(address to, inEuint128 calldata encryptedAmount) external returns (bool);
    function transferFromEncrypted(address from, address to, inEuint128 calldata encryptedAmount) external returns (bool);
    function approveEncrypted(address spender, inEuint128 calldata encryptedAmount) external returns (bool);
    function allowanceEncrypted(address owner, address spender, Permission calldata permission) external view returns (string memory);
    
    // View key management
    function grantViewKey(address viewer) external;
    function revokeViewKey(address viewer) external;
    function hasViewKey(address account, address viewer) external view returns (bool);
    function viewBalanceWithKey(address account, Permission memory permission) external view returns (string memory);
    
    // Events
    event Transfer(address indexed from, address indexed to);
    event Approval(address indexed owner, address indexed spender);
    event ViewKeyGranted(address indexed account, address indexed viewer);
    event ViewKeyRevoked(address indexed account, address indexed viewer);
}
