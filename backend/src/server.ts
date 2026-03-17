import express from "express";
import cors from "cors";
import { isAddress } from "viem";

import type { AppDatabase } from "./db";

export function createServer(database: AppDatabase) {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({
      ok: true,
      sync: database.getSyncStatus(),
    });
  });

  app.get("/api/transfers/:address", (req, res) => {
    const { address } = req.params;
    if (!isAddress(address)) {
      res.status(400).json({ error: "Invalid address" });
      return;
    }

    const rawLimit = Number(req.query.limit ?? 20);
    const rawPage = Number(req.query.page ?? 1);
    if (!Number.isFinite(rawLimit) || !Number.isFinite(rawPage)) {
      res.status(400).json({ error: "limit and page must be numbers" });
      return;
    }

    const limit = Math.max(1, Math.min(Math.trunc(rawLimit), 100));
    const page = Math.max(1, Math.trunc(rawPage));
    const normalizedAddress = address.toLowerCase();
    const offset = (page - 1) * limit;

    const result = database.getTransfersByAddress(normalizedAddress, limit, offset);

    res.json({
      address: normalizedAddress,
      page,
      limit,
      total: result.total,
      items: result.items,
    });
  });

  return app;
}
