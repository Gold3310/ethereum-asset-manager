// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IAssetManager {
    event AssetAdded(address indexed tokenAddress, string symbol, uint8 decimals);
    event AssetRemoved(address indexed tokenAddress);
    event DepositMade(address indexed user, address indexed token, uint256 amount);
    event WithdrawalMade(address indexed user, address indexed token, uint256 amount);
    event TransferMade(address indexed from, address indexed to, address indexed token, uint256 amount);
    event InterestUpdated(address indexed token, uint256 newRate);

    function addAsset(address tokenAddress, string memory symbol, uint8 decimals) external;
    function removeAsset(address tokenAddress) external;
    function deposit(address tokenAddress, uint256 amount) external;
    function withdraw(address tokenAddress, uint256 amount) external;
    function transfer(address tokenAddress, address recipient, uint256 amount) external;
    function getBalance(address user, address tokenAddress) external view returns (uint256);
    function getTotalAssets() external view returns (uint256);
    function getAssetInfo(address tokenAddress) external view returns (string memory, uint8);
}

contract AssetManager is IAssetManager, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Asset {
        address tokenAddress;
        string symbol;
        uint8 decimals;
        bool active;
        uint256 totalDeposited;
        uint256 interestRate; // in basis points (1% = 100)
    }

    struct UserBalance {
        uint256 amount;
        uint256 depositTime;
        uint256 lastWithdrawalTime;
        uint256 accumulatedInterest;
    }

    mapping(address => Asset) public assets;
    mapping(bytes32 => bool) public assetExists;
    mapping(address => mapping(address => UserBalance)) public userBalances;
    mapping(address => address[]) public userAssets;

    address[] public assetList;
    uint256 public totalAssetsCount;
    uint256 public minimumDepositAmount = 1e6; // 1 token with 6 decimals

    constructor() {}

    // ==================== Admin Functions ====================

    /**
     * @dev Add a new asset to the manager
     * @param tokenAddress Address of the ERC20 token
     * @param symbol Token symbol
     * @param decimals Token decimals
     */
    function addAsset(
        address tokenAddress,
        string memory symbol,
        uint8 decimals
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(decimals <= 18, "Invalid decimals");
        require(bytes(symbol).length > 0, "Invalid symbol");

        bytes32 assetKey = keccak256(abi.encodePacked(tokenAddress));
        require(!assetExists[assetKey], "Asset already exists");

        assets[tokenAddress] = Asset({
            tokenAddress: tokenAddress,
            symbol: symbol,
            decimals: decimals,
            active: true,
            totalDeposited: 0,
            interestRate: 0
        });

        assetExists[assetKey] = true;
        assetList.push(tokenAddress);
        totalAssetsCount++;

        emit AssetAdded(tokenAddress, symbol, decimals);
    }

    /**
     * @dev Remove an asset from the manager
     * @param tokenAddress Address of the token to remove
     */
    function removeAsset(address tokenAddress) external onlyOwner {
        require(assets[tokenAddress].active, "Asset not found");

        assets[tokenAddress].active = false;
        bytes32 assetKey = keccak256(abi.encodePacked(tokenAddress));
        assetExists[assetKey] = false;
        totalAssetsCount--;

        emit AssetRemoved(tokenAddress);
    }

    /**
     * @dev Set interest rate for an asset
     * @param tokenAddress Address of the token
     * @param interestRate Interest rate in basis points
     */
    function setInterestRate(address tokenAddress, uint256 interestRate)
        external
        onlyOwner
    {
        require(assets[tokenAddress].active, "Asset not found");
        require(interestRate <= 10000, "Interest rate too high"); // Max 100%

        assets[tokenAddress].interestRate = interestRate;
        emit InterestUpdated(tokenAddress, interestRate);
    }

    /**
     * @dev Set minimum deposit amount
     * @param amount Minimum deposit in wei
     */
    function setMinimumDeposit(uint256 amount) external onlyOwner {
        minimumDepositAmount = amount;
    }

    /**
     * @dev Pause all transactions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Resume all transactions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================== User Functions ====================

    /**
     * @dev Deposit tokens to the contract
     * @param tokenAddress Address of the token to deposit
     * @param amount Amount to deposit
     */
    function deposit(address tokenAddress, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        require(assets[tokenAddress].active, "Asset not supported");
        require(amount >= minimumDepositAmount, "Amount below minimum");
        require(amount > 0, "Amount must be positive");

        IERC20 token = IERC20(tokenAddress);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Transfer tokens from user to contract
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Update user balance
        if (userBalances[msg.sender][tokenAddress].amount == 0) {
            userAssets[msg.sender].push(tokenAddress);
        }

        userBalances[msg.sender][tokenAddress].amount += amount;
        userBalances[msg.sender][tokenAddress].depositTime = block.timestamp;
        assets[tokenAddress].totalDeposited += amount;

        emit DepositMade(msg.sender, tokenAddress, amount);
    }

    /**
     * @dev Withdraw tokens from the contract
     * @param tokenAddress Address of the token to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address tokenAddress, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        require(assets[tokenAddress].active, "Asset not supported");
        require(
            userBalances[msg.sender][tokenAddress].amount >= amount,
            "Insufficient balance"
        );
        require(amount > 0, "Amount must be positive");

        // Calculate and add interest
        uint256 interest = calculateInterest(msg.sender, tokenAddress);
        userBalances[msg.sender][tokenAddress].accumulatedInterest += interest;

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Transfer failed");

        userBalances[msg.sender][tokenAddress].amount -= amount;
        userBalances[msg.sender][tokenAddress].lastWithdrawalTime = block.timestamp;
        assets[tokenAddress].totalDeposited -= amount;

        emit WithdrawalMade(msg.sender, tokenAddress, amount);
    }

    /**
     * @dev Transfer tokens to another user
     * @param tokenAddress Address of the token
     * @param recipient Recipient address
     * @param amount Amount to transfer
     */
    function transfer(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(assets[tokenAddress].active, "Asset not supported");
        require(recipient != address(0), "Invalid recipient");
        require(
            userBalances[msg.sender][tokenAddress].amount >= amount,
            "Insufficient balance"
        );
        require(amount > 0, "Amount must be positive");

        userBalances[msg.sender][tokenAddress].amount -= amount;
        
        if (userBalances[recipient][tokenAddress].amount == 0) {
            userAssets[recipient].push(tokenAddress);
        }
        
        userBalances[recipient][tokenAddress].amount += amount;

        emit TransferMade(msg.sender, recipient, tokenAddress, amount);
    }

    // ==================== View Functions ====================

    /**
     * @dev Get user balance for a specific asset
     * @param user User address
     * @param tokenAddress Token address
     * @return Balance amount
     */
    function getBalance(address user, address tokenAddress)
        external
        view
        returns (uint256)
    {
        return userBalances[user][tokenAddress].amount;
    }

    /**
     * @dev Get user total balance across all assets
     * @param user User address
     * @return Total balance
     */
    function getTotalBalance(address user) external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < userAssets[user].length; i++) {
            total += userBalances[user][userAssets[user][i]].amount;
        }
        return total;
    }

    /**
     * @dev Get total number of assets
     * @return Total assets count
     */
    function getTotalAssets() external view returns (uint256) {
        return totalAssetsCount;
    }

    /**
     * @dev Get asset information
     * @param tokenAddress Token address
     * @return symbol Token symbol
     * @return decimals Token decimals
     */
    function getAssetInfo(address tokenAddress)
        external
        view
        returns (string memory symbol, uint8 decimals)
    {
        Asset memory asset = assets[tokenAddress];
        return (asset.symbol, asset.decimals);
    }

    /**
     * @dev Get all user assets
     * @param user User address
     * @return Array of asset addresses
     */
    function getUserAssets(address user)
        external
        view
        returns (address[] memory)
    {
        return userAssets[user];
    }

    /**
     * @dev Get detailed user balance info
     * @param user User address
     * @param tokenAddress Token address
     * @return balance Amount deposited
     * @return interest Accumulated interest
     * @return depositTime Deposit timestamp
     */
    function getUserBalanceDetail(
        address user,
        address tokenAddress
    )
        external
        view
        returns (
            uint256 balance,
            uint256 interest,
            uint256 depositTime
        )
    {
        UserBalance memory ub = userBalances[user][tokenAddress];
        return (ub.amount, ub.accumulatedInterest, ub.depositTime);
    }

    /**
     * @dev Get all asset addresses
     * @return Array of asset addresses
     */
    function getAllAssets() external view returns (address[] memory) {
        return assetList;
    }

    /**
     * @dev Get asset total deposited
     * @param tokenAddress Token address
     * @return Total amount deposited
     */
    function getAssetTotalDeposited(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return assets[tokenAddress].totalDeposited;
    }

    // ==================== Internal Functions ====================

    /**
     * @dev Calculate accumulated interest
     * @param user User address
     * @param tokenAddress Token address
     * @return Interest amount
     */
    function calculateInterest(address user, address tokenAddress)
        internal
        view
        returns (uint256)
    {
        UserBalance memory ub = userBalances[user][tokenAddress];
        Asset memory asset = assets[tokenAddress];

        if (ub.amount == 0 || asset.interestRate == 0) {
            return 0;
        }

        uint256 timeDiff = block.timestamp - ub.depositTime;
        uint256 yearInSeconds = 365 days;
        uint256 interest = (ub.amount * asset.interestRate * timeDiff) /
            (yearInSeconds * 10000);

        return interest;
    }

    /**
     * @dev Get calculated interest for user
     * @param user User address
     * @param tokenAddress Token address
     * @return Interest amount
     */
    function getCalculatedInterest(address user, address tokenAddress)
        external
        view
        returns (uint256)
    {
        return calculateInterest(user, tokenAddress);
    }
}
