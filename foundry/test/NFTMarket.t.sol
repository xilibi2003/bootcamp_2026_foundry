// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1363Token} from "../src/ERC1363.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {NFTMarketV2} from "../src/NFTMarketV2.sol";

contract NFTMarketTest is Test {
    ERC1363Token internal token;
    MyNFT internal nft;
    NFTMarket internal market;

    uint256 internal adminPrivateKey = 0xA11CE;
    address internal admin;
    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    address internal buyer2 = makeAddr("buyer2");
    address internal outsider = makeAddr("outsider");
    uint256 internal sellerPrivateKey = 0xBEEF;
    address internal signedSeller;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000;
    uint256 internal constant PRICE = 100 ether;

    function setUp() public {
        admin = vm.addr(adminPrivateKey);
        signedSeller = vm.addr(sellerPrivateKey);
        token = new ERC1363Token("PayToken", "PAY", INITIAL_SUPPLY);
        MyNFT nftImpl = new MyNFT();
        nft = MyNFT(address(new ERC1967Proxy(address(nftImpl), abi.encodeCall(MyNFT.initialize, (address(this))))));

        NFTMarket marketImpl = new NFTMarket();
        market = NFTMarket(
            address(
                new ERC1967Proxy(
                    address(marketImpl),
                    abi.encodeCall(NFTMarket.initialize, (address(token), address(nft), admin, address(this)))
                )
            )
        );

        nft.safeMint(seller, "ipfs://token-0");
        nft.safeMint(signedSeller, "ipfs://token-1");

        token.transfer(buyer, PRICE);
        token.transfer(buyer2, PRICE);
        token.transfer(outsider, PRICE);
    }

    function test_PermitWhiteBuyer() public {
        bytes memory signature = _signWhitelist(buyer);

        assertTrue(market.PermitWhiteBuyer(buyer, signature));
        assertFalse(market.PermitWhiteBuyer(outsider, signature));
    }

    function test_PermitBuyNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), seller);

        bytes memory signature = _signWhitelist(buyer);

        vm.prank(buyer);
        token.approve(address(market), PRICE);

        vm.prank(buyer);
        market.permitBuy(0, signature);

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

        bytes memory signature = _signWhitelist(buyer2);

        vm.prank(buyer2);
        token.transferAndCall(address(market), PRICE, abi.encode(uint256(0), signature));

        assertEq(nft.ownerOf(0), buyer2);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(address(market)), 0);
    }

    function test_RevertWhenPermitBuyWithInvalidSignature() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        bytes memory signature = _signWhitelist(buyer);

        vm.prank(outsider);
        token.approve(address(market), PRICE);

        vm.prank(outsider);
        vm.expectRevert(NFTMarket.InvalidWhitelistSignature.selector);
        market.permitBuy(0, signature);
    }

    function test_RevertWhenDirectBuyNFTCalled() public {
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.UsePermitBuy.selector);
        market.buyNFT(0);
    }

    function test_RevertWhenTransferAndCallPriceMismatch() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        bytes memory signature = _signWhitelist(buyer2);

        vm.prank(buyer2);
        vm.expectRevert(NFTMarket.IncorrectPrice.selector);
        token.transferAndCall(address(market), PRICE - 1, abi.encode(uint256(0), signature));
    }

    function _signWhitelist(address whitelist) internal view returns (bytes memory) {
        bytes32 digest = market.getPermitWhiteBuyerDigest(whitelist);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_V2PermitBuyWithPermitList() public {
        NFTMarketV2 marketV2 = _deployMarketV2();

        vm.prank(signedSeller);
        nft.setApprovalForAll(address(marketV2), true);

        bytes memory whitelistSignature = _signWhitelistFor(address(marketV2), buyer);
        uint256 deadline = block.timestamp + 1 days;
        bytes memory listSignature = _signPermitList(marketV2, 1, PRICE, deadline);

        vm.prank(buyer);
        token.approve(address(marketV2), PRICE);

        vm.prank(buyer);
        marketV2.permitBuyV2(1, abi.encode(whitelistSignature, PRICE, deadline, listSignature));

        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(signedSeller), PRICE);
    }

    function test_RevertWhenV2PermitListSignatureInvalid() public {
        NFTMarketV2 marketV2 = _deployMarketV2();

        vm.prank(signedSeller);
        nft.setApprovalForAll(address(marketV2), true);

        bytes memory whitelistSignature = _signWhitelistFor(address(marketV2), buyer);
        uint256 deadline = block.timestamp + 1 days;
        bytes memory invalidListSignature = _signPermitList(marketV2, 1, PRICE + 1, deadline);

        vm.prank(buyer);
        token.approve(address(marketV2), PRICE);

        vm.prank(buyer);
        vm.expectRevert(NFTMarketV2.InvalidListingSignature.selector);
        marketV2.permitBuyV2(1, abi.encode(whitelistSignature, PRICE, deadline, invalidListSignature));
    }

    function test_RevertWhenV2PermitListExpired() public {
        NFTMarketV2 marketV2 = _deployMarketV2();

        vm.prank(signedSeller);
        nft.setApprovalForAll(address(marketV2), true);

        uint256 deadline = block.timestamp;
        bytes memory whitelistSignature = _signWhitelistFor(address(marketV2), buyer);
        bytes memory listSignature = _signPermitList(marketV2, 1, PRICE, deadline);

        vm.warp(block.timestamp + 1);

        vm.prank(buyer);
        token.approve(address(marketV2), PRICE);

        vm.prank(buyer);
        vm.expectRevert(NFTMarketV2.ListingSignatureExpired.selector);
        marketV2.permitBuyV2(1, abi.encode(whitelistSignature, PRICE, deadline, listSignature));
    }

    function _signWhitelistFor(address marketAddress, address whitelist) internal view returns (bytes memory) {
        bytes32 digest = NFTMarket(marketAddress).getPermitWhiteBuyerDigest(whitelist);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function _signPermitList(NFTMarketV2 marketV2, uint256 tokenId, uint256 price, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = marketV2.getPermitListDigest(tokenId, price, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function _deployMarketV2() internal returns (NFTMarketV2 marketV2) {
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV2 = NFTMarketV2(
            address(
                new ERC1967Proxy(
                    address(marketV2Impl),
                    abi.encodeCall(NFTMarket.initialize, (address(token), address(nft), admin, address(this)))
                )
            )
        );
    }
}
