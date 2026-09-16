const ethers = require('ethers');

/**
 * Format token amount with decimals
 * @param {BigNumber} amount - Amount in smallest units
 * @param {number} decimals - Token decimals
 * @returns {string} Formatted amount
 */
function formatAmount(amount, decimals = 18) {
  try {
    return ethers.formatUnits(amount, decimals);
  } catch (error) {
    console.error('Error formatting amount:', error);
    return '0';
  }
}

/**
 * Parse token amount to smallest units
 * @param {string|number} amount - Human-readable amount
 * @param {number} decimals - Token decimals
 * @returns {BigNumber} Amount in smallest units
 */
function parseAmount(amount, decimals = 18) {
  try {
    return ethers.parseUnits(amount.toString(), decimals);
  } catch (error) {
    console.error('Error parsing amount:', error);
    return ethers.parseUnits('0', decimals);
  }
}

/**
 * Validate Ethereum address
 * @param {string} address - Address to validate
 * @returns {boolean} Is valid address
 */
function isValidAddress(address) {
  return ethers.isAddress(address);
}

/**
 * Get checksum address
 * @param {string} address - Address to checksum
 * @returns {string} Checksummed address
 */
function getChecksumAddress(address) {
  try {
    return ethers.getAddress(address);
  } catch (error) {
    console.error('Invalid address:', address);
    return null;
  }
}

/**
 * Format gas cost in USD
 * @param {BigNumber} gasUsed - Gas used
 * @param {BigNumber} gasPrice - Gas price in wei
 * @param {number} ethPrice - ETH price in USD
 * @returns {string} Formatted cost
 */
function formatGasCost(gasUsed, gasPrice, ethPrice = 2000) {
  try {
    const costInEth = ethers.formatEther(gasUsed * gasPrice);
    const costInUsd = parseFloat(costInEth) * ethPrice;
    return `${costInEth} ETH (~$${costInUsd.toFixed(2)})`;
  } catch (error) {
    console.error('Error calculating gas cost:', error);
    return 'N/A';
  }
}

/**
 * Truncate address for display
 * @param {string} address - Full address
 * @returns {string} Truncated address
 */
function truncateAddress(address) {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Format timestamp to readable date
 * @param {number} timestamp - Unix timestamp
 * @returns {string} Formatted date
 */
function formatDate(timestamp) {
  const date = new Date(timestamp * 1000);
  return date.toLocaleString();
}

/**
 * Wait for transaction confirmation
 * @param {object} tx - Transaction object
 * @param {number} confirmations - Number of confirmations to wait
 * @returns {Promise<object>} Transaction receipt
 */
async function waitForConfirmation(tx, confirmations = 1) {
  try {
    console.log(`⏳ Waiting for ${confirmations} confirmation(s)...`);
    const receipt = await tx.wait(confirmations);
    return receipt;
  } catch (error) {
    console.error('Error waiting for confirmation:', error);
    throw error;
  }
}

/**
 * Get current gas price
 * @param {object} provider - Ethers provider
 * @returns {Promise<string>} Gas price in gwei
 */
async function getGasPrice(provider) {
  try {
    const feeData = await provider.getFeeData();
    return ethers.formatUnits(feeData.gasPrice, 'gwei');
  } catch (error) {
    console.error('Error getting gas price:', error);
    return 'N/A';
  }
}

/**
 * Estimate transaction cost
 * @param {BigNumber} gasLimit - Gas limit
 * @param {BigNumber} gasPrice - Gas price
 * @returns {string} Formatted cost
 */
function estimateTransactionCost(gasLimit, gasPrice) {
  try {
    const totalCost = gasLimit * gasPrice;
    const costInEth = ethers.formatEther(totalCost);
    return costInEth;
  } catch (error) {
    console.error('Error estimating cost:', error);
    return 'N/A';
  }
}

module.exports = {
  formatAmount,
  parseAmount,
  isValidAddress,
  getChecksumAddress,
  formatGasCost,
  truncateAddress,
  formatDate,
  waitForConfirmation,
  getGasPrice,
  estimateTransactionCost,
};
