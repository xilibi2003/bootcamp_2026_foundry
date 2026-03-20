"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
const viem_1 = require("viem");
const accounts_1 = require("viem/accounts");
const chains_1 = require("viem/chains");
dotenv_1.default.config();
const rpcUrl = process.env.ANVIL_RPC_URL ?? "http://127.0.0.1:8545";
const tokenAddress = process.env.ANVIL_TOKEN_ADDRESS ??
    "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const senderPrivateKey = process.env.ANVIL_SENDER_PRIVATE_KEY ??
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const anvilMnemonic = process.env.ANVIL_MNEMONIC ??
    "test test test test test test test test test test test junk";
async function main() {
    const publicClient = (0, viem_1.createPublicClient)({
        chain: chains_1.foundry,
        transport: (0, viem_1.http)(rpcUrl),
    });
    const senderAccount = (0, accounts_1.privateKeyToAccount)(senderPrivateKey);
    const senderClient = (0, viem_1.createWalletClient)({
        account: senderAccount,
        chain: chains_1.foundry,
        transport: (0, viem_1.http)(rpcUrl),
    });
    const recipientAccounts = [1, 2, 3].map((index) => (0, accounts_1.mnemonicToAccount)(anvilMnemonic, {
        addressIndex: index,
    }));
    const decimals = await publicClient.readContract({
        address: tokenAddress,
        abi: viem_1.erc20Abi,
        functionName: "decimals",
    });
    const symbol = await publicClient.readContract({
        address: tokenAddress,
        abi: viem_1.erc20Abi,
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
        const value = (0, viem_1.parseUnits)(transfer.amount, decimals);
        const hash = await senderClient.writeContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "transfer",
            args: [transfer.to, value],
        });
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log(`transfer ${transfer.amount} ${symbol} -> ${transfer.to} tx=${receipt.transactionHash} block=${receipt.blockNumber}`);
    }
    console.log("balances:");
    for (const account of recipientAccounts) {
        const balance = await publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "balanceOf",
            args: [account.address],
        });
        console.log(`- ${account.address}: ${(0, viem_1.formatUnits)(balance, decimals)} ${symbol}`);
    }
}
main().catch((error) => {
    console.error("failed to generate transfer records", error);
    process.exit(1);
});
