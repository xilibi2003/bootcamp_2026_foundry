// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract DeployMyNFT is Script {
    function run() public {
        vm.startBroadcast();

        address deployer = msg.sender;
        console.log("Deployer address:", deployer);

        address proxy = Upgrades.deployUUPSProxy("src/MyNFT.sol:MyNFT", abi.encodeCall(MyNFT.initialize, (deployer)));
        MyNFT myNft = MyNFT(proxy);
        console.log("MyNFT proxy deployed to:", proxy);

        string memory tokenUri = "ipfs://bafkreicdz4lei3yvxlc5wnvymv2n6ogxcukre4depcgmxdr6giy6qhby4m";

        myNft.safeMint(deployer, tokenUri);
        console.log("Minted NFT to:", deployer);
        console.log("Token URI:", tokenUri);

        vm.stopBroadcast();
    }
}
