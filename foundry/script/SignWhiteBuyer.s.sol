// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract SignWhiteBuyer is Script {
    function run() external view {
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        address whitelist = vm.envAddress("WHITELIST_ADDRESS");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");

        NFTMarket market = NFTMarket(marketAddress);
        bytes32 digest = market.getPermitWhiteBuyerDigest(whitelist);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digest);

        console.log("Admin signer:", vm.addr(adminPrivateKey));
        console.log("Whitelist buyer:", whitelist);
        console.log("Market:", marketAddress);
        console.logBytes32(digest);
        console.log("signature.v:");
        console.logUint(uint256(v));
        console.logBytes32(r);
        console.logBytes32(s);
        console.logBytes(abi.encodePacked(r, s, v));
    }
}
