// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external returns (MyToken) {
        // 使用外部 keystore 文件提供的签名者（通过 --account 传入）
        // msg.sender 即为 keystore 对应的钱包地址
        address deployer = msg.sender;

        console.log("Deploying MyToken...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast();

        // 将 1000 MTK 铸造给部署者
        MyToken myToken = new MyToken(deployer);

        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(myToken));
        console.log("Total supply:", myToken.totalSupply());

        return myToken;
    }
}
