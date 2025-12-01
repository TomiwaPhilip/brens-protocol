// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { FHERC20 as BaseFHERC20 } from "../lib/fhenix-contracts/contracts/experimental/token/FHERC20/FHERC20.sol";
import { inEuint128 } from "../lib/fhenix-contracts/contracts/FHE.sol";
import { Permission } from "../lib/fhenix-contracts/contracts/access/Permissioned.sol";

/**
 * @title TPT (Tradeable Private Token)
 * @notice Extended FHERC20 with additional features for Brens Protocol
 * @dev Inherits from official Fhenix FHERC20 and adds:
 * 
 * Additional Features Beyond Base FHERC20:
 * - Selective disclosure via view keys for compliance/auditing
 * - Initial supply minting to creator
 * - Enhanced metadata and events
 * 
 * Inherits from Base FHERC20:
 * - Encrypted balances (euint128) - balances are never visible on-chain
 * - Zero-replacement logic - failed transfers don't revert (prevents balance disclosure)
 * - Encrypted transfers and approvals
 * - Wrap/unwrap between public and private tokens
 * - Wallet UX compatibility with indicated balances
 */
contract TPT is BaseFHERC20 {
    
    // View key registry for compliance (selective disclosure)
    mapping(address => mapping(address => bool)) public viewKeyAuthorizations;
    
    // Events for view key management
    event ViewKeyGranted(address indexed account, address indexed viewer);
    event ViewKeyRevoked(address indexed account, address indexed viewer);
    
    // Errors
    error InvalidAddress();
    error Unauthorized();
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _creator
    ) BaseFHERC20(_name, _symbol) {
        // Mint initial encrypted supply to creator
        if (_initialSupply > 0) {
            inEuint128 memory encryptedSupply;
            encryptedSupply.data = abi.encode(_initialSupply);
            encryptedSupply.securityZone = 0;
            _mintEncrypted(_creator, encryptedSupply);
        }
    }
    
    /**
     * @notice Grant view key access for compliance/auditing
     * @dev Allows designated addresses to view encrypted balances
     */
    function grantViewKey(address viewer) public {
        if (viewer == address(0)) revert InvalidAddress();
        viewKeyAuthorizations[msg.sender][viewer] = true;
        emit ViewKeyGranted(msg.sender, viewer);
    }
    
    /**
     * @notice Revoke view key access
     */
    function revokeViewKey(address viewer) public {
        viewKeyAuthorizations[msg.sender][viewer] = false;
        emit ViewKeyRevoked(msg.sender, viewer);
    }
    
    /**
     * @notice Check if viewer has view key access
     */
    function hasViewKey(address account, address viewer) public view returns (bool) {
        return viewKeyAuthorizations[account][viewer];
    }
    
    /**
     * @notice View balance with view key authorization (for compliance)
     * @dev Only works if account has granted view key to caller
     */
    function viewBalanceWithKey(
        address account,
        Permission memory permission
    ) public view returns (string memory) {
        if (!viewKeyAuthorizations[account][msg.sender]) revert Unauthorized();
        return balanceOfEncrypted(account, permission);
    }
}
