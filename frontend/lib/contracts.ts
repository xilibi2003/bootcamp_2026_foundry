import { erc20Abi, type Address } from "viem";

export const tokenBankAbi = [
  {
    type: "function",
    stateMutability: "view",
    name: "balances",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    stateMutability: "view",
    name: "token",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    stateMutability: "nonpayable",
    name: "deposit",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    stateMutability: "nonpayable",
    name: "permitDeposit",
    inputs: [
      { name: "amount", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "r", type: "bytes32" },
      { name: "s", type: "bytes32" },
    ],
    outputs: [],
  },
  {
    type: "function",
    stateMutability: "nonpayable",
    name: "withdraw",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
] as const;

const zeroAddress = "0x0000000000000000000000000000000000000000" as Address;

export const tokenAbi = [
  ...erc20Abi,
  {
    type: "function",
    stateMutability: "view",
    name: "nonces",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export const config = {
  rpcUrl: process.env.NEXT_PUBLIC_RPC_URL ?? "http://127.0.0.1:8545",
  chainId: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "31337"),
  chainName: process.env.NEXT_PUBLIC_CHAIN_NAME ?? "Anvil",
  tokenAddress:
    (process.env.NEXT_PUBLIC_TOKEN_ADDRESS ??
      "0x5FbDB2315678afecb367f032d93F642f64180aa3") as Address,
  tokenBankAddress:
    (process.env.NEXT_PUBLIC_TOKEN_BANK_ADDRESS ??
      "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512") as Address,
  tokenName: process.env.NEXT_PUBLIC_TOKEN_NAME ?? "MyPermitToken",
  tokenSymbol: process.env.NEXT_PUBLIC_TOKEN_SYMBOL ?? "MPT",
  tokenDecimals: Number(process.env.NEXT_PUBLIC_TOKEN_DECIMALS ?? "18"),
};

export function hasConfiguredContracts() {
  return config.tokenAddress !== zeroAddress && config.tokenBankAddress !== zeroAddress;
}
