// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {KKToken} from "../src/KKToken.sol";
import {StakingPool} from "../src/StakingPool.sol";

contract DeployKKStakingScript is Script {
    function run() external returns (KKToken token, StakingPool pool) {
        vm.startBroadcast();

        token = new KKToken(msg.sender);
        pool = new StakingPool(token);
        token.transferOwnership(address(pool));

        vm.stopBroadcast();
    }
}
