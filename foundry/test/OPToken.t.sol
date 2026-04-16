// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {OPToken} from "../src/OPToken.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract OPTokenTest is Test {
    uint256 internal constant INITIAL_USDT_SUPPLY = 10_000_000 ether;

    OPToken internal optionToken;
    MockERC20 internal usdt;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        usdt = new MockERC20("Mock USDT", "USDT", owner, INITIAL_USDT_SUPPLY);

        vm.prank(owner);
        optionToken = new OPToken(owner, usdt);

        vm.deal(owner, 100 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        vm.startPrank(owner);
        usdt.transfer(alice, 100_000 ether);
        usdt.transfer(bob, 100_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        usdt.approve(address(optionToken), type(uint256).max);

        vm.prank(bob);
        usdt.approve(address(optionToken), type(uint256).max);
    }

    function test_Mint_MintsEquivalentOptionTokensForDepositedETH() public {
        vm.prank(owner);
        optionToken.mint{value: 2 ether}(alice);

        assertEq(optionToken.balanceOf(alice), 2 ether);
        assertEq(optionToken.totalSupply(), 2 ether);
        assertEq(address(optionToken).balance, 2 ether);
    }

    function test_Mint_OnlyOwnerCanMint() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        optionToken.mint{value: 1 ether}(alice);
    }

    function test_Exercise_OnExerciseDateExchangesUSDTForETHAndBurnsOptions() public {
        vm.prank(owner);
        optionToken.mint{value: 1 ether}(alice);

        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        uint256 aliceEthBefore = alice.balance;

        vm.warp(optionToken.EXERCISE_DATE());

        vm.prank(alice);
        optionToken.exercise(1 ether);

        assertEq(optionToken.balanceOf(alice), 0);
        assertEq(optionToken.totalSupply(), 0);
        assertEq(address(optionToken).balance, 0);
        assertEq(alice.balance, aliceEthBefore + 1 ether);
        assertEq(
            usdt.balanceOf(owner),
            ownerUsdtBefore + optionToken.STRIKE_PRICE()
        );
    }

    function test_Exercise_RevertsOutsideExerciseDate() public {
        vm.prank(owner);
        optionToken.mint{value: 1 ether}(alice);

        vm.warp(optionToken.EXERCISE_DATE() - 1);

        vm.prank(alice);
        vm.expectRevert(OPToken.NotExerciseDay.selector);
        optionToken.exercise(1 ether);
    }

    function test_Mint_RevertsAfterExerciseDate() public {
        vm.warp(optionToken.EXERCISE_DATE());

        vm.prank(owner);
        vm.expectRevert(OPToken.MintClosed.selector);
        optionToken.mint{value: 1 ether}(alice);
    }

    function test_Expire_MarksExpiredAndReturnsRemainingETH() public {
        vm.startPrank(owner);
        optionToken.mint{value: 1 ether}(alice);
        optionToken.mint{value: 2 ether}(bob);
        vm.stopPrank();

        uint256 ownerEthBefore = owner.balance;

        vm.warp(optionToken.EXERCISE_DATE());
        vm.prank(alice);
        optionToken.exercise(1 ether);

        assertEq(address(optionToken).balance, 2 ether);
        assertEq(optionToken.balanceOf(bob), 2 ether);

        vm.warp(optionToken.EXERCISE_DATE() + 1 days);
        vm.prank(owner);
        optionToken.expire();

        assertTrue(optionToken.expired());
        assertEq(optionToken.totalSupply(), 2 ether);
        assertEq(optionToken.balanceOf(bob), 2 ether);
        assertEq(address(optionToken).balance, 0);
        assertEq(owner.balance, ownerEthBefore + 2 ether);
    }

    function test_Exercise_RevertsAfterExpire() public {
        vm.prank(owner);
        optionToken.mint{value: 1 ether}(alice);

        vm.warp(optionToken.EXERCISE_DATE() + 1 days);
        vm.prank(owner);
        optionToken.expire();

        vm.prank(alice);
        vm.expectRevert(OPToken.AlreadyExpired.selector);
        optionToken.exercise(1 ether);
    }

    function test_Transfer_RevertsAfterExpire() public {
        vm.prank(owner);
        optionToken.mint{value: 1 ether}(alice);

        vm.warp(optionToken.EXERCISE_DATE() + 1 days);
        vm.prank(owner);
        optionToken.expire();

        vm.prank(alice);
        vm.expectRevert(OPToken.TokenExpired.selector);
        optionToken.transfer(bob, 0.5 ether);
    }
}
