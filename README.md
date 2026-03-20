# Project Layout

- `backend/`: Node.js backend for MyToken Transfer indexing and REST APIs
- `frontend/`: Next.js frontend app
- `foundry/`: Solidity contracts, scripts, tests, artifacts, and Foundry config




在 foundry 下实现一个简单的多签钱包合约， 函数有：
1. proposal(): 多签持有人可提交交易 发起提案
2. comfirm() ：其他多签人确认交易（使用交易的方式确认即可， 不使用离线签名）
3. execute():  当提案达到多签门槛、任何人都可以执行交易 
