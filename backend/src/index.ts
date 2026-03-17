import { config } from "./config";
import { createDatabase } from "./db";
import { createIndexer } from "./indexer";
import { createServer } from "./server";

async function main() {
  const database = createDatabase(config.sqlitePath);
  const indexer = createIndexer(database);
  const app = createServer(database);

  indexer.start();

  app.listen(config.port, () => {
    console.log(`backend listening on http://localhost:${config.port}`);
    console.log(`tracking token: ${config.tokenAddress}`);
    console.log(`sqlite: ${config.sqlitePath}`);
  });
}

main().catch((error) => {
  console.error("failed to start backend", error);
  process.exit(1);
});
