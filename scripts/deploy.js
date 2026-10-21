const { ethers } = require('hardhat');

async function main() {
  const deployerOwner = process.env.DEPLOYER_OWNER || process.env.CONTRACT_OWNER;
  const owners = [
    deployerOwner,
    process.env.OWNER_1,
    process.env.OWNER_2,
  ].filter(Boolean);

  if (!deployerOwner) {
    throw new Error('Set DEPLOYER_OWNER or CONTRACT_OWNER in your .env before deploying.');
  }

  if (owners.length < 1) {
    throw new Error('No owner addresses were configured for deployment.');
  }

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
