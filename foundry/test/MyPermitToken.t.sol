// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";

contract MyPermitTokenTest is Test {
    uint256 internal constant TOTAL = 1000 * 10 ** 18;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    uint256 internal ownerPrivateKey;
    address internal owner;
    address internal spender;
    MyPermitToken internal token;

    function setUp() public {
        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);
        spender = makeAddr("spender");
        token = new MyPermitToken(owner);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), TOTAL);
        assertEq(token.balanceOf(owner), TOTAL);
    }

    function test_PermitSetsAllowance() public {
        uint256 value = 250 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(owner);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), nonce + 1);
    }
}
