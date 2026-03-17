// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployTokenBank is Script {
    function run() external returns (TokenBank) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deploying MyToken and TokenBank...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(privateKey);

        MyToken myToken = new MyToken(deployer);
        TokenBank tokenBank = new TokenBank(address(myToken));

        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(myToken));
        console.log("TokenBank deployed at:", address(tokenBank));

        return tokenBank;
    }
}
