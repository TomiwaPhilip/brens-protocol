// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { FHE, euint128, inEuint128 } from "../lib/fhenix-contracts/contracts/FHE.sol";
import { Permissioned, Permission } from "../lib/fhenix-contracts/contracts/access/Permissioned.sol";

/**
 * @title FHERC20
 * @notice Tradeable Private Token (TPT) implementation using Fully Homomorphic Encryption
 * @dev This is the base implementation for all TPTs in the Brens Protocol ecosystem
 * 
 * Key Features:
 * - Encrypted balances (euint128) - balances are never visible on-chain
 * - Zero-replacement logic - failed transfers don't revert (prevents balance disclosure)
 * - Indicated balances - optional range-based balance display for UX
 * - Selective disclosure - view keys for compliance
 */
contract FHERC20 is Permissioned {
    
    // Token metadata
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    
    // Encrypted state
    mapping(address => euint128) internal _encBalances;
    mapping(address => mapping(address => euint128)) internal _allowances;
    euint128 public totalEncryptedSupply;
    
    // Indicated balance ranges for UX (optional)
    enum BalanceRange {
        ZERO,           // 0
        SMALL,          // 0-10
        MEDIUM,         // 10-100
        LARGE,          // 100-1000
        VERY_LARGE,     // 1000-10000
        WHALE           // 10000+
    }
    
    // View key registry for compliance
    mapping(address => mapping(address => bool)) public viewKeyAuthorizations;
    
    // Events
    event Transfer(address indexed from, address indexed to);
    event Approval(address indexed owner, address indexed spender);
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
    ) {
        name = _name;
        symbol = _symbol;
        
        // Initialize with encrypted supply
        if (_initialSupply > 0) {
            euint128 encryptedSupply = FHE.asEuint128(_initialSupply);
            _encBalances[_creator] = encryptedSupply;
            totalEncryptedSupply = encryptedSupply;
            emit Transfer(address(0), _creator);
        }
    }
    
    /**
     * @notice Get encrypted balance of an account
     * @dev Requires permission from the account holder
     */
    function balanceOfEncrypted(
        address account,
        Permission memory permission
    ) public view onlyPermitted(permission, account) returns (string memory) {
        return _encBalances[account].seal(permission.publicKey);
    }
    
    /**
     * @notice Get indicated balance range for UX purposes
     * @dev Returns a range without revealing exact balance
     */
    function getIndicatedBalance(address account) public view returns (BalanceRange) {
        // This would typically use threshold decryption or a separate tracking mechanism
        // For now, returns ZERO as placeholder - to be implemented with threshold FHE
        return BalanceRange.ZERO;
    }
    
    /**
     * @notice Transfer encrypted amount to another address
     * @dev Uses zero-replacement logic - transaction succeeds even if insufficient balance
     */
    function transferEncrypted(
        address to,
        inEuint128 calldata encryptedAmount
    ) public returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        
        euint128 amount = FHE.asEuint128(encryptedAmount);
        _transferImpl(msg.sender, to, amount);
        
        emit Transfer(msg.sender, to);
        return true;
    }
    
    /**
     * @notice Transfer encrypted amount from one address to another (requires allowance)
     */
    function transferFromEncrypted(
        address from,
        address to,
        inEuint128 calldata encryptedAmount
    ) public returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        
        euint128 amount = FHE.asEuint128(encryptedAmount);
        
        // Spend allowance
        euint128 currentAllowance = _allowances[from][msg.sender];
        euint128 spent = FHE.min(currentAllowance, amount);
        _allowances[from][msg.sender] = currentAllowance - spent;
        
        // Transfer the spent amount
        _transferImpl(from, to, spent);
        
        emit Transfer(from, to);
        return true;
    }
    
    /**
     * @notice Approve encrypted spending allowance
     */
    function approveEncrypted(
        address spender,
        inEuint128 calldata encryptedAmount
    ) public returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        
        euint128 amount = FHE.asEuint128(encryptedAmount);
        _allowances[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender);
        return true;
    }
    
    /**
     * @notice Get encrypted allowance
     */
    function allowanceEncrypted(
        address owner,
        address spender,
        Permission calldata permission
    ) public view onlyBetweenPermitted(permission, owner, spender) returns (string memory) {
        return _allowances[owner][spender].seal(permission.publicKey);
    }
    
    /**
     * @notice Internal transfer implementation with zero-replacement logic
     * @dev If sender has insufficient balance, transfers 0 instead of reverting
     */
    function _transferImpl(
        address from,
        address to,
        euint128 amount
    ) internal {
        // Zero-replacement logic: only transfer what the sender actually has
        // If balance < amount, transfer becomes 0 (but transaction doesn't revert)
        euint128 senderBalance = _encBalances[from];
        euint128 amountToSend = FHE.select(
            amount.lte(senderBalance),
            amount,
            FHE.asEuint128(0)
        );
        
        // Update balances
        _encBalances[from] = senderBalance - amountToSend;
        _encBalances[to] = _encBalances[to] + amountToSend;
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
     */
    function viewBalanceWithKey(
        address account,
        Permission memory permission
    ) public view returns (string memory) {
        if (!viewKeyAuthorizations[account][msg.sender]) revert Unauthorized();
        return _encBalances[account].seal(permission.publicKey);
    }
}
