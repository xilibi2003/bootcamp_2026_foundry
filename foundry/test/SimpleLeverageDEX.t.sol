// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleLeverageDEX} from "../src/SimpleLeverageDEX.sol";

contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX internal dex;
    IERC20 internal usdc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal liquidator = makeAddr("liquidator");

    uint256 internal constant INITIAL_MINT = 1_000_000 ether;

    function setUp() public {
        dex = new SimpleLeverageDEX(1_000 ether, 1_000_000 ether);
        usdc = dex.USDC();

        dex.mintUSDC(alice, INITIAL_MINT);
        dex.mintUSDC(bob, INITIAL_MINT);
        dex.mintUSDC(liquidator, INITIAL_MINT);
        dex.mintUSDC(address(dex), INITIAL_MINT);

        vm.prank(alice);
        usdc.approve(address(dex), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(dex), type(uint256).max);
    }

    function test_OpenLongPosition_RecordsPositiveVirtualETH() public {
        vm.prank(alice);
        dex.openPosition(1_000 ether, 2, true);

        (uint256 margin, uint256 borrowed, int256 position) = dex.positions(alice);

        assertEq(margin, 1_000 ether);
        assertEq(borrowed, 1_000 ether);
        assertGt(position, 0);
        assertLt(dex.vETHAmount(), 1_000 ether);
        assertGt(dex.vUSDCAmount(), 1_000_000 ether);
    }

    function test_CloseLongPosition_ProfitsWhenPriceGoesUp() public {
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.openPosition(1_000 ether, 3, true);

        vm.prank(bob);
        dex.openPosition(5_000 ether, 4, true);

        int256 pnlBeforeClose = dex.calculatePnL(alice);
        assertGt(pnlBeforeClose, 0);

        vm.prank(alice);
        dex.closePosition();

        assertGt(usdc.balanceOf(alice), aliceBalanceBefore);
        (, , int256 positionAfterClose) = dex.positions(alice);
        assertEq(positionAfterClose, 0);
    }

    function test_CloseShortPosition_ProfitsWhenPriceGoesDown() public {
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.openPosition(1_000 ether, 3, false);

        vm.prank(bob);
        dex.openPosition(5_000 ether, 4, false);

        int256 pnlBeforeClose = dex.calculatePnL(alice);
        assertGt(pnlBeforeClose, 0);

        vm.prank(alice);
        dex.closePosition();

        assertGt(usdc.balanceOf(alice), aliceBalanceBefore);
    }

    function test_LiquidatePosition_WhenLossExceedsEightyPercentMargin() public {
        uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);

        vm.prank(alice);
        dex.openPosition(1_000 ether, 10, true);

        vm.prank(bob);
        dex.openPosition(4_800 ether, 10, false);

        vm.prank(liquidator);
        dex.liquidatePosition(alice);

        assertGt(usdc.balanceOf(liquidator), liquidatorBalanceBefore);
        (, , int256 positionAfterLiquidation) = dex.positions(alice);
        assertEq(positionAfterLiquidation, 0);
    }

    function test_CannotLiquidateHealthyPosition() public {
        vm.prank(alice);
        dex.openPosition(1_000 ether, 2, true);

        vm.prank(liquidator);
        vm.expectRevert(SimpleLeverageDEX.NotLiquidatable.selector);
        dex.liquidatePosition(alice);
    }
}
