import dotenv from "dotenv";
import {
  createPublicClient,
  createWalletClient,
  erc20Abi,
  formatUnits,
  http,
  isAddress,
  parseUnits,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

dotenv.config();

function getRequiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`missing required env var: ${name}`);
  }

  return value;
}

function parseCliArgs(argv: string[]) {
  let to: string | undefined;
  let amount: string | undefined;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];

    if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    }

    if (arg === "--to") {
      to = next;
      index += 1;
      continue;
    }

    if (arg === "--amount") {
      amount = next;
      index += 1;
      continue;
    }
  }

  if (!to || !amount) {
    printUsage();
    throw new Error("missing required arguments: --to and --amount");
  }

  if (!isAddress(to)) {
    throw new Error(`invalid recipient address: ${to}`);
  }

  return {
    to: to as Address,
    amount,
  };
}

function printUsage() {
  console.log(
    "Usage: npm run wallet -- --to <recipient-address> --amount <human-readable-amount>",
  );
}

async function main() {
  const { to, amount } = parseCliArgs(process.argv.slice(2));
  const rpcUrl = getRequiredEnv("ANVIL_RPC_URL");
  const tokenAddress = getRequiredEnv("TOKEN_ADDRESS");
  const privateKey = getRequiredEnv("PRIVATE_KEY");

  if (!isAddress(tokenAddress)) {
    throw new Error(`invalid TOKEN_ADDRESS: ${tokenAddress}`);
  }

  if (!privateKey.startsWith("0x")) {
    throw new Error("PRIVATE_KEY must be a hex string prefixed with 0x");
  }

  const account = privateKeyToAccount(privateKey as `0x${string}`);
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  });
  const walletClient = createWalletClient({
    account,
    chain: foundry,
    transport: http(rpcUrl),
  });

  const [decimals, symbol, senderBalanceBefore] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress as Address,
      abi: erc20Abi,
      functionName: "decimals",
    }),
    publicClient.readContract({
      address: tokenAddress as Address,
      abi: erc20Abi,
      functionName: "symbol",
    }),
    publicClient.readContract({
      address: tokenAddress as Address,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    }),
  ]);

  const value = parseUnits(amount, decimals);

  if (value <= 0n) {
    throw new Error("amount must be greater than 0");
  }

  console.log(`RPC: ${rpcUrl}`);
  console.log(`Token: ${tokenAddress}`);
  console.log(`Sender: ${account.address}`);
  console.log(`Recipient: ${to}`);
  console.log(`Amount: ${amount} ${symbol}`);
  console.log(
    `Sender balance before: ${formatUnits(senderBalanceBefore, decimals)} ${symbol}`,
  );

  const hash = await walletClient.writeContract({
    address: tokenAddress as Address,
    abi: erc20Abi,
    functionName: "transfer",
    args: [to, value],
  });

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  const [senderBalanceAfter, recipientBalanceAfter] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress as Address,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    }),
    publicClient.readContract({
      address: tokenAddress as Address,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [to],
    }),
  ]);

  console.log(`Transaction hash: ${receipt.transactionHash}`);
  console.log(`Block number: ${receipt.blockNumber}`);
  console.log(
    `Sender balance after: ${formatUnits(senderBalanceAfter, decimals)} ${symbol}`,
  );
  console.log(
    `Recipient balance after: ${formatUnits(recipientBalanceAfter, decimals)} ${symbol}`,
  );
}

main().catch((error) => {
  console.error("failed to send ERC20 transfer", error);
  process.exit(1);
});
