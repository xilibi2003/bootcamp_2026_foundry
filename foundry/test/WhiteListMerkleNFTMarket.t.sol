// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Hashes} from "@openzeppelin/contracts/utils/cryptography/Hashes.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {WhiteListMerkleNFTMarket} from "../src/WhiteListMerkleNFTMarket.sol";

contract WhiteListMerkleNFTMarketTest is Test {
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal buyerPrivateKey = 0xB0B;
    address internal buyer;
    address internal buyer2;
    address internal seller;
    address internal outsider;

    uint256 internal constant PRICE = 100 ether;

    MyPermitToken internal token;
    MyNFT internal nft;
    WhiteListMerkleNFTMarket internal market;
    bytes32 internal merkleRoot;

    function setUp() public {
        buyer = vm.addr(buyerPrivateKey);
        buyer2 = makeAddr("buyer2");
        seller = makeAddr("seller");
        outsider = makeAddr("outsider");

        merkleRoot = Hashes.commutativeKeccak256(_leaf(buyer), _leaf(buyer2));

        token = new MyPermitToken(address(this));
        MyNFT nftImpl = new MyNFT();
        nft = MyNFT(address(new ERC1967Proxy(address(nftImpl), abi.encodeCall(MyNFT.initialize, (address(this))))));
        market = new WhiteListMerkleNFTMarket(address(token), address(nft), merkleRoot);

        nft.safeMint(seller, "ipfs://token-0");

        token.transfer(buyer, PRICE);
        token.transfer(outsider, PRICE);
    }

    function test_MulticallPermitPrePayAndBuyNFTInWhitelist() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        uint256 deadline = block.timestamp + 1 days;
        uint256 discountedPrice = PRICE / 2;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(buyerPrivateKey, buyer, address(market), discountedPrice, deadline);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(buyer2);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(WhiteListMerkleNFTMarket.permitPrePay, (discountedPrice, deadline, v, r, s));
        calls[1] = abi.encodeCall(WhiteListMerkleNFTMarket.buyNFTInWhitelist, (0, proof));

        vm.prank(buyer);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), discountedPrice);
        assertEq(token.balanceOf(buyer), PRICE - discountedPrice);
        assertEq(token.balanceOf(address(market)), 0);
        assertEq(token.allowance(buyer, address(market)), 0);

        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_RevertWhenBuyerNotInWhitelist() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, PRICE);
        vm.stopPrank();

        uint256 deadline = block.timestamp + 1 days;
        uint256 discountedPrice = PRICE / 2;
        uint256 outsiderPrivateKey = 0xBAD;
        address outsiderBuyer = vm.addr(outsiderPrivateKey);
        token.transfer(outsiderBuyer, discountedPrice);

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(outsiderPrivateKey, outsiderBuyer, address(market), discountedPrice, deadline);

        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = _leaf(buyer2);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(WhiteListMerkleNFTMarket.permitPrePay, (discountedPrice, deadline, v, r, s));
        calls[1] = abi.encodeCall(WhiteListMerkleNFTMarket.buyNFTInWhitelist, (0, invalidProof));

        vm.prank(outsiderBuyer);
        vm.expectRevert(WhiteListMerkleNFTMarket.InvalidWhitelistProof.selector);
        market.multicall(calls);
    }

    function _signPermit(uint256 ownerPrivateKey, address owner, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce = token.nonces(owner);
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        return vm.sign(ownerPrivateKey, digest);
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }
}
