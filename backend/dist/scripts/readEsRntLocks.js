"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
const viem_1 = require("viem");
const chains_1 = require("viem/chains");
dotenv_1.default.config();
const rpcUrl = process.env.ANVIL_RPC_URL ?? "http://127.0.0.1:8545";
const contractAddress = process.env.ESRNT_ADDRESS ??
    "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
const LOCKS_SLOT = 0n;
const ADDRESS_MASK = (1n << 160n) - 1n;
const UINT64_MASK = (1n << 64n) - 1n;
const STRUCT_SLOTS = 2n;
async function readSlot(client, slot) {
    const value = await client.getStorageAt({
        address: contractAddress,
        slot: (0, viem_1.toHex)(slot),
    });
    return (0, viem_1.hexToBigInt)(value ?? "0x0");
}
function getArrayBaseSlot(slot) {
    return (0, viem_1.hexToBigInt)((0, viem_1.keccak256)((0, viem_1.pad)((0, viem_1.toHex)(slot), { size: 32 })));
}
async function main() {
    const client = (0, viem_1.createPublicClient)({
        chain: chains_1.foundry,
        transport: (0, viem_1.http)(rpcUrl),
    });
    const length = await readSlot(client, LOCKS_SLOT);
    const baseSlot = getArrayBaseSlot(LOCKS_SLOT);
    console.log(`RPC: ${rpcUrl}`);
    console.log(`ESRnt: ${contractAddress}`);
    console.log(`locks length: ${length}`);
    for (let i = 0n; i < length; i++) {
        const packedSlot = await readSlot(client, baseSlot + i * STRUCT_SLOTS);
        const amount = await readSlot(client, baseSlot + i * STRUCT_SLOTS + 1n);
        const user = (0, viem_1.getAddress)(`0x${(packedSlot & ADDRESS_MASK).toString(16).padStart(40, "0")}`);
        const startTime = (packedSlot >> 160n) & UINT64_MASK;
        console.log(`locks[${i}]: user:${user}, startTime:${startTime}, amount:${amount}`);
    }
}
main().catch((error) => {
    console.error("failed to read ESRnt locks", error);
    process.exit(1);
});
