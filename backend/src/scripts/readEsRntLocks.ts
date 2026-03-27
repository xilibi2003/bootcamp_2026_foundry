import dotenv from "dotenv";
import {
  createPublicClient,
  getAddress,
  hexToBigInt,
  http,
  keccak256,
  pad,
  toHex,
} from "viem";
import { foundry } from "viem/chains";

dotenv.config();

const rpcUrl = process.env.ANVIL_RPC_URL ?? "http://127.0.0.1:8545";
const contractAddress =
  (process.env.ESRNT_ADDRESS as `0x${string}` | undefined) ??
  "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";

const LOCKS_SLOT = 0n;
const ADDRESS_MASK = (1n << 160n) - 1n;
const UINT64_MASK = (1n << 64n) - 1n;
const STRUCT_SLOTS = 2n;

async function readSlot(
  client: ReturnType<typeof createPublicClient>,
  slot: bigint,
) {
  const value = await client.getStorageAt({
    address: contractAddress,
    slot: toHex(slot),
  });

  return hexToBigInt(value ?? "0x0");
}

function getArrayBaseSlot(slot: bigint) {
  return hexToBigInt(keccak256(pad(toHex(slot), { size: 32 })));
}

async function main() {
  const client = createPublicClient({
    chain: foundry,
    transport: http(rpcUrl),
  });

  const length = await readSlot(client, LOCKS_SLOT);
  const baseSlot = getArrayBaseSlot(LOCKS_SLOT);

  console.log(`RPC: ${rpcUrl}`);
  console.log(`ESRnt: ${contractAddress}`);
  console.log(`locks length: ${length}`);

  for (let i = 0n; i < length; i++) {
    const packedSlot = await readSlot(client, baseSlot + i * STRUCT_SLOTS);
    const amount = await readSlot(client, baseSlot + i * STRUCT_SLOTS + 1n);

    const user = getAddress(`0x${(packedSlot & ADDRESS_MASK).toString(16).padStart(40, "0")}`);
    const startTime = (packedSlot >> 160n) & UINT64_MASK;

    console.log(
      `locks[${i}]: user:${user}, startTime:${startTime}, amount:${amount}`,
    );
  }
}

main().catch((error) => {
  console.error("failed to read ESRnt locks", error);
  process.exit(1);
});
