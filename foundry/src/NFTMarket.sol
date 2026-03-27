// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1363Receiver} from "./IERC1363Receiver.sol";

contract NFTMarket is IERC1363Receiver, ReentrancyGuard {
    using ECDSA for bytes32;

    error InvalidToken();
    error InvalidNft();
    error InvalidSigner();
    error PriceIsZero();
    error PriceOverflow();
    error NotOwner();
    error AlreadyListed();
    error UsePermitBuy();
    error InvalidWhitelistSignature();
    error TokenTransferFailed();
    error UnsupportedToken();
    error IncorrectPrice();
    error SellerNotOwner();
    error PaySellerFailed();
    error NotListed();

    struct Listing {
        address seller; // 20 byte => 160 bit
        uint96 price; // 12 byte => 96 bit
    }

    bytes32 public constant PERMIT_WHITE_BUYER_TYPEHASH =
        keccak256("PermitWhiteBuyer(address whitelist)");

    IERC20 public immutable paymentToken;
    IERC721 public immutable nft;
    address public immutable whitelistSigner;

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

    constructor(address paymentToken_, address nft_, address whitelistSigner_) {
        if (paymentToken_ == address(0)) revert InvalidToken();
        if (nft_ == address(0)) revert InvalidNft();
        if (whitelistSigner_ == address(0)) revert InvalidSigner();

        paymentToken = IERC20(paymentToken_);
        nft = IERC721(nft_);
        whitelistSigner = whitelistSigner_;
    }

    // token
    function list(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert PriceIsZero();
        if (price > type(uint96).max) revert PriceOverflow();
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (listings[tokenId].seller != address(0)) revert AlreadyListed();

        // forge-lint: disable-next-line(unsafe-typecast)
        listings[tokenId] = Listing({seller: msg.sender, price: uint96(price)});

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256) external pure {
        revert UsePermitBuy();
    }

    function PermitWhiteBuyer(
        address whitelist,
        bytes memory signature
    ) public view returns (bool) {
        return
            getPermitWhiteBuyerDigest(whitelist).recover(signature) ==
            whitelistSigner;
    }

    function getPermitWhiteBuyerDigest(
        address whitelist
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_WHITE_BUYER_TYPEHASH, whitelist)
        );

        bytes32 messageHash = keccak256(
            abi.encode(address(this), block.chainid, structHash)
        );

        return MessageHashUtils.toEthSignedMessageHash(messageHash);
    }

    function permitBuy(
        uint256 tokenId,
        bytes calldata signature
    ) external nonReentrant {
        if (!PermitWhiteBuyer(msg.sender, signature)) {
            revert InvalidWhitelistSignature();
        }

        Listing memory listing = _getListing(tokenId);

        if (!paymentToken.transferFrom(msg.sender, listing.seller, listing.price)) {
            revert TokenTransferFailed();
        }

        _completePurchase(tokenId, msg.sender, listing, listing.price, true);
    }

    function onTransferReceived(
        address,
        address from,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bytes4) {
        if (msg.sender != address(paymentToken)) revert UnsupportedToken();
        (uint256 tokenId, bytes memory signature) = abi.decode(
            data,
            (uint256, bytes)
        );
        if (!PermitWhiteBuyer(from, signature)) {
            revert InvalidWhitelistSignature();
        }

        Listing memory listing = _getListing(tokenId);

        _completePurchase(tokenId, from, listing, amount, false);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _completePurchase(
        uint256 tokenId,
        address buyer,
        Listing memory listing,
        uint256 amount,
        bool alreadyPaidSeller
    ) private {
        if (amount != listing.price) revert IncorrectPrice();
        if (nft.ownerOf(tokenId) != listing.seller) revert SellerNotOwner();

        delete listings[tokenId];

        if (!alreadyPaidSeller && !paymentToken.transfer(listing.seller, amount)) {
            revert PaySellerFailed();
        }
        nft.transferFrom(listing.seller, buyer, tokenId);

        emit Purchased(buyer, listing.seller, tokenId, amount);
    }

    function _getListing(
        uint256 tokenId
    ) private view returns (Listing memory listing) {
        listing = listings[tokenId];
        if (listing.seller == address(0)) revert NotListed();
    }
}
