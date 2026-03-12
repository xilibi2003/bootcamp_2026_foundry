// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract DeployMyNFT is Script {
    function run() public {
        // 当在命令行使用 --keystore 或 --account 选项时，
        // Foundry 默认会将运行脚本的外部发送者 (msg.sender) 设为对应 keystore 中的地址
        address deployer = msg.sender;
        
        console.log("Deployer address:", deployer);

        // 无参开启广播，利用通过命令行 --keystore 或交互式解锁的钱包进行签名
        vm.startBroadcast();

        // 1. 部署 MyNFT 合约
        MyNFT myNft = new MyNFT();
        console.log("MyNFT deployed to:", address(myNft));

        // 2. 铸造 NFT (利用刚刚上传到 IPFS 的 JSON 元数据)
        // 使用传递给合约的 CID 拼接 ipfs:// URI
        string memory tokenUri = "ipfs://bafkreicdz4lei3yvxlc5wnvymv2n6ogxcukre4depcgmxdr6giy6qhby4m";
        
        // 我们将它铸造给当前部署者的钱包地址
        myNft.safeMint(deployer, tokenUri);
        
        console.log("Minted NFT to:", deployer);
        console.log("Token URI:", tokenUri);

        // 结束广播
        vm.stopBroadcast();
    }
}
