// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {esRNT} from "../src/ESRnt.sol";

contract DeployESRnt is Script {
    function run() external returns (esRNT) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deploying esRNT...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(privateKey);

        esRNT token = new esRNT();

        vm.stopBroadcast();

        console.log("esRNT deployed at:", address(token));

        return token;
    }
}
