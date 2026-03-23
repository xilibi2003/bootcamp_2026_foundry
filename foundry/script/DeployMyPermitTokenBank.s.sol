// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployMyPermitTokenBank is Script {
    function run() external returns (MyPermitToken, TokenBank) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deploying MyPermitToken and TokenBank...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(privateKey);

        MyPermitToken myPermitToken = new MyPermitToken(deployer);
        TokenBank tokenBank = new TokenBank(address(myPermitToken));

        vm.stopBroadcast();

        console.log("MyPermitToken deployed at:", address(myPermitToken));
        console.log("TokenBank deployed at:", address(tokenBank));

        return (myPermitToken, tokenBank);
    }
}
