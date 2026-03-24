// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20MemeFactory} from "../src/ERC20MemeFactory.sol";
import {ERC20Meme} from "../src/ERC20Meme.sol";

contract ERC20MemeFactoryTest is Test {
    ERC20MemeFactory internal factory;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        factory = new ERC20MemeFactory();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_DeployMeme_InitializesClone() public {
        vm.prank(alice);
        address tokenAddr = factory.deployMeme(
            "DOGE",
            1_000_000 ether,
            100 ether,
            0.01 ether
        );

        ERC20Meme token = ERC20Meme(tokenAddr);
        (address tokenOwner, uint256 tokenMintFee) = factory.memeConfigs(tokenAddr);

        assertTrue(factory.isMemeToken(tokenAddr));
        assertEq(token.name(), "DOGE");
        assertEq(token.symbol(), "DOGE");
        assertEq(token.factory(), address(factory));
        assertEq(tokenOwner, alice);
        assertEq(token.maxSupply(), 1_000_000 ether);
        assertEq(token.perMint(), 100 ether);
        assertEq(tokenMintFee, 0.01 ether);
        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_MintMeme_MintsPerMintToCaller() public {
        vm.prank(alice);
        address tokenAddr = factory.deployMeme(
            "PEPE",
            10_000 ether,
            25 ether,
            1 ether
        );

        ERC20Meme token = ERC20Meme(tokenAddr);
        uint256 aliceBefore = alice.balance;
        uint256 factoryBefore = address(factory).balance;

        vm.prank(bob);
        uint256 mintedAmount = factory.mintMeme{value: 1 ether}(tokenAddr);

        assertEq(mintedAmount, 25 ether);
        assertEq(token.balanceOf(bob), 25 ether);
        assertEq(token.totalSupply(), 25 ether);
        assertEq(alice.balance, aliceBefore + 0.05 ether);
        assertEq(address(factory).balance, factoryBefore + 0.95 ether);
    }

    function test_MintMeme_RevertWhenExceedsMaxSupply() public {
        vm.prank(alice);
        address tokenAddr = factory.deployMeme("FROG", 10 ether, 6 ether, 0.2 ether);

        vm.prank(alice);
        factory.mintMeme{value: 0.2 ether}(tokenAddr);

        vm.prank(bob);
        vm.expectRevert(ERC20Meme.ExceedsMaxSupply.selector);
        factory.mintMeme{value: 0.2 ether}(tokenAddr);
    }

    function test_MintMeme_RevertForIncorrectEthAmount() public {
        vm.prank(alice);
        address tokenAddr = factory.deployMeme("CAT", 100 ether, 10 ether, 1 ether);

        vm.prank(bob);
        vm.expectRevert(ERC20MemeFactory.InvalidMintFee.selector);
        factory.mintMeme{value: 0.5 ether}(tokenAddr);
    }

    function test_MintMeme_RevertForUnknownToken() public {
        vm.expectRevert(ERC20MemeFactory.InvalidToken.selector);
        factory.mintMeme{value: 1 ether}(address(0x1234));
    }

    function testFuzz_DeploysIndependentClones(
        uint256 totalSupplyA,
        uint256 perMintA,
        uint256 totalSupplyB,
        uint256 perMintB
    ) public {
        totalSupplyA = bound(totalSupplyA, 0, type(uint128).max);
        perMintA = bound(perMintA, 0, type(uint128).max);
        totalSupplyB = bound(totalSupplyB, 0, type(uint128).max);
        perMintB = bound(perMintB, 0, type(uint128).max);

        vm.prank(alice);
        address tokenAAddr = factory.deployMeme(
            "AAA",
            totalSupplyA,
            perMintA,
            0.001 ether
        );

        vm.prank(bob);
        address tokenBAddr = factory.deployMeme(
            "BBB",
            totalSupplyB,
            perMintB,
            0.002 ether
        );

        ERC20Meme tokenA = ERC20Meme(tokenAAddr);
        ERC20Meme tokenB = ERC20Meme(tokenBAddr);
        (address tokenAOwner, uint256 tokenAMintFee) = factory.memeConfigs(
            tokenAAddr
        );
        (address tokenBOwner, uint256 tokenBMintFee) = factory.memeConfigs(
            tokenBAddr
        );

        assertTrue(tokenAAddr != tokenBAddr);
        assertEq(tokenA.maxSupply(), totalSupplyA);
        assertEq(tokenB.maxSupply(), totalSupplyB);
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenB.balanceOf(bob), 0);
        assertEq(tokenA.totalSupply(), 0);
        assertEq(tokenB.totalSupply(), 0);
        assertEq(tokenA.perMint(), perMintA);
        assertEq(tokenB.perMint(), perMintB);
        assertEq(tokenAMintFee, 0.001 ether);
        assertEq(tokenBMintFee, 0.002 ether);
        assertEq(tokenAOwner, alice);
        assertEq(tokenBOwner, bob);
    }
}
