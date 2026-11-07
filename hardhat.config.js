require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();
require('hardhat-gas-reporter');
require('solidity-coverage');

const mainnetRequested = process.argv.some(
  (arg, index, args) => arg === '--network' && args[index + 1] === 'mainnet',
) || process.env.HARDHAT_NETWORK === 'mainnet';
if (mainnetRequested && process.env.ALLOW_MAINNET_DEPLOYMENT !== 'true') {
  throw new Error('Mainnet execution is disabled. Set ALLOW_MAINNET_DEPLOYMENT=true only after completing deployment review.');
}
if (process.env.PRIVATE_KEY && !/^0x[0-9a-fA-F]{64}$/.test(process.env.PRIVATE_KEY)) {
  throw new Error('PRIVATE_KEY must be a 32-byte hex key (0x + 64 hex characters). Never place it in a committed file.');
}

module.exports = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 17000000,
      },
      chainId: 1337,
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5,
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === 'true',
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
};
