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
function getRequiredEnv(name) {
    const value = process.env[name];
    if (!value) {
        throw new Error(`missing required env var: ${name}`);
    }
    return value;
}
function parseCliArgs(argv) {
    let to;
    let amount;
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
    if (!(0, viem_1.isAddress)(to)) {
        throw new Error(`invalid recipient address: ${to}`);
    }
    return {
        to: to,
        amount,
    };
}
function printUsage() {
    console.log("Usage: npm run wallet -- --to <recipient-address> --amount <human-readable-amount>");
}
async function main() {
    const { to, amount } = parseCliArgs(process.argv.slice(2));
    const rpcUrl = getRequiredEnv("ANVIL_RPC_URL");
    const tokenAddress = getRequiredEnv("TOKEN_ADDRESS");
    const privateKey = getRequiredEnv("PRIVATE_KEY");
    if (!(0, viem_1.isAddress)(tokenAddress)) {
        throw new Error(`invalid TOKEN_ADDRESS: ${tokenAddress}`);
    }
    if (!privateKey.startsWith("0x")) {
        throw new Error("PRIVATE_KEY must be a hex string prefixed with 0x");
    }
    const account = (0, accounts_1.privateKeyToAccount)(privateKey);
    const publicClient = (0, viem_1.createPublicClient)({
        chain: chains_1.foundry,
        transport: (0, viem_1.http)(rpcUrl),
    });
    const walletClient = (0, viem_1.createWalletClient)({
        account,
        chain: chains_1.foundry,
        transport: (0, viem_1.http)(rpcUrl),
    });
    const [decimals, symbol, senderBalanceBefore] = await Promise.all([
        publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "decimals",
        }),
        publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "symbol",
        }),
        publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "balanceOf",
            args: [account.address],
        }),
    ]);
    const value = (0, viem_1.parseUnits)(amount, decimals);
    if (value <= 0n) {
        throw new Error("amount must be greater than 0");
    }
    console.log(`RPC: ${rpcUrl}`);
    console.log(`Token: ${tokenAddress}`);
    console.log(`Sender: ${account.address}`);
    console.log(`Recipient: ${to}`);
    console.log(`Amount: ${amount} ${symbol}`);
    console.log(`Sender balance before: ${(0, viem_1.formatUnits)(senderBalanceBefore, decimals)} ${symbol}`);
    const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: viem_1.erc20Abi,
        functionName: "transfer",
        args: [to, value],
    });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    const [senderBalanceAfter, recipientBalanceAfter] = await Promise.all([
        publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "balanceOf",
            args: [account.address],
        }),
        publicClient.readContract({
            address: tokenAddress,
            abi: viem_1.erc20Abi,
            functionName: "balanceOf",
            args: [to],
        }),
    ]);
    console.log(`Transaction hash: ${receipt.transactionHash}`);
    console.log(`Block number: ${receipt.blockNumber}`);
    console.log(`Sender balance after: ${(0, viem_1.formatUnits)(senderBalanceAfter, decimals)} ${symbol}`);
    console.log(`Recipient balance after: ${(0, viem_1.formatUnits)(recipientBalanceAfter, decimals)} ${symbol}`);
}
main().catch((error) => {
    console.error("failed to send ERC20 transfer", error);
    process.exit(1);
});
