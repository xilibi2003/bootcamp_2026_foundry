import fs from "fs";
import path from "path";

import Database from "better-sqlite3";

export type TransferRecord = {
  id: number;
  transactionHash: string;
  logIndex: number;
  blockNumber: number;
  blockHash: string;
  fromAddress: string;
  toAddress: string;
  value: string;
  contractAddress: string;
  createdAt: string;
};

export type SyncStatus = {
  lastSyncedBlock: number | null;
};

export function createDatabase(sqlitePath: string) {
  fs.mkdirSync(path.dirname(sqlitePath), { recursive: true });

  const db = new Database(sqlitePath);
  db.pragma("journal_mode = WAL");

  db.exec(`
    CREATE TABLE IF NOT EXISTS transfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_key TEXT NOT NULL UNIQUE,
      transaction_hash TEXT NOT NULL,
      log_index INTEGER NOT NULL,
      block_number INTEGER NOT NULL,
      block_hash TEXT NOT NULL,
      from_address TEXT NOT NULL,
      to_address TEXT NOT NULL,
      value TEXT NOT NULL,
      contract_address TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_transfers_from_address
      ON transfers(from_address);
    CREATE INDEX IF NOT EXISTS idx_transfers_to_address
      ON transfers(to_address);
    CREATE INDEX IF NOT EXISTS idx_transfers_block_number
      ON transfers(block_number DESC, log_index DESC);

    CREATE TABLE IF NOT EXISTS sync_state (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);

  const insertTransfer = db.prepare(`
    INSERT OR IGNORE INTO transfers (
      log_key,
      transaction_hash,
      log_index,
      block_number,
      block_hash,
      from_address,
      to_address,
      value,
      contract_address
    ) VALUES (
      @logKey,
      @transactionHash,
      @logIndex,
      @blockNumber,
      @blockHash,
      @fromAddress,
      @toAddress,
      @value,
      @contractAddress
    );
  `);

  const setSyncState = db.prepare(`
    INSERT INTO sync_state (key, value)
    VALUES (@key, @value)
    ON CONFLICT(key) DO UPDATE SET value = excluded.value;
  `);

  const getSyncState = db.prepare(`
    SELECT value FROM sync_state WHERE key = ?;
  `);

  const queryTransfers = db.prepare(`
    SELECT
      id,
      transaction_hash AS transactionHash,
      log_index AS logIndex,
      block_number AS blockNumber,
      block_hash AS blockHash,
      from_address AS fromAddress,
      to_address AS toAddress,
      value,
      contract_address AS contractAddress,
      created_at AS createdAt
    FROM transfers
    WHERE from_address = @address OR to_address = @address
    ORDER BY block_number DESC, log_index DESC
    LIMIT @limit OFFSET @offset;
  `);

  const countTransfers = db.prepare(`
    SELECT COUNT(*) AS count
    FROM transfers
    WHERE from_address = ? OR to_address = ?;
  `);

  return {
    db,
    insertTransfers(records: Array<Omit<TransferRecord, "id" | "createdAt"> & { logKey: string }>) {
      const transaction = db.transaction((items: Array<Omit<TransferRecord, "id" | "createdAt"> & { logKey: string }>) => {
        for (const item of items) {
          insertTransfer.run(item);
        }
      });

      transaction(records);
    },
    getLastSyncedBlock() {
      const row = getSyncState.get("last_synced_block") as { value: string } | undefined;
      return row ? BigInt(row.value) : null;
    },
    setLastSyncedBlock(blockNumber: bigint) {
      setSyncState.run({
        key: "last_synced_block",
        value: blockNumber.toString(),
      });
    },
    getTransfersByAddress(address: string, limit: number, offset: number) {
      const items = queryTransfers.all({ address, limit, offset }) as TransferRecord[];
      const row = countTransfers.get(address, address) as { count: number };

      return {
        items,
        total: row.count,
      };
    },
    getSyncStatus(): SyncStatus {
      const lastSyncedBlock = this.getLastSyncedBlock();
      return {
        lastSyncedBlock: lastSyncedBlock === null ? null : Number(lastSyncedBlock),
      };
    },
  };
}

export type AppDatabase = ReturnType<typeof createDatabase>;
