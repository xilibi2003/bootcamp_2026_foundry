// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract TokenVestingTest is Test {
    uint256 internal constant TOTAL_ALLOCATION = 1_000_000 ether;

    MockERC20 internal token;
    TokenVesting internal vesting;

    address internal deployer = makeAddr("deployer");
    address internal beneficiary = makeAddr("beneficiary");

    function setUp() public {
        vm.startPrank(deployer);
        token = new MockERC20("Mock Token", "MTK", deployer, TOTAL_ALLOCATION);
        vesting = new TokenVesting(beneficiary, address(token));
        token.transfer(address(vesting), TOTAL_ALLOCATION);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.released(), 0);
        assertEq(token.balanceOf(address(vesting)), TOTAL_ALLOCATION);
        assertEq(vesting.releasable(), 0);
    }

    function test_Release_RevertBeforeCliff() public {
        vm.expectRevert(TokenVesting.NothingToRelease.selector);
        vesting.release();
    }

    function test_Release_FirstMonthAfterCliff() public {
        vm.warp(vesting.cliffEndTimestamp());

        uint256 expectedUnlocked = vesting.vestedAmount(block.timestamp);
        assertEq(vesting.releasable(), expectedUnlocked);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), expectedUnlocked);
        assertEq(vesting.released(), expectedUnlocked);
        assertEq(token.balanceOf(address(vesting)), TOTAL_ALLOCATION - expectedUnlocked);
    }

    function test_Release_AfterThreeUnlockedMonths() public {
        vm.warp(vesting.cliffEndTimestamp() + 2 * 30 days);

        uint256 expectedUnlocked = vesting.vestedAmount(block.timestamp);
        assertEq(vesting.releasable(), expectedUnlocked);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), expectedUnlocked);
        assertEq(vesting.released(), expectedUnlocked);
    }

    function test_Release_InMultipleCallsAcrossMonths() public {
        vm.warp(vesting.cliffEndTimestamp());
        uint256 firstReleaseAmount = vesting.vestedAmount(block.timestamp);
        vesting.release();

        vm.warp(vesting.cliffEndTimestamp() + 5 * 30 days);
        uint256 totalUnlocked = vesting.vestedAmount(block.timestamp);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), totalUnlocked);
        assertEq(vesting.released(), totalUnlocked);
        assertEq(firstReleaseAmount, TOTAL_ALLOCATION / 24);
        assertEq(vesting.releasable(), 0);
    }

    function test_Release_AllTokensAfterFullVesting() public {
        vm.warp(vesting.cliffEndTimestamp() + 23 * 30 days);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(), TOTAL_ALLOCATION);
        assertEq(vesting.releasable(), 0);
    }

    function test_Release_RevertWhenAlreadyReleasedForCurrentMonth() public {
        vm.warp(vesting.cliffEndTimestamp());
        vesting.release();

        vm.expectRevert(TokenVesting.NothingToRelease.selector);
        vesting.release();
    }
}
