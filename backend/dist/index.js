"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("./config");
const db_1 = require("./db");
const indexer_1 = require("./indexer");
const server_1 = require("./server");
async function main() {
    const database = (0, db_1.createDatabase)(config_1.config.sqlitePath);
    const indexer = (0, indexer_1.createIndexer)(database);
    const app = (0, server_1.createServer)(database);
    indexer.start();
    app.listen(config_1.config.port, () => {
        console.log(`backend listening on http://localhost:${config_1.config.port}`);
        console.log(`tracking token: ${config_1.config.tokenAddress}`);
        console.log(`sqlite: ${config_1.config.sqlitePath}`);
    });
}
main().catch((error) => {
    console.error("failed to start backend", error);
    process.exit(1);
});
