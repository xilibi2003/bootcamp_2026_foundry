import dotenv from "dotenv";
import {
  createPublicClient,
  createWalletClient,
  erc20Abi,
  formatUnits,
  http,
  parseUnits,
} from "viem";
import { mnemonicToAccount, privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

dotenv.config();

const rpcUrl = process.env.ANVIL_RPC_URL ?? "http://127.0.0.1:8545";
const tokenAddress =
  process.env.ANVIL_TOKEN_ADDRESS ??
  "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const senderPrivateKey =
  process.env.ANVIL_SENDER_PRIVATE_KEY ??
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const anvilMnemonic =
  process.env.ANVIL_MNEMONIC ??
  "test test test test test test test test test test test junk";

async function main() {
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  });

  const senderAccount = privateKeyToAccount(senderPrivateKey as `0x${string}`);
  const senderClient = createWalletClient({
    account: senderAccount,
    chain: foundry,
    transport: http(rpcUrl),
  });

  const recipientAccounts = [1, 2, 3].map((index) =>
    mnemonicToAccount(anvilMnemonic, {
      addressIndex: index,
    }),
  );

  const decimals = await publicClient.readContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: "decimals",
  });

  const symbol = await publicClient.readContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: "symbol",
  });

  const plan = [
    { to: recipientAccounts[0].address, amount: "12" },
    { to: recipientAccounts[1].address, amount: "5" },
    { to: recipientAccounts[2].address, amount: "9" },
    { to: recipientAccounts[0].address, amount: "3.5" },
    { to: recipientAccounts[1].address, amount: "1.25" },
    { to: recipientAccounts[2].address, amount: "7.75" },
  ];

  console.log(`RPC: ${rpcUrl}`);
  console.log(`Token: ${tokenAddress}`);
  console.log(`Sender: ${senderAccount.address}`);

  for (const transfer of plan) {
    const value = parseUnits(transfer.amount, decimals);
    const hash = await senderClient.writeContract({
      address: tokenAddress as `0x${string}`,
      abi: erc20Abi,
      functionName: "transfer",
      args: [transfer.to, value],
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(
      `transfer ${transfer.amount} ${symbol} -> ${transfer.to} tx=${receipt.transactionHash} block=${receipt.blockNumber}`,
    );
  }

  console.log("balances:");
  for (const account of recipientAccounts) {
    const balance = await publicClient.readContract({
      address: tokenAddress as `0x${string}`,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    });

    console.log(`- ${account.address}: ${formatUnits(balance, decimals)} ${symbol}`);
  }
}

main().catch((error) => {
  console.error("failed to generate transfer records", error);
  process.exit(1);
});
