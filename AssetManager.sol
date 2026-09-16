// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title AssetManager
 * @dev Multi-asset management contract with deposit, withdrawal, and transfer capabilities
 * @notice Supports ERC20 tokens, provides accessibility features and comprehensive tracking
 */
contract AssetManager is Ownable, ReentrancyGuard, Pausable {
    
    // ============ Structs ============
    
    /**
     * @dev Asset information structure
     */
    struct Asset {
        address tokenAddress;
        string symbol;
        uint8 decimals;
        bool active;
        uint256 totalDeposited;
        uint256 createdAt;
    }
    
    /**
     * @dev User account structure
     */
    struct UserAccount {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 totalTransferred;
        uint256 createdAt;
        bool exists;
    }
    
    /**
     * @dev User asset balance structure
     */
    struct AssetBalance {
        uint256 balance;
        uint256 depositedAmount;
        uint256 withdrawnAmount;
        uint256 lastUpdate;
    }
    
    /**
     * @dev Transaction history structure
     */
    struct Transaction {
        address user;
        address asset;
        uint256 amount;
        string txType; // "DEPOSIT", "WITHDRAW", "TRANSFER"
        uint256 timestamp;
        bool success;
    }
    
    // ============ State Variables ============
    
    mapping(uint256 => Asset) public assets;
    mapping(address => UserAccount) public userAccounts;
    mapping(address => mapping(uint256 => AssetBalance)) public userBalances;
    mapping(uint256 => Transaction[]) public assetTransactionHistory;
    mapping(address => Transaction[]) public userTransactionHistory;
    
    uint256 public assetCounter;
    uint256 public totalUsers;
    
    // Accessibility features
    uint256 public minTransferAmount = 1e6; // Minimum 1 token (6 decimals)
    uint256 public maxTransferAmount = 1e9 * 1e18; // Maximum 1 billion tokens
    bool public requireApproval = false;
    
    // Fee structure
    uint256 public transferFeePercentage = 0; // In basis points (100 = 1%)
    uint256 public collectedFees;
    
    // ============ Events ============
    
    event AssetAdded(
        uint256 indexed assetId,
        address indexed tokenAddress,
        string symbol,
        uint8 decimals
    );
    
    event AssetRemoved(uint256 indexed assetId, address indexed tokenAddress);
    
    event Deposited(
        address indexed user,
        uint256 indexed assetId,
        uint256 amount,
        uint256 timestamp
    );
    
    event Withdrawn(
        address indexed user,
        uint256 indexed assetId,
        uint256 amount,
        uint256 timestamp
    );
    
    event AssetTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed assetId,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event UserAccountCreated(
        address indexed user,
        uint256 timestamp
    );
    
    event AccessibilitySettingUpdated(
        string settingName,
        uint256 newValue
    );
    
    // ============ Modifiers ============
    
    modifier assetExists(uint256 assetId) {
        require(assets[assetId].active, "Asset does not exist");
        _;
    }
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(amount >= minTransferAmount, "Amount below minimum");
        require(amount <= maxTransferAmount, "Amount exceeds maximum");
        _;
    }
    
    modifier userExists(address user) {
        if (!userAccounts[user].exists) {
            userAccounts[user] = UserAccount(0, 0, 0, block.timestamp, true);
            totalUsers++;
            emit UserAccountCreated(user, block.timestamp);
        }
        _;
    }
    
    // ============ Asset Management ============
    
    /**
     * @notice Add a new asset to the platform
     * @param tokenAddress Address of the ERC20 token
     * @param symbol Symbol of the token (e.g., "USDC")
     * @param decimals Decimal places of the token
     */
    function addAsset(
        address tokenAddress,
        string memory symbol,
        uint8 decimals
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(decimals <= 18, "Invalid decimals");
        
        uint256 assetId = assetCounter++;
        
        assets[assetId] = Asset(
            tokenAddress,
            symbol,
            decimals,
            true,
            0,
            block.timestamp
        );
        
        emit AssetAdded(assetId, tokenAddress, symbol, decimals);
    }
    
    /**
     * @notice Remove an asset from the platform
     * @param assetId ID of the asset to remove
     */
    function removeAsset(uint256 assetId) external onlyOwner assetExists(assetId) {
        address tokenAddress = assets[assetId].tokenAddress;
        assets[assetId].active = false;
        
        emit AssetRemoved(assetId, tokenAddress);
    }
    
    /**
     * @notice Get asset details
     * @param assetId ID of the asset
     * @return Asset details
     */
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        require(assets[assetId].active, "Asset does not exist");
        return assets[assetId];
    }
    
    // ============ Deposit Functions ============
    
    /**
     * @notice Deposit tokens into the platform
     * @param assetId ID of the asset to deposit
     * @param amount Amount to deposit
     */
    function deposit(
        uint256 assetId,
        uint256 amount
    ) external nonReentrant whenNotPaused assetExists(assetId) validAmount(amount) userExists(msg.sender) {
        Asset storage asset = assets[assetId];
        IERC20 token = IERC20(asset.tokenAddress);
        
        // Transfer tokens from user to contract
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        // Update balances
        userBalances[msg.sender][assetId].balance += amount;
        userBalances[msg.sender][assetId].depositedAmount += amount;
        userBalances[msg.sender][assetId].lastUpdate = block.timestamp;
        
        // Update user account
        userAccounts[msg.sender].totalDeposited += amount;
        
        // Update asset
        asset.totalDeposited += amount;
        
        // Record transaction
        _recordTransaction(
            msg.sender,
            asset.tokenAddress,
            amount,
            "DEPOSIT",
            assetId,
            true
        );
        
        emit Deposited(msg.sender, assetId, amount, block.timestamp);
    }
    
    /**
     * @notice Deposit using permit (EIP-2612)
     * @param assetId ID of the asset
     * @param amount Amount to deposit
     * @param deadline Permit deadline
     * @param v Signature component
     * @param r Signature component
     * @param s Signature component
     */
    function depositWithPermit(
        uint256 assetId,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused assetExists(assetId) validAmount(amount) userExists(msg.sender) {
        Asset storage asset = assets[assetId];
        IERC20Permit token = IERC20Permit(asset.tokenAddress);
        
        // Use permit to approve
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // Transfer tokens
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        // Update balances
        userBalances[msg.sender][assetId].balance += amount;
        userBalances[msg.sender][assetId].depositedAmount += amount;
        userBalances[msg.sender][assetId].lastUpdate = block.timestamp;
        
        userAccounts[msg.sender].totalDeposited += amount;
        asset.totalDeposited += amount;
        
        _recordTransaction(
            msg.sender,
            asset.tokenAddress,
            amount,
            "DEPOSIT",
            assetId,
            true
        );
        
        emit Deposited(msg.sender, assetId, amount, block.timestamp);
    }
    
    // ============ Withdrawal Functions ============
    
    /**
     * @notice Withdraw tokens from the platform
     * @param assetId ID of the asset to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(
        uint256 assetId,
        uint256 amount
    ) external nonReentrant whenNotPaused assetExists(assetId) validAmount(amount) {
        Asset storage asset = assets[assetId];
        require(
            userBalances[msg.sender][assetId].balance >= amount,
            "Insufficient balance"
        );
        
        IERC20 token = IERC20(asset.tokenAddress);
        
        // Update balances
        userBalances[msg.sender][assetId].balance -= amount;
        userBalances[msg.sender][assetId].withdrawnAmount += amount;
        userBalances[msg.sender][assetId].lastUpdate = block.timestamp;
        
        userAccounts[msg.sender].totalWithdrawn += amount;
        asset.totalDeposited -= amount;
        
        // Transfer tokens to user
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        _recordTransaction(
            msg.sender,
            asset.tokenAddress,
            amount,
            "WITHDRAW",
            assetId,
            true
        );
        
        emit Withdrawn(msg.sender, assetId, amount, block.timestamp);
    }
    
    /**
     * @notice Withdraw all tokens of a specific asset
     * @param assetId ID of the asset
     */
    function withdrawAll(uint256 assetId) external nonReentrant whenNotPaused assetExists(assetId) {
        uint256 balance = userBalances[msg.sender][assetId].balance;
        require(balance > 0, "No balance to withdraw");
        
        withdraw(assetId, balance);
    }
    
    // ============ Transfer Functions ============
    
    /**
     * @notice Transfer tokens to another user
     * @param to Recipient address
     * @param assetId ID of the asset
     * @param amount Amount to transfer
     */
    function transfer(
        address to,
        uint256 assetId,
        uint256 amount
    ) external nonReentrant whenNotPaused assetExists(assetId) validAmount(amount) userExists(to) {
        require(to != address(0), "Invalid recipient");
        require(to != msg.sender, "Cannot transfer to yourself");
        
        Asset storage asset = assets[assetId];
        require(
            userBalances[msg.sender][assetId].balance >= amount,
            "Insufficient balance"
        );
        
        // Calculate fee
        uint256 fee = (amount * transferFeePercentage) / 10000;
        uint256 transferAmount = amount - fee;
        
        // Update sender balance
        userBalances[msg.sender][assetId].balance -= amount;
        userBalances[msg.sender][assetId].lastUpdate = block.timestamp;
        userAccounts[msg.sender].totalTransferred += amount;
        
        // Update recipient balance
        userBalances[to][assetId].balance += transferAmount;
        userBalances[to][assetId].depositedAmount += transferAmount;
        userBalances[to][assetId].lastUpdate = block.timestamp;
        
        // Collect fee
        if (fee > 0) {
            collectedFees += fee;
        }
        
        _recordTransaction(
            msg.sender,
            asset.tokenAddress,
            amount,
            "TRANSFER",
            assetId,
            true
        );
        
        emit AssetTransferred(msg.sender, to, assetId, transferAmount, fee, block.timestamp);
    }
    
    /**
     * @notice Transfer to external address (with withdrawal)
     * @param to Recipient address
     * @param assetId ID of the asset
     * @param amount Amount to transfer
     */
    function transferExternal(
        address to,
        uint256 assetId,
        uint256 amount
    ) external nonReentrant whenNotPaused assetExists(assetId) validAmount(amount) {
        require(to != address(0), "Invalid recipient");
        
        Asset storage asset = assets[assetId];
        require(
            userBalances[msg.sender][assetId].balance >= amount,
            "Insufficient balance"
        );
        
        // Calculate fee
        uint256 fee = (amount * transferFeePercentage) / 10000;
        uint256 transferAmount = amount - fee;
        
        IERC20 token = IERC20(asset.tokenAddress);
        
        // Update sender balance
        userBalances[msg.sender][assetId].balance -= amount;
        userBalances[msg.sender][assetId].withdrawnAmount += amount;
        userBalances[msg.sender][assetId].lastUpdate = block.timestamp;
        
        userAccounts[msg.sender].totalTransferred += amount;
        
        // Collect fee
        if (fee > 0) {
            collectedFees += fee;
        }
        
        // Transfer tokens to recipient
        require(token.transfer(to, transferAmount), "Transfer failed");
        
        _recordTransaction(
            msg.sender,
            asset.tokenAddress,
            amount,
            "TRANSFER",
            assetId,
            true
        );
        
        emit AssetTransferred(msg.sender, to, assetId, transferAmount, fee, block.timestamp);
    }
    
    // ============ Balance Query Functions ============
    
    /**
     * @notice Get user balance for a specific asset
     * @param user User address
     * @param assetId Asset ID
     * @return Balance amount
     */
    function getUserBalance(address user, uint256 assetId) external view returns (uint256) {
        return userBalances[user][assetId].balance;
    }
    
    /**
     * @notice Get complete asset balance details for a user
     * @param user User address
     * @param assetId Asset ID
     * @return AssetBalance struct with all details
     */
    function getUserAssetBalance(address user, uint256 assetId) external view returns (AssetBalance memory) {
        return userBalances[user][assetId];
    }
    
    /**
     * @notice Get all assets balance for a user
     * @param user User address
     * @return balances Array of balances
     * @return assetIds Array of asset IDs
     */
    function getUserAllBalances(address user) external view returns (
        uint256[] memory balances,
        uint256[] memory assetIds
    ) {
        uint256[] memory ids = new uint256[](assetCounter);
        uint256[] memory bals = new uint256[](assetCounter);
        uint256 count = 0;
        
        for (uint256 i = 0; i < assetCounter; i++) {
            if (assets[i].active && userBalances[user][i].balance > 0) {
                ids[count] = i;
                bals[count] = userBalances[user][i].balance;
                count++;
            }
        }
        
        uint256[] memory resultIds = new uint256[](count);
        uint256[] memory resultBals = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            resultIds[i] = ids[i];
            resultBals[i] = bals[i];
        }
        
        return (resultBals, resultIds);
    }
    
    /**
     * @notice Get user account details
     * @param user User address
     * @return UserAccount struct
     */
    function getUserAccount(address user) external view returns (UserAccount memory) {
        return userAccounts[user];
    }
    
    // ============ Transaction History ============
    
    /**
     * @notice Get user transaction history
     * @param user User address
     * @return Array of transactions
     */
    function getUserTransactionHistory(address user) external view returns (Transaction[] memory) {
        return userTransactionHistory[user];
    }
    
    /**
     * @notice Get number of user transactions
     * @param user User address
     * @return Count of transactions
     */
    function getUserTransactionCount(address user) external view returns (uint256) {
        return userTransactionHistory[user].length;
    }
    
    /**
     * @notice Get asset transaction history
     * @param assetId Asset ID
     * @return Array of transactions
     */
    function getAssetTransactionHistory(uint256 assetId) external view returns (Transaction[] memory) {
        return assetTransactionHistory[assetId];
    }
    
    // ============ Accessibility Settings ============
    
    /**
     * @notice Update minimum transfer amount
     * @param newMin New minimum amount
     */
    function setMinTransferAmount(uint256 newMin) external onlyOwner {
        require(newMin > 0, "Minimum must be greater than 0");
        minTransferAmount = newMin;
        emit AccessibilitySettingUpdated("minTransferAmount", newMin);
    }
    
    /**
     * @notice Update maximum transfer amount
     * @param newMax New maximum amount
     */
    function setMaxTransferAmount(uint256 newMax) external onlyOwner {
        require(newMax > minTransferAmount, "Maximum must be greater than minimum");
        maxTransferAmount = newMax;
        emit AccessibilitySettingUpdated("maxTransferAmount", newMax);
    }
    
    /**
     * @notice Set transfer fee percentage
     * @param feePercentage Fee in basis points (100 = 1%)
     */
    function setTransferFee(uint256 feePercentage) external onlyOwner {
        require(feePercentage <= 10000, "Fee cannot exceed 100%");
        transferFeePercentage = feePercentage;
        emit AccessibilitySettingUpdated("transferFeePercentage", feePercentage);
    }
    
    /**
     * @notice Withdraw collected fees
     * @param assetId Asset ID to withdraw fees in
     */
    function withdrawCollectedFees(uint256 assetId) external onlyOwner {
        require(assetId < assetCounter, "Asset does not exist");
        require(collectedFees > 0, "No fees collected");
        
        Asset storage asset = assets[assetId];
        IERC20 token = IERC20(asset.tokenAddress);
        
        uint256 feesToWithdraw = collectedFees;
        collectedFees = 0;
        
        require(token.transfer(owner(), feesToWithdraw), "Fee withdrawal failed");
    }
    
    /**
     * @notice Pause contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ Statistics ============
    
    /**
     * @notice Get platform statistics
     * @return totalAssetsCount Number of active assets
     * @return totalUsersCount Number of users
     * @return totalFeesCollected Total fees collected
     */
    function getPlatformStats() external view returns (
        uint256 totalAssetsCount,
        uint256 totalUsersCount,
        uint256 totalFeesCollected
    ) {
        uint256 activeAssets = 0;
        for (uint256 i = 0; i < assetCounter; i++) {
            if (assets[i].active) {
                activeAssets++;
            }
        }
        
        return (activeAssets, totalUsers, collectedFees);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Record a transaction
     * @param user User address
     * @param asset Asset address
     * @param amount Amount
     * @param txType Transaction type
     * @param assetId Asset ID
     * @param success Whether transaction succeeded
     */
    function _recordTransaction(
        address user,
        address asset,
        uint256 amount,
        string memory txType,
        uint256 assetId,
        bool success
    ) internal {
        Transaction memory tx = Transaction(
            user,
            asset,
            amount,
            txType,
            block.timestamp,
            success
        );
        
        userTransactionHistory[user].push(tx);
        assetTransactionHistory[assetId].push(tx);
    }
    
    /**
     * @notice Emergency withdrawal (only by owner)
     * @param tokenAddress Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(owner(), amount), "Emergency withdrawal failed");
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
}
