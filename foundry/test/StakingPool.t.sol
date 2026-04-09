// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {KKToken} from "../src/KKToken.sol";
import {StakingPool} from "../src/StakingPool.sol";

contract StakingPoolTest is Test {
    KKToken public token;
    StakingPool public pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        token = new KKToken(address(this));
        pool = new StakingPool(token);
        token.transferOwnership(address(pool));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_KKToken_InitialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0, "initial supply should be zero");
    }

    function test_KKToken_OwnerTransferredToPool() public view {
        assertEq(token.owner(), address(pool), "pool should own KK token");
    }

    function test_StakeAndClaim_SingleUserGetsAllRewards() public {
        uint256 startBlock = block.number;
        uint256 stakeAmount = 1 ether;

        vm.prank(alice);
        pool.stake{value: stakeAmount}();

        vm.roll(startBlock + 10);
        uint256 earnedBeforeClaim = pool.earned(alice);

        console.log("single stake amount:", stakeAmount);
        console.log("single earned before claim:", earnedBeforeClaim);

        assertEq(earnedBeforeClaim, 100 ether, "alice pending reward mismatch");

        vm.prank(alice);
        pool.claim();

        console.log("single claimed reward:", token.balanceOf(alice));

        assertEq(token.balanceOf(alice), 100 ether, "alice claim mismatch");
        assertEq(token.totalSupply(), 100 ether, "total supply mismatch");
    }

    function test_StakeAndClaim_MultiUserRewardsAreFair() public {
        uint256 startBlock = block.number;
        uint256 aliceStakeAmount = 1 ether;
        uint256 bobStakeAmount = 3 ether;

        vm.prank(alice);
        pool.stake{value: aliceStakeAmount}();

        vm.roll(startBlock + 10);

        vm.prank(bob);
        pool.stake{value: bobStakeAmount}();

        vm.roll(startBlock + 20);

        uint256 aliceEarned = pool.earned(alice);
        uint256 bobEarned = pool.earned(bob);

        console.log("multi alice stake amount:", aliceStakeAmount);
        console.log("multi bob stake amount:", bobStakeAmount);
        console.log("multi alice earned before claim:", aliceEarned);
        console.log("multi bob earned before claim:", bobEarned);

        assertEq(aliceEarned, 125 ether, "alice earned mismatch");
        assertEq(bobEarned, 75 ether, "bob earned mismatch");

        vm.prank(alice);
        pool.claim();

        vm.prank(bob);
        pool.claim();

        console.log("multi alice claimed reward:", token.balanceOf(alice));
        console.log("multi bob claimed reward:", token.balanceOf(bob));

        assertEq(token.balanceOf(alice), 125 ether, "alice reward mismatch");
        assertEq(token.balanceOf(bob), 75 ether, "bob reward mismatch");
        assertEq(token.totalSupply(), 200 ether, "total supply mismatch");
    }

    function test_Unstake_ReturnsETHAndAutoClaimsRewards() public {
        uint256 startBlock = block.number;
        uint256 initialStakeAmount = 2 ether;
        uint256 unstakeAmount = 1 ether;

        vm.prank(alice);
        pool.stake{value: initialStakeAmount}();

        vm.roll(startBlock + 5);

        uint256 aliceEthBefore = alice.balance;

        vm.prank(alice);
        pool.unstake(unstakeAmount);

        console.log("unstake initial stake amount:", initialStakeAmount);
        console.log("unstake amount:", unstakeAmount);
        console.log("unstake auto-claimed reward:", token.balanceOf(alice));
        console.log("unstake pending reward after auto-claim:", pool.earned(alice));

        assertEq(pool.balanceOf(alice), 1 ether, "remaining stake mismatch");
        assertEq(alice.balance, aliceEthBefore + 1 ether, "unstaked eth mismatch");
        assertEq(token.balanceOf(alice), 50 ether, "unstake should auto-claim");
        assertEq(pool.earned(alice), 0, "pending reward should be claimed");

        vm.roll(startBlock + 10);

        vm.prank(alice);
        pool.claim();

        console.log("unstake final claimed reward:", token.balanceOf(alice));

        assertEq(token.balanceOf(alice), 100 ether, "claimed reward mismatch");
    }

    function test_ClaimWithoutRewardsReverts() public {
        vm.prank(alice);
        pool.stake{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(StakingPool.ZeroAmount.selector);
        pool.claim();
    }

    function test_OnlyOwnerCanMint() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        token.mint(address(this), 1 ether);
    }
}
