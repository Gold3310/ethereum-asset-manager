require('dotenv').config();
const { ethers } = require('hardhat');

const SAFE_ABI = [
  'function getOwners() view returns (address[])',
  'function getThreshold() view returns (uint256)',
  'function nonce() view returns (uint256)',
  'function getTransactionHash(address to, uint256 value, bytes data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) view returns (bytes32)',
  'function swapOwner(address prevOwner, address oldOwner, address newOwner) external',
];

async function main() {
  const safeAddress = process.env.SAFE_ADDRESS;
  const oldOwner = process.env.OLD_OWNER;
  const newOwner = process.env.NEW_OWNER;

  if (!safeAddress || !oldOwner || !newOwner) {
    throw new Error('Set SAFE_ADDRESS, OLD_OWNER, and NEW_OWNER in your .env before running this script.');
  }

  const provider = new ethers.JsonRpcProvider(
    process.env.ALCHEMY_KEY
      ? `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`
      : 'http://127.0.0.1:8545'
  );

  const safe = new ethers.Contract(safeAddress, SAFE_ABI, provider);
  const owners = await safe.getOwners();
  const threshold = await safe.getThreshold();

  const index = owners.findIndex((owner) => owner.toLowerCase() === oldOwner.toLowerCase());
  if (index === -1) {
    throw new Error(`Old owner ${oldOwner} is not in the Safe owner list.`);
  }

  const prevOwner = index === 0
    ? '0x0000000000000000000000000000000000000001'
    : owners[index - 1];

  const iface = new ethers.Interface([
    'function swapOwner(address prevOwner, address oldOwner, address newOwner)',
  ]);

  const data = iface.encodeFunctionData('swapOwner', [prevOwner, oldOwner, newOwner]);
  const nonce = await safe.nonce();
  const txHash = await safe.getTransactionHash(
    safeAddress,
    0,
    data,
    0,
    0,
    0,
    0,
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    nonce
  );

  console.log('Safe address:', safeAddress);
  console.log('Current threshold:', threshold.toString());
  console.log('Current owners:', owners);
  console.log('prevOwner:', prevOwner);
  console.log('oldOwner:', oldOwner);
  console.log('newOwner:', newOwner);
  console.log('safeTxHash:', txHash);
  console.log('data:', data);
  console.log('');
  console.log('Sign this Safe transaction with the remaining owners that satisfy the threshold.');
  console.log('The old owner key does not need to sign for swapOwner().');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
