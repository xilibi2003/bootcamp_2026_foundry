// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

import {MyToken} from "../src/MyToken.sol";

contract TokenScript is Script {
    MyToken public token;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address deployer = vm.addr(privateKey);

        token = new MyToken(deployer);
        vm.stopBroadcast();
    }
}
