# Backend

Node.js backend used to index `MyToken` ERC20 `Transfer` events with `viem`, persist them into SQLite, and expose REST APIs.

## Setup

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

## Env Vars

- `PORT`: REST service port, defaults to `3001`
- `RPC_URL`: Sepolia RPC endpoint
- `CHAIN_ID`: EVM chain id, defaults to `11155111`
- `TOKEN_ADDRESS`: `MyToken` contract address
- `START_BLOCK`: first block used for backfill
- `SYNC_INTERVAL_MS`: polling interval for new logs
- `SYNC_BATCH_SIZE`: how many blocks to scan per batch
- `SQLITE_PATH`: SQLite database file path

## APIs

### `GET /health`

Returns service health and current sync status.

### `GET /api/transfers/:address`

Query transfers related to an address.

Query params:

- `page`: page number, defaults to `1`
- `limit`: page size, defaults to `20`, max `100`

Example:

```bash
curl "http://localhost:3001/api/transfers/0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38?page=1&limit=20"
```

## Generate Test Transfers

If your `MyToken` contract is deployed on local Anvil at `0x07B5A5ADaCedF233AADbe3f2862aac7ae21fBc0d`, run:

```bash
cd backend
npm run generate:transfers
```

The script uses the default Anvil first account as sender and sends several `transfer` transactions to other Anvil test accounts, so the indexer can capture fresh `Transfer` logs.

## CLI Wallet

The CLI wallet reads `ANVIL_RPC_URL`, `TOKEN_ADDRESS`, and `PRIVATE_KEY` from `.env`, then sends an ERC20 `transfer` using a human-readable `amount`.

Example:

```bash
cd backend
npm run wallet -- --to 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 --amount 1.5
```

The script will fetch the token `decimals` on-chain and convert `1.5` into the raw ERC20 amount automatically before submitting the transaction.
