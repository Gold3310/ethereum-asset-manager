// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AssetManager
 * @dev Multi-asset management contract with transfer, balance tracking, and accessibility features
 * @notice This contract manages multiple ERC20 tokens and ETH with comprehensive asset tracking
 */
contract AssetManager is Ownable, ReentrancyGuard {
    
    // ==================== EVENTS ====================
    event AssetAdded(
        string indexed assetId,
        address indexed tokenAddress,
        string symbol,
        uint8 decimals,
        uint256 timestamp
    );
    
    event AssetTransferred(
        string indexed assetId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event BalanceUpdated(
        string indexed assetId,
        address indexed user,
        uint256 newBalance,
        uint256 timestamp
    );
    
    event AssetRemoved(
        string indexed assetId,
        address indexed tokenAddress,
        uint256 timestamp
    );
    
    event AccessibilityUpdated(
        string indexed assetId,
        bool frozen,
        bool paused,
        uint256 timestamp
    );

    // ==================== STRUCTS ====================
    struct Asset {
        string assetId;
        address tokenAddress;
        string symbol;
        uint8 decimals;
        bool exists;
        bool frozen;
        bool paused;
        uint256 totalSupply;
        uint256 addedAt;
    }

    struct UserAsset {
        uint256 balance;
        uint256 lastUpdated;
        uint256 totalTransferred;
        uint256 totalReceived;
    }

    struct AccessibilityInfo {
        string assetId;
        address tokenAddress;
        string symbol;
        uint8 decimals;
        bool frozen;
        bool paused;
        uint256 totalSupply;
        uint256 userBalance;
        uint256 allowance;
        uint256 addedAt;
    }

    // ==================== STATE VARIABLES ====================
    mapping(string => Asset) public assets;
    mapping(address => bool) public supportedTokens;
    mapping(string => mapping(address => UserAsset)) public userAssets;
    
    string[] public assetList;
    uint256 public assetCount;
    
    // Access control
    mapping(address => bool) public managers;
    mapping(string => bool) public assetBlacklist;

    // ==================== MODIFIERS ====================
    modifier onlyManager() {
        require(managers[msg.sender] || msg.sender == owner(), "Only manager");
        _;
    }

    modifier assetExists(string memory _assetId) {
        require(assets[_assetId].exists, "Asset does not exist");
        _;
    }

    modifier notFrozen(string memory _assetId) {
        require(!assets[_assetId].frozen, "Asset is frozen");
        _;
    }

    modifier notPaused(string memory _assetId) {
        require(!assets[_assetId].paused, "Asset is paused");
        _;
    }

    modifier notBlacklisted(string memory _assetId) {
        require(!assetBlacklist[_assetId], "Asset is blacklisted");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    constructor() {
        managers[msg.sender] = true;
    }

    // ==================== ASSET MANAGEMENT ====================
    
    /**
     * @dev Add a new asset to the manager
     * @param _assetId Unique identifier for the asset
     * @param _tokenAddress Address of the ERC20 token
     */
    function addAsset(
        string memory _assetId,
        address _tokenAddress
    ) external onlyManager nonReentrant {
        require(_tokenAddress != address(0), "Invalid token address");
        require(!assets[_assetId].exists, "Asset already exists");
        require(bytes(_assetId).length > 0, "Asset ID cannot be empty");

        IERC20Metadata token = IERC20Metadata(_tokenAddress);
        
        string memory symbol = token.symbol();
        uint8 decimals = token.decimals();
        uint256 totalSupply = token.totalSupply();

        assets[_assetId] = Asset({
            assetId: _assetId,
            tokenAddress: _tokenAddress,
            symbol: symbol,
            decimals: decimals,
            exists: true,
            frozen: false,
            paused: false,
            totalSupply: totalSupply,
            addedAt: block.timestamp
        });

        supportedTokens[_tokenAddress] = true;
        assetList.push(_assetId);
        assetCount++;

        emit AssetAdded(_assetId, _tokenAddress, symbol, decimals, block.timestamp);
    }

    /**
     * @dev Remove an asset from the manager
     * @param _assetId Asset identifier to remove
     */
    function removeAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) nonReentrant {
        Asset storage asset = assets[_assetId];
        
        address tokenAddress = asset.tokenAddress;
        supportedTokens[tokenAddress] = false;
        asset.exists = false;

        assetCount--;

        emit AssetRemoved(_assetId, tokenAddress, block.timestamp);
    }

    // ==================== TRANSFER FUNCTIONS ====================
    
    /**
     * @dev Transfer tokens to a recipient
     * @param _assetId Asset identifier
     * @param _to Recipient address
     * @param _amount Amount to transfer
     */
    function transfer(
        string memory _assetId,
        address _to,
        uint256 _amount
    ) external nonReentrant assetExists(_assetId) notFrozen(_assetId) notPaused(_assetId) notBlacklisted(_assetId) returns (bool) {
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be greater than 0");
        require(userAssets[_assetId][msg.sender].balance >= _amount, "Insufficient balance");

        Asset storage asset = assets[_assetId];
        IERC20 token = IERC20(asset.tokenAddress);

        // Update sender balance
        userAssets[_assetId][msg.sender].balance -= _amount;
        userAssets[_assetId][msg.sender].lastUpdated = block.timestamp;
        userAssets[_assetId][msg.sender].totalTransferred += _amount;

        // Update recipient balance
        userAssets[_assetId][_to].balance += _amount;
        userAssets[_assetId][_to].lastUpdated = block.timestamp;
        userAssets[_assetId][_to].totalReceived += _amount;

        // Execute token transfer
        require(token.transferFrom(msg.sender, _to, _amount), "Transfer failed");

        emit BalanceUpdated(_assetId, msg.sender, userAssets[_assetId][msg.sender].balance, block.timestamp);
        emit BalanceUpdated(_assetId, _to, userAssets[_assetId][_to].balance, block.timestamp);
        emit AssetTransferred(_assetId, msg.sender, _to, _amount, block.timestamp);

        return true;
    }

    /**
     * @dev Batch transfer multiple assets to a recipient
     * @param _assetIds Array of asset identifiers
     * @param _to Recipient address
     * @param _amounts Array of amounts to transfer
     */
    function batchTransfer(
        string[] memory _assetIds,
        address _to,
        uint256[] memory _amounts
    ) external nonReentrant returns (bool) {
        require(_assetIds.length == _amounts.length, "Array length mismatch");
        require(_to != address(0), "Invalid recipient");

        for (uint256 i = 0; i < _assetIds.length; i++) {
            transfer(_assetIds[i], _to, _amounts[i]);
        }

        return true;
    }

    // ==================== BALANCE FUNCTIONS ====================
    
    /**
     * @dev Get user balance for an asset
     * @param _assetId Asset identifier
     * @param _user User address
     */
    function getBalance(
        string memory _assetId,
        address _user
    ) external view assetExists(_assetId) returns (uint256) {
        return userAssets[_assetId][_user].balance;
    }

    /**
     * @dev Get all balances for a user across all assets
     * @param _user User address
     */
    function getUserBalances(address _user) external view returns (
        string[] memory assetIds,
        uint256[] memory balances
    ) {
        assetIds = new string[](assetCount);
        balances = new uint256[](assetCount);

        uint256 index = 0;
        for (uint256 i = 0; i < assetList.length; i++) {
            string memory assetId = assetList[i];
            if (assets[assetId].exists) {
                assetIds[index] = assetId;
                balances[index] = userAssets[assetId][_user].balance;
                index++;
            }
        }

        return (assetIds, balances);
    }

    /**
     * @dev Update user balance (admin function)
     * @param _assetId Asset identifier
     * @param _user User address
     * @param _newBalance New balance amount
     */
    function updateBalance(
        string memory _assetId,
        address _user,
        uint256 _newBalance
    ) external onlyManager assetExists(_assetId) {
        userAssets[_assetId][_user].balance = _newBalance;
        userAssets[_assetId][_user].lastUpdated = block.timestamp;

        emit BalanceUpdated(_assetId, _user, _newBalance, block.timestamp);
    }

    // ==================== ACCESSIBILITY FUNCTIONS ====================
    
    /**
     * @dev Get comprehensive accessibility details for an asset
     * @param _assetId Asset identifier
     * @param _user User address for balance info
     */
    function getAccessibilityInfo(
        string memory _assetId,
        address _user
    ) external view assetExists(_assetId) returns (AccessibilityInfo memory) {
        Asset storage asset = assets[_assetId];
        IERC20 token = IERC20(asset.tokenAddress);

        return AccessibilityInfo({
            assetId: asset.assetId,
            tokenAddress: asset.tokenAddress,
            symbol: asset.symbol,
            decimals: asset.decimals,
            frozen: asset.frozen,
            paused: asset.paused,
            totalSupply: asset.totalSupply,
            userBalance: userAssets[_assetId][_user].balance,
            allowance: token.allowance(_user, address(this)),
            addedAt: asset.addedAt
        });
    }

    /**
     * @dev Get detailed user asset information
     * @param _assetId Asset identifier
     * @param _user User address
     */
    function getUserAssetDetails(
        string memory _assetId,
        address _user
    ) external view assetExists(_assetId) returns (UserAsset memory) {
        return userAssets[_assetId][_user];
    }

    /**
     * @dev Get all assets with their accessibility status
     */
    function getAllAssets() external view returns (Asset[] memory) {
        Asset[] memory allAssets = new Asset[](assetCount);
        uint256 index = 0;

        for (uint256 i = 0; i < assetList.length; i++) {
            string memory assetId = assetList[i];
            if (assets[assetId].exists) {
                allAssets[index] = assets[assetId];
                index++;
            }
        }

        return allAssets;
    }

    // ==================== FREEZE/PAUSE FUNCTIONS ====================
    
    /**
     * @dev Freeze an asset (emergency function)
     * @param _assetId Asset identifier
     */
    function freezeAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) {
        require(!assets[_assetId].frozen, "Asset already frozen");
        assets[_assetId].frozen = true;

        emit AccessibilityUpdated(_assetId, true, assets[_assetId].paused, block.timestamp);
    }

    /**
     * @dev Unfreeze an asset
     * @param _assetId Asset identifier
     */
    function unfreezeAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) {
        require(assets[_assetId].frozen, "Asset not frozen");
        assets[_assetId].frozen = false;

        emit AccessibilityUpdated(_assetId, false, assets[_assetId].paused, block.timestamp);
    }

    /**
     * @dev Pause an asset
     * @param _assetId Asset identifier
     */
    function pauseAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) {
        require(!assets[_assetId].paused, "Asset already paused");
        assets[_assetId].paused = true;

        emit AccessibilityUpdated(_assetId, assets[_assetId].frozen, true, block.timestamp);
    }

    /**
     * @dev Unpause an asset
     * @param _assetId Asset identifier
     */
    function unpauseAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) {
        require(assets[_assetId].paused, "Asset not paused");
        assets[_assetId].paused = false;

        emit AccessibilityUpdated(_assetId, assets[_assetId].frozen, false, block.timestamp);
    }

    // ==================== MANAGER FUNCTIONS ====================
    
    /**
     * @dev Add a manager account
     * @param _manager Manager address
     */
    function addManager(address _manager) external onlyOwner {
        require(_manager != address(0), "Invalid address");
        managers[_manager] = true;
    }

    /**
     * @dev Remove a manager account
     * @param _manager Manager address
     */
    function removeManager(address _manager) external onlyOwner {
        managers[_manager] = false;
    }

    /**
     * @dev Blacklist an asset
     * @param _assetId Asset identifier
     */
    function blacklistAsset(
        string memory _assetId
    ) external onlyManager assetExists(_assetId) {
        assetBlacklist[_assetId] = true;
    }

    /**
     * @dev Remove asset from blacklist
     * @param _assetId Asset identifier
     */
    function removeFromBlacklist(
        string memory _assetId
    ) external onlyManager {
        assetBlacklist[_assetId] = false;
    }

    // ==================== EMERGENCY FUNCTIONS ====================
    
    /**
     * @dev Emergency withdrawal of tokens
     * @param _tokenAddress Token to withdraw
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(
        address _tokenAddress,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        require(_tokenAddress != address(0), "Invalid token");
        IERC20 token = IERC20(_tokenAddress);
        require(token.transfer(msg.sender, _amount), "Withdrawal failed");
    }

    /**
     * @dev Emergency ETH withdrawal
     */
    function emergencyWithdrawETH() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH withdrawal failed");
    }

    // ==================== RECEIVE FUNCTION ====================
    receive() external payable {}
}
