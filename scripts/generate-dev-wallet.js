const fs = require("node:fs/promises");
const path = require("node:path");
const readline = require("node:readline");
const { Wallet } = require("ethers");

function readHidden(prompt) {
  return new Promise((resolve, reject) => {
    const stdin = process.stdin;
    if (!stdin.isTTY || typeof stdin.setRawMode !== "function") {
      reject(new Error("Run this command in an interactive local terminal."));
      return;
    }
    let value = "";
    process.stdout.write(prompt);
    stdin.setRawMode(true);
    stdin.resume();
    const cleanup = () => {
      stdin.setRawMode(false);
      stdin.pause();
      stdin.removeListener("data", onData);
      process.stdout.write("\n");
    };
    const onData = (chunk) => {
      for (const byte of chunk) {
        if (byte === 3) {
          cleanup();
          reject(new Error("Cancelled."));
          return;
        }
        if (byte === 13 || byte === 10) {
          cleanup();
          resolve(value);
          return;
        }
        if (byte === 127 || byte === 8) {
          value = value.slice(0, -1);
        } else if (byte >= 32 && byte <= 126) {
          value += String.fromCharCode(byte);
        }
      }
    };
    stdin.on("data", onData);
  });
}

async function main() {
  const password = await readHidden("Keystore password (minimum 16 characters): ");
  if (password.length < 16) throw new Error("Use a password of at least 16 characters.");
  const confirmation = await readHidden("Confirm keystore password: ");
  if (password !== confirmation) throw new Error("Passwords do not match.");

  const wallet = Wallet.createRandom();
  const encryptedJson = await wallet.encrypt(password);
  const address = wallet.address;
  const directory = path.resolve(process.cwd(), "wallet_storage");
  await fs.mkdir(directory, { recursive: true, mode: 0o700 });
  await fs.chmod(directory, 0o700);

  const destination = path.join(directory, `dev-wallet-${address.toLowerCase()}.json`);
  const temporary = `${destination}.tmp`;
  await fs.writeFile(temporary, encryptedJson + "\n", { encoding: "utf8", mode: 0o600, flag: "wx" });
  await fs.chmod(temporary, 0o600);
  await fs.rename(temporary, destination);
  await fs.chmod(destination, 0o600);

  process.stdout.write(`Created encrypted development keystore.\nAddress: ${address}\nFile: ${path.relative(process.cwd(), destination)}\n\nThe private key is encrypted and was not printed. Back up the keystore offline and keep its password separately. This wallet is for testnets only.\n`);
}

main().catch((error) => {
  process.stderr.write(`Wallet generation failed: ${error.message}\n`);
  process.exitCode = 1;
});
