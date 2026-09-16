const ethers = require('ethers');

// Network Configuration
const NETWORKS = {
  sepolia: {
    chainId: 11155111,
    rpcUrl: process.env.INFURA_KEY 
      ? `https://sepolia.infura.io/v3/${process.env.INFURA_KEY}`
      : 'http://localhost:8545',
    blockExplorer: 'https://sepolia.etherscan.io',
  },
  goerli: {
    chainId: 5,
    rpcUrl: process.env.INFURA_KEY
      ? `https://goerli.infura.io/v3/${process.env.INFURA_KEY}`
      : 'http://localhost:8545',
    blockExplorer: 'https://goerli.etherscan.io',
  },
  mainnet: {
    chainId: 1,
    rpcUrl: process.env.ALCHEMY_KEY
      ? `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`
      : 'http://localhost:8545',
    blockExplorer: 'https://etherscan.io',
  },
};

// Token Configuration for Sepolia Testnet
const TOKENS = {
  USDC: {
    symbol: 'USDC',
    decimals: 6,
    address: '0x1c7D4B196Cb0C6f48758F993f7C915e0D177B0e7',
    name: 'USD Coin',
  },
  DAI: {
    symbol: 'DAI',
    decimals: 18,
    address: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD9b44B1f53',
    name: 'Dai Stablecoin',
  },
  USDT: {
    symbol: 'USDT',
    decimals: 6,
    address: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
    name: 'Tether USD',
  },
  WETH: {
    symbol: 'WETH',
    decimals: 18,
    address: '0xfFf9976782d46CC05630D92EE39253FFB91a26C7',
    name: 'Wrapped Ether',
  },
};

// Transfer Configuration
const TRANSFER_CONFIG = {
  recipientAddress: '0x347287598b94d06309B3feaec5B6028e9fA2f94E',
  assetId: 'USDC',
  amount: '1000',
  from: '0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be',
};

// ABI for ERC20 tokens
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) returns (bool)',
  'function balanceOf(address account) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function totalSupply() view returns (uint256)',
];

module.exports = {
  NETWORKS,
  TOKENS,
  TRANSFER_CONFIG,
  ERC20_ABI,
};
