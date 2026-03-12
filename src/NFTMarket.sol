// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1363Receiver} from "./IERC1363Receiver.sol";

contract NFTMarket is IERC1363Receiver, ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
    }

    IERC20 public immutable paymentToken;
    IERC721 public immutable nft;

    mapping(uint256 tokenId => Listing) public listings;

    event Listed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event Purchased(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    constructor(address paymentToken_, address nft_) {
        require(paymentToken_ != address(0), "invalid token");
        require(nft_ != address(0), "invalid nft");

        paymentToken = IERC20(paymentToken_);
        nft = IERC721(nft_);
    }

    function list(uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "price is zero");
        require(nft.ownerOf(tokenId) == msg.sender, "not owner");
        require(listings[tokenId].seller == address(0), "already listed");

        nft.transferFrom(msg.sender, address(this), tokenId);
        listings[tokenId] = Listing({seller: msg.sender, price: price});

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256 tokenId) external nonReentrant {
        Listing memory listing = _getListing(tokenId);

        require(
            paymentToken.transferFrom(msg.sender, address(this), listing.price),
            "token transfer failed"
        );

        _completePurchase(tokenId, msg.sender, listing, listing.price);
    }

    function onTransferReceived(
        address,
        address from,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bytes4) {
        require(msg.sender == address(paymentToken), "unsupported token");
        require(data.length == 32, "invalid data");

        uint256 tokenId = abi.decode(data, (uint256));
        Listing memory listing = _getListing(tokenId);

        _completePurchase(tokenId, from, listing, amount);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _completePurchase(
        uint256 tokenId,
        address buyer,
        Listing memory listing,
        uint256 amount
    ) private {
        require(amount == listing.price, "incorrect price");

        delete listings[tokenId];

        require(
            paymentToken.transfer(listing.seller, amount),
            "pay seller failed"
        );
        nft.transferFrom(address(this), buyer, tokenId);

        emit Purchased(buyer, listing.seller, tokenId, amount);
    }

    function _getListing(
        uint256 tokenId
    ) private view returns (Listing memory listing) {
        listing = listings[tokenId];
        require(listing.seller != address(0), "not listed");
    }
}
