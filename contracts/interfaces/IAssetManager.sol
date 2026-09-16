// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
