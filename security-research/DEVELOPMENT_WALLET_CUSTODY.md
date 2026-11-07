# Development wallet security

## Scope

This utility creates a **new development-only EOA locally**. It does not deploy contracts, connect to an RPC, fund the wallet, transfer assets, or authorize transactions.

## Generate locally

1. Clone this repository onto a trusted computer.
2. Install dependencies with the repository's lockfile-based install command (the lockfile must be committed before production use).
3. Run `npm run wallet:generate` in an interactive terminal.
4. Enter a unique password of at least 16 characters when prompted. Input is hidden.
5. Record the displayed public address. The encrypted JSON keystore is written under `wallet_storage/` with owner-only file permissions where supported.

## Critical custody rules

- The keystore password is not stored by this script. Keep it separately in an offline password backup or hardware-backed secret manager.
- The generated private key is never printed by the script.
- `wallet_storage/` is ignored by Git. Never upload the keystore, password, seed phrase, or private key to GitHub, ChatGPT, email, cloud drives, or support tickets.
- Back up the encrypted keystore offline. Test recovery before funding.
- Fund this wallet with testnet assets only. Never migrate production assets to a development EOA.
- For real treasury assets, deploy/use a Safe multisig with independently controlled signers and a reviewed threshold. The Asset Manager should propose transactions; authorized signers approve and execute them.
- A sponsored transaction is not free: a Paymaster or sponsor pays the network fee and must be funded and configured with policy limits.

## What this utility does not do

It does not create a Safe, register passkeys, provision a Paymaster, obtain gas sponsorship, or transfer any assets. Those steps require separate chain-specific deployment, service configuration, security review, and explicit transaction approval.
