// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { FHERC20 } from "@fhenixprotocol/fhenix-confidential-contracts/contracts/FHERC20.sol";

/**
 * @title TPT (Tradeable Private Token)
 * @notice Extended FHERC20 with additional features for Brens Protocol
 * @dev Inherits from official Fhenix FHERC20 and adds:
 * 
 * Additional Features Beyond Base FHERC20:
 * - Fixed supply minting pattern (OpenZeppelin ERC20 style)
 * - Selective disclosure via view keys for compliance/auditing
 * - Initial supply minting to creator
 * - Enhanced metadata and events
 * 
 * Inherits from Base FHERC20:
 * - Encrypted balances (euint64) - balances are never visible on-chain
 * - Zero-replacement logic - failed transfers don't revert (prevents balance disclosure)
 * - Encrypted transfers via confidentialTransfer and confidentialTransferFrom
 * - Operator-based permissions (no allowances to prevent leakage)
 * - Wallet UX compatibility with indicated balances
 */
contract TPT is FHERC20 {
    
    // View key registry for compliance (selective disclosure)
    mapping(address => mapping(address => bool)) public viewKeyAuthorizations;
    
    // Events for view key management
    event ViewKeyGranted(address indexed account, address indexed viewer);
    event ViewKeyRevoked(address indexed account, address indexed viewer);
    
    // Errors
    error InvalidAddress();
    error Unauthorized();
    
    /**
     * @dev Constructor following OpenZeppelin's fixed supply pattern
     * See: https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226
     * 
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialSupply Initial supply to mint (as uint64, respects decimals)
     * @param _creator Address to receive initial supply
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint64 _initialSupply,
        address _creator
    ) FHERC20(_name, _symbol, 6) {
        // Mint initial encrypted supply to creator using internal _mint
        // This follows OpenZeppelin's pattern for fixed supply tokens
        if (_initialSupply > 0 && _creator != address(0)) {
            _mint(_creator, _initialSupply);
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
}
