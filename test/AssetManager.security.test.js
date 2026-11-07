const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager security regressions", function () {
  let manager;
  let token;
  let owner;
  let user;
  let recipient;
  let tokenAddress;
  let managerAddress;
  const amount = ethers.parseUnits("100", 6);

  beforeEach(async function () {
    [owner, user, recipient] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockERC20");
    token = await Token.deploy("Test USD", "TUSD", 6, 1000);
    await token.waitForDeployment();
    tokenAddress = await token.getAddress();

    const Manager = await ethers.getContractFactory("AssetManager");
    manager = await Manager.deploy();
    await manager.waitForDeployment();
    managerAddress = await manager.getAddress();

    await manager.addAsset(tokenAddress, "TUSD", 6);
    await token.transfer(user.address, amount * 2n);
    await token.connect(user).approve(managerAddress, amount * 2n);
  });

  it("rejects removing an asset while user deposits remain", async function () {
    await manager.connect(user).deposit(tokenAddress, amount);

    await expect(manager.removeAsset(tokenAddress))
      .to.be.revertedWith("Outstanding deposits");

    expect(await manager.getBalance(user.address, tokenAddress)).to.equal(amount);
    expect(await manager.getTotalDeposited(tokenAddress)).to.equal(amount);

    // The failed administrative removal must not prevent the user's withdrawal.
    await expect(manager.connect(user).withdraw(tokenAddress, amount)).not.to.be.reverted;
    expect(await manager.getBalance(user.address, tokenAddress)).to.equal(0n);
  });

  it("allows removal and re-addition only after all deposits are withdrawn", async function () {
    await manager.connect(user).deposit(tokenAddress, amount);
    await manager.connect(user).withdraw(tokenAddress, amount);

    await expect(manager.removeAsset(tokenAddress)).not.to.be.reverted;
    await expect(manager.addAsset(tokenAddress, "TUSD", 6)).not.to.be.reverted;

    await manager.connect(user).deposit(tokenAddress, amount);
    expect(await manager.getTotalDeposited(tokenAddress)).to.equal(amount);
    await expect(manager.connect(user).withdraw(tokenAddress, amount)).not.to.be.reverted;
  });

  it("does not duplicate a user's asset entry after a full transfer out and back", async function () {
    await manager.connect(user).deposit(tokenAddress, amount);
    await manager.connect(user).transfer(tokenAddress, recipient.address, amount);
    await manager.connect(recipient).transfer(tokenAddress, user.address, amount);

    expect(await manager.getUserAssets(user.address)).to.deep.equal([tokenAddress]);
    expect(await manager.getTotalBalance(user.address)).to.equal(amount);
  });

  it("does not duplicate the global asset list after removal and re-addition", async function () {
    await manager.connect(user).deposit(tokenAddress, amount);
    await manager.connect(user).withdraw(tokenAddress, amount);
    await manager.removeAsset(tokenAddress);
    await manager.addAsset(tokenAddress, "TUSD", 6);

    expect(await manager.getAllAssets()).to.deep.equal([tokenAddress]);
    expect(await manager.getTotalAssets()).to.equal(1n);
  });
});
