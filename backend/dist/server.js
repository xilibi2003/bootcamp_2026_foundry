"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createServer = createServer;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const viem_1 = require("viem");
function createServer(database) {
    const app = (0, express_1.default)();
    app.use((0, cors_1.default)());
    app.use(express_1.default.json());
    app.get("/health", (_req, res) => {
        res.json({
            ok: true,
            sync: database.getSyncStatus(),
        });
    });
    app.get("/api/transfers/:address", (req, res) => {
        const { address } = req.params;
        if (!(0, viem_1.isAddress)(address)) {
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
