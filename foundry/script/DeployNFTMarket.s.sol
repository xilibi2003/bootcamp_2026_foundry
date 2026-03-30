// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external returns (address proxy) {
        address paymentToken = vm.envAddress("PAYMENT_TOKEN_ADDRESS");
        address nft = vm.envAddress("NFT_ADDRESS");
        address whitelistSigner = vm.envAddress("WHITELIST_SIGNER");

        vm.startBroadcast();

        address deployer = msg.sender;
        console.log("Deployer address:", deployer);
        console.log("Payment token:", paymentToken);
        console.log("NFT address:", nft);
        console.log("Whitelist signer:", whitelistSigner);

        proxy = Upgrades.deployUUPSProxy(
            "src/NFTMarket.sol:NFTMarket",
            abi.encodeCall(NFTMarket.initialize, (paymentToken, nft, whitelistSigner, deployer))
        );

        vm.stopBroadcast();

        console.log("NFTMarket proxy deployed to:", proxy);
    }
}
