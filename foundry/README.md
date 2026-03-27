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



forge snapshot test/NFTMarket.t.sol --snap v1_gas
forge snapshot test/NFTMarket.t.sol --diff v1_gas

forge test test/NFTMarket.t.sol --gas-report



使用Viem 利用 getStorageAt 从链上读取 ESRnt ( 地址： 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 ， 在 anvil 网络）的 _locks 数组中的所有元素值，并打印出如下内容：
locks[0]: user:…… ,startTime:……,amount:……