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
    name: "withdraw",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
] as const;

const zeroAddress = "0x0000000000000000000000000000000000000000" as Address;

export const tokenAbi = erc20Abi;

export const config = {
  rpcUrl:
    process.env.NEXT_PUBLIC_RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com",
  chainId: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "11155111"),
  chainName: process.env.NEXT_PUBLIC_CHAIN_NAME ?? "Sepolia",
  tokenAddress: (process.env.NEXT_PUBLIC_TOKEN_ADDRESS ?? zeroAddress) as Address,
  tokenBankAddress: (process.env.NEXT_PUBLIC_TOKEN_BANK_ADDRESS ?? zeroAddress) as Address,
  tokenSymbol: process.env.NEXT_PUBLIC_TOKEN_SYMBOL ?? "MTK",
  tokenDecimals: Number(process.env.NEXT_PUBLIC_TOKEN_DECIMALS ?? "18"),
};

export function hasConfiguredContracts() {
  return config.tokenAddress !== zeroAddress && config.tokenBankAddress !== zeroAddress;
}
