## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


forge create Counter --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545 --broadcast


cast wallet import --mnemonic "test test test test test test test test test test test junk" -k <KEYSTORE_DIR> <ACCOUNT_NAME>

### Get Wallet address

cast wallet address --keystore ./keys/for_deploy
0x1E1C0979e6C7CBdDD9E066a51F7df1aab3AfCfeC

## Depoly

forge script script/XXToken.s.sol \
  --keystore keys/for_deploy \
  --rpc-url sepolia \
  --broadcast \
  --verify


forge script script/DeployMyNFT.s.sol:DeployMyNFT --rpc-url https://go.getblock.io/02667b699f05444ab2c64f9bff28f027 --keystore keys/for_deploy --broadcast


https://go.getblock.io/02667b699f05444ab2c64f9bff28f027



编写一个简单的 NFTMarket 合约，使用 @src/ERC1363.sol Token 来买卖 NFT， NFTMarket 的函数有：

list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

实现 @src/IERC1363Receiver.sol 所要求的接收者方法 onTransferReceived ，在 onTransferReceived 中实现NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。