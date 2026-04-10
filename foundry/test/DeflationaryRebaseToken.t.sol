// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    DeflationaryRebaseToken
} from "../src/DeflationaryRebaseToken.sol";

contract DeflationaryRebaseTokenTest is Test {
    uint256 private constant INITIAL_SUPPLY = 100_000_000 ether;
    uint256 private constant ONE_YEAR = 365 days;

    DeflationaryRebaseToken internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        token = new DeflationaryRebaseToken(owner);
    }

    function test_InitialSupplyIs100Million() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_RebaseAfterOneYearUpdatesSupplyAndBalances() public {
        uint256 aliceAmount = 60_000_000 ether;
        uint256 bobAmount = 40_000_000 ether;

        vm.startPrank(owner);
        token.transfer(alice, aliceAmount);
        token.transfer(bob, bobAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        assertEq(token.totalSupply(), 99_000_000 ether);
        assertEq(token.balanceOf(alice), 59_400_000 ether);
        assertEq(token.balanceOf(bob), 39_600_000 ether);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_RebaseAfterTwoYearsUsesCompoundedDeflation() public {
        vm.prank(owner);
        token.transfer(alice, INITIAL_SUPPLY);

        vm.warp(block.timestamp + (ONE_YEAR * 2));
        token.rebase();

        assertEq(token.totalSupply(), 98_010_000 ether);
        assertEq(token.balanceOf(alice), 98_010_000 ether);
    }

    function test_RebaseTooEarlyReverts() public {
        vm.warp(block.timestamp + 364 days);
        vm.expectRevert(DeflationaryRebaseToken.RebaseTooEarly.selector);
        token.rebase();
    }

    function test_BalanceOfReflectsRebasedBalanceForPartialHolder() public {
        vm.startPrank(owner);
        token.transfer(alice, 25_000_000 ether);
        token.transfer(bob, 75_000_000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        assertEq(token.balanceOf(alice), 24_750_000 ether);
        assertEq(token.balanceOf(bob), 74_250_000 ether);
    }
}
