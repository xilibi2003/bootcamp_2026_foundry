# Project Layout

- `backend/`: Node.js backend for MyToken Transfer indexing and REST APIs
- `frontend/`: Next.js frontend app
- `foundry/`: Solidity contracts, scripts, tests, artifacts, and Foundry config



实现一个工厂合约 ERC20MemeFactory，  实现用最小代理创建很多个 ERC20 合约，创建的方法为：deployMeme(string symbol, uint totalSupply, uint perMint) 
mint token 的方法为：mintMeme(address tokenAddr) 



ERC20Meme  initialize  mint  为 0 


在 ERC20MemeFactory 合约中，添加一个mint 时需要支付 ETH 的设置， 在 deployMeme  添加一个参数用来设置 铸造一个 Meme 所需的费用， 属于 deployMeme 的调用者（即 Meme 的 Owner） 收取支付 ETH 的 5%为作为 Owner 的收益。

