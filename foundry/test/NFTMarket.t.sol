// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1363Token} from "../src/ERC1363.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    ERC1363Token internal token;
    MyNFT internal nft;
    NFTMarket internal market;

    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    address internal buyer2 = makeAddr("buyer2");

    uint256 internal constant INITIAL_SUPPLY = 1_000_000;
    uint256 internal constant PRICE = 100 ether;

    function setUp() public {
        token = new ERC1363Token("PayToken", "PAY", INITIAL_SUPPLY);
        nft = new MyNFT();
        market = new NFTMarket(address(token), address(nft));

        nft.safeMint(seller, "ipfs://token-0");

        token.transfer(buyer, PRICE);
        token.transfer(buyer2, PRICE);
    }

    function test_ListAndBuyNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), seller);

        vm.prank(buyer);
        token.approve(address(market), PRICE);

        vm.prank(buyer);
        market.buyNFT(0);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);

        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_BuyNFTViaTransferAndCall() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        vm.prank(buyer2);
        token.transferAndCall(address(market), PRICE, abi.encode(uint256(0)));

        assertEq(nft.ownerOf(0), buyer2);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(address(market)), 0);
    }

    function test_RevertWhenTransferAndCallPriceMismatch() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        vm.prank(buyer2);
        vm.expectRevert("incorrect price");
        token.transferAndCall(
            address(market),
            PRICE - 1,
            abi.encode(uint256(0))
        );
    }
}
