const { ethers } = require('hardhat');

async function main() {
  const deployerOwner = process.env.DEPLOYER_OWNER || process.env.CONTRACT_OWNER;

  if (!deployerOwner) {
    throw new Error('Set DEPLOYER_OWNER or CONTRACT_OWNER in your .env before deploying.');
  }

  const owners = [deployerOwner];

  const AssetManager = await ethers.getContractFactory('AssetManager');
  const assetManager = await AssetManager.deploy(owners);

  await assetManager.waitForDeployment();

  console.log('AssetManager deployed to:', await assetManager.getAddress());
  console.log('Authorized owners:', owners);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
