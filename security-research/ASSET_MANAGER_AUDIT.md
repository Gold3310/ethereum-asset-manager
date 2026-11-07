# Ethereum Asset Manager — Security Review

**Review date:** 2026-11-07  
**Repository:** `Gold3310/ethereum-asset-manager`  
**Baseline:** `main` at `d35a7207de2a86dd9d50986177bbe553e8405b7f`  
**Research branch:** `security-fix/asset-accounting-2026-11-07`  
**Pull request:** [#1 — Draft security fixes](https://github.com/Gold3310/ethereum-asset-manager/pull/1)

## Executive summary

The original `AssetManager` implementation had an owner-triggered path that could permanently prevent users from withdrawing deposited tokens. The same review found duplicate asset-list entries that could inflate `getTotalBalance` and duplicate global asset-list results. The patch is isolated on a draft branch; no main-branch merge or deployment occurred.

## Confirmed findings and remediations

### AM-01 — Removing an asset with outstanding deposits locks withdrawals

**Severity:** High operational impact; privileged-owner trigger  
**Affected source:** `contracts/AssetManager.sol`, `removeAsset` and `addAsset`  
**Original behavior:**
- `removeAsset` marked the asset inactive without checking `totalDeposited`.
- `withdraw` required the asset to remain active.
- Re-adding the same asset initialized `totalDeposited` to zero while user balances remained.
- After re-addition, withdrawal accounting could underflow at `totalDeposited -= amount`, reverting the whole transaction.

**Impact:** An owner action or owner-key compromise could make existing user deposits unwithdrawable. Re-adding the token did not restore the accounting invariant.

**Remediation on research branch:** `removeAsset` now requires `totalDeposited == 0` and reverts with `Outstanding deposits` otherwise.

**Regression coverage:** `test/AssetManager.security.test.js` verifies that removal is rejected while funds remain, withdrawal still works, and removal/re-addition works after full withdrawal.

### AM-02 — Duplicate per-user and global asset entries

**Severity:** Low (accounting/view integrity)  
**Affected source:** `contracts/AssetManager.sol`, deposit, transfer, `getTotalBalance`, and `getAllAssets`.

**Original behavior:** A user could transfer an asset balance to zero and later receive the same token again; the token address could be appended to `userAssets` more than once. `getTotalBalance` iterates that array and could count the same current balance multiple times. Removing and re-adding an asset could similarly duplicate the global asset list.

**Remediation on research branch:** Added membership mappings `userAssetListed` and `assetListed`; append each user/token and global token entry at most once.

**Regression coverage:** Tests cover transfer-out/transfer-back and remove/re-add without duplicate list entries.

## Deployment and key-handling hardening

### AM-03 — Mainnet execution had no explicit opt-in

**Severity:** High deployment risk  
**Affected source:** `hardhat.config.js`.

**Original behavior:** A configured `PRIVATE_KEY` enabled the mainnet network account without a separate mainnet deployment acknowledgement.

**Remediation on research branch:** Mainnet commands now require `ALLOW_MAINNET_DEPLOYMENT=true`. A malformed private key is rejected at config load. This is a guardrail, not a substitute for multisig approvals or a deployment review.

### AM-04 — Environment template mislabelled an address as a private key

**Severity:** Medium configuration risk; no private key exposure confirmed  
**Affected source:** `.env.example`.

The committed `PRIVATE_KEY` value was a 20-byte address-shaped value, not a valid 32-byte private key. It is not evidence that a private key was exposed. The template now leaves the private key blank and documents local secret handling.

The `.gitignore` now ignores `.env.*` while allowing `.env.example`.

### AM-05 — Ethers v5/v6 dependency conflict and unused wallet dependencies

**Severity:** Medium build/supply-chain hygiene  
**Affected source:** `package.json`.

The initial CI install failed because `@nomiclabs/hardhat-ethers@2.2.3` requires ethers v5 while the project uses ethers v6 and Hardhat Toolbox v3. The obsolete ethers v5 plugins and unused Uniswap/BIP39/ethereumjs-wallet/crypto dependencies were removed.

## Validation

**GitHub Actions:** [Run 42392755716](https://github.com/Gold3310/ethereum-asset-manager/actions/runs/42392755716)  
**Result:** Success  
**Verified head commit:** `fb27794f45ffbdb4edadf90c815297cc61e83716`

Passed steps:
- Dependency installation
- Hardhat compilation
- Hardhat regression tests

## Remaining risks and limitations

1. No deployed contract address was verified in the repository; no on-chain state inspection or transaction was performed.
2. The repository's `deploy`, `interact`, `add-assets`, `transfer`, and `display` scripts reference `scripts/*.js` paths that are absent from the current repository tree. Do not treat the project as deployment-ready until those scripts are implemented and reviewed.
3. No `package-lock.json` is present in the reviewed tree. Add and commit a lockfile before production builds to pin transitive dependency versions.
4. The contract accepts owner-listed ERC-20 tokens without checking actual received amounts. Fee-on-transfer or rebasing tokens can desynchronize internal accounting from actual token balances. Restrict supported assets or credit the measured balance delta.
5. `getTotalBalance` adds raw token units across assets with different decimals. Its result is not a meaningful common-denomination portfolio value; use price feeds and decimal normalization before presenting it as a total.
6. Interest is accumulated in accounting state; the reviewed contract does not establish a funded, claimable interest payout path.
7. `Ownable` is the administrative trust boundary. For real assets, transfer ownership to a properly configured Safe multisig after separate deployment review.

## Release decision

**Do not deploy this contract to mainnet yet.** The withdrawal-lock fix and regression tests pass, but deployment scripts, lockfile, supported-token policy, price/decimal accounting, interest semantics, and multisig ownership still need resolution. This branch and PR remain draft; main has not been modified.
