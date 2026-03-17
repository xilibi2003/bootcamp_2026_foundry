import path from "path";

import dotenv from "dotenv";
import { isAddress, type Address } from "viem";

dotenv.config();

function parseNumber(name: string, fallback: number) {
  const value = process.env[name];
  if (!value) return fallback;

  const parsed = Number(value);
  if (Number.isNaN(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative number`);
  }

  return parsed;
}

function parseAddress(name: string, fallback: Address) {
  const value = process.env[name] ?? fallback;
  if (!isAddress(value)) {
    throw new Error(`${name} must be a valid EVM address`);
  }

  return value;
}

export const config = {
  port: parseNumber("PORT", 3001),
  rpcUrl: process.env.RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com",
  chainId: parseNumber("CHAIN_ID", 11155111),
  tokenAddress: parseAddress(
    "TOKEN_ADDRESS",
    "0x07B5A5ADaCedF233AADbe3f2862aac7ae21fBc0d",
  ),
  startBlock: BigInt(parseNumber("START_BLOCK", 10420689)),
  syncIntervalMs: parseNumber("SYNC_INTERVAL_MS", 15000),
  syncBatchSize: BigInt(parseNumber("SYNC_BATCH_SIZE", 2000)),
  sqlitePath: path.resolve(
    process.cwd(),
    process.env.SQLITE_PATH ?? "./data/mytoken-transfers.db",
  ),
};
