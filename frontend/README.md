# Token Bank Frontend

这是一个独立的 Next.js 前端，使用 `viem` 与 `MyToken` 和 `TokenBank` 合约交互。

## 功能

- 连接钱包
- 显示当前用户钱包中的 Token 余额
- 显示当前用户已存入 `TokenBank` 的金额
- 输入金额并执行存款
- 输入金额并执行取款

## 配置

1. 复制环境变量文件：

```bash
cp .env.example .env.local
```

2. 如有需要，按你的实际部署结果调整配置：

- `NEXT_PUBLIC_TOKEN_ADDRESS`
- `NEXT_PUBLIC_TOKEN_BANK_ADDRESS`

当前 `.env.example` 已按仓库中的 Anvil 广播记录预填：

- `NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545`
- `NEXT_PUBLIC_CHAIN_ID=31337`
- `NEXT_PUBLIC_CHAIN_NAME=Anvil`
- `MyToken=0x5FbDB2315678afecb367f032d93F642f64180aa3`
- `TokenBank=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`

如果你重启过 Anvil 并重新部署过合约，这两个地址可能会变化，需要同步更新。

## 启动

```bash
npm install
npm run dev
```

默认访问 [http://localhost:3000](http://localhost:3000)。

连接钱包时，页面会尝试切换到本地 `Anvil` 链；如果钱包里还没有这条链，也会请求自动添加。
