"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createIndexer = createIndexer;
const viem_1 = require("viem");
const config_1 = require("./config");
const transferEvent = (0, viem_1.parseAbiItem)("event Transfer(address indexed from, address indexed to, uint256 value)");
const publicClient = (0, viem_1.createPublicClient)({
    transport: (0, viem_1.http)(config_1.config.rpcUrl),
});
function createIndexer(database) {
    let isSyncing = false;
    async function syncOnce() {
        if (isSyncing)
            return;
        isSyncing = true;
        try {
            const latestBlock = await publicClient.getBlockNumber();
            const lastSyncedBlock = database.getLastSyncedBlock();
            let nextBlock = lastSyncedBlock === null ? config_1.config.startBlock : lastSyncedBlock + 1n;
            if (nextBlock > latestBlock) {
                return;
            }
            while (nextBlock <= latestBlock) {
                const toBlock = nextBlock + config_1.config.syncBatchSize - 1n > latestBlock
                    ? latestBlock
                    : nextBlock + config_1.config.syncBatchSize - 1n;
                const logs = await publicClient.getLogs({
                    address: config_1.config.tokenAddress,
                    event: transferEvent,
                    fromBlock: nextBlock,
                    toBlock,
                    strict: true,
                });
                const records = logs.flatMap((log) => {
                    if (log.transactionHash === null ||
                        log.blockHash === null ||
                        log.logIndex === null ||
                        log.blockNumber === null) {
                        return [];
                    }
                    return [
                        {
                            logKey: `${log.transactionHash}-${log.logIndex}`,
                            transactionHash: log.transactionHash,
                            logIndex: Number(log.logIndex),
                            blockNumber: Number(log.blockNumber),
                            blockHash: log.blockHash,
                            fromAddress: log.args.from.toLowerCase(),
                            toAddress: log.args.to.toLowerCase(),
                            value: log.args.value.toString(),
                            contractAddress: log.address.toLowerCase(),
                        },
                    ];
                });
                if (records.length > 0) {
                    database.insertTransfers(records);
                }
                database.setLastSyncedBlock(toBlock);
                nextBlock = toBlock + 1n;
            }
        }
        catch (error) {
            console.error("failed to sync transfers", error);
        }
        finally {
            isSyncing = false;
        }
    }
    return {
        syncOnce,
        start() {
            void syncOnce();
            return setInterval(() => {
                void syncOnce();
            }, config_1.config.syncIntervalMs);
        },
    };
}
