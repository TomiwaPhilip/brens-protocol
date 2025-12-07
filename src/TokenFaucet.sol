// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenFaucet
 * @notice Distributes test tokens (1000 TokenA + 1000 TokenB) to users
 * @dev Each address can only claim once
 */
contract TokenFaucet is Ownable {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public constant CLAIM_AMOUNT = 1000 ether; // 1000 tokens with 18 decimals
    
    mapping(address => bool) public hasClaimed;
    
    event TokensClaimed(address indexed user, uint256 amountA, uint256 amountB);
    event TokensWithdrawn(address indexed token, uint256 amount);
    
    error AlreadyClaimed();
    error InsufficientBalance();
    error TransferFailed();
    
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    /**
     * @notice Claim 1000 of each token (can only be done once per address)
     */
    function claimTokens() external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        
        if (balanceA < CLAIM_AMOUNT || balanceB < CLAIM_AMOUNT) {
            revert InsufficientBalance();
        }
        
        hasClaimed[msg.sender] = true;
        
        bool successA = tokenA.transfer(msg.sender, CLAIM_AMOUNT);
        bool successB = tokenB.transfer(msg.sender, CLAIM_AMOUNT);
        
        if (!successA || !successB) revert TransferFailed();
        
        emit TokensClaimed(msg.sender, CLAIM_AMOUNT, CLAIM_AMOUNT);
    }
    
    /**
     * @notice Check if an address has already claimed tokens
     */
    function hasUserClaimed(address user) external view returns (bool) {
        return hasClaimed[user];
    }
    
    /**
     * @notice Get remaining token balances in the faucet
     */
    function getRemainingBalances() external view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = tokenA.balanceOf(address(this));
        balanceB = tokenB.balanceOf(address(this));
    }
    
    /**
     * @notice Owner can withdraw tokens in case of emergency
     */
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
        emit TokensWithdrawn(token, amount);
    }
}
