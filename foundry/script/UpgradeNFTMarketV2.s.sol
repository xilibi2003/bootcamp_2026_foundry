// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeNFTMarketV2 is Script {
    function run() external {
        address proxy = vm.envAddress("MARKET_PROXY_ADDRESS");

        vm.startBroadcast();
        Upgrades.upgradeProxy(proxy, "src/NFTMarketV2.sol:NFTMarketV2", "");
        vm.stopBroadcast();

        console.log("NFTMarket proxy upgraded to V2:", proxy);
    }
}
