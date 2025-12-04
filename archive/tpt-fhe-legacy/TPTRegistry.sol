// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

/**
 * @title TPTRegistry
 * @notice Separate registry contract to manage TPT metadata and reduce factory size
 */
contract TPTRegistry {
    
    // TPT metadata structure
    struct TPTMetadata {
        address tokenAddress;
        address creator;
        string name;
        string symbol;
        uint64 initialSupply;
        uint256 createdAt;
        bool isVerified;
    }
    
    // Registry storage
    mapping(address => TPTMetadata) public tptRegistry;
    address[] public allTPTs;
    mapping(address => address[]) public creatorTPTs;
    
    address public owner;
    
    event TPTRegistered(address indexed tokenAddress, address indexed creator);
    event TPTVerified(address indexed tokenAddress);
    
    error Unauthorized();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function registerTPT(
        address tokenAddress,
        address creator,
        string memory name,
        string memory symbol,
        uint64 initialSupply
    ) external onlyOwner {
        TPTMetadata memory metadata = TPTMetadata({
            tokenAddress: tokenAddress,
            creator: creator,
            name: name,
            symbol: symbol,
            initialSupply: initialSupply,
            createdAt: block.timestamp,
            isVerified: false
        });
        
        tptRegistry[tokenAddress] = metadata;
        allTPTs.push(tokenAddress);
        creatorTPTs[creator].push(tokenAddress);
        
        emit TPTRegistered(tokenAddress, creator);
    }
    
    function verifyTPT(address tptAddress) external onlyOwner {
        tptRegistry[tptAddress].isVerified = true;
        emit TPTVerified(tptAddress);
    }
    
    function getTPTMetadata(address tptAddress) external view returns (TPTMetadata memory) {
        return tptRegistry[tptAddress];
    }
    
    function getCreatorTPTs(address creator) external view returns (address[] memory) {
        return creatorTPTs[creator];
    }
    
    function getTotalTPTs() external view returns (uint256) {
        return allTPTs.length;
    }
    
    function isTPT(address tokenAddress) external view returns (bool) {
        return tptRegistry[tokenAddress].tokenAddress != address(0);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
