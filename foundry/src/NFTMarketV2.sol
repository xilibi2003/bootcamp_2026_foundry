// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NFTMarket} from "./NFTMarket.sol";

/// @custom:oz-upgrades-from src/NFTMarket.sol:NFTMarket
contract NFTMarketV2 is NFTMarket {
    using ECDSA for bytes32;

    error InvalidListingSignature();
    error ListingSignatureExpired();

    bytes32 public constant PERMIT_LIST_TYPEHASH =
        keccak256("PermitList(uint256 tokenId,uint256 price,uint256 deadline)");

    function PermitList(uint256 tokenId, uint256 price, uint256 deadline, bytes memory signature)
        public
        view
        returns (bool)
    {
        if (deadline < block.timestamp) {
            return false;
        }

        address seller = nft.ownerOf(tokenId);
        return getPermitListDigest(tokenId, price, deadline).recover(signature) == seller;
    }

    function getPermitListDigest(uint256 tokenId, uint256 price, uint256 deadline) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(PERMIT_LIST_TYPEHASH, tokenId, price, deadline));

        bytes32 messageHash = keccak256(abi.encode(address(this), block.chainid, structHash));

        return MessageHashUtils.toEthSignedMessageHash(messageHash);
    }

    function permitBuyV2(uint256 tokenId, bytes calldata signature) external nonReentrant {
        (bytes memory whitelistSignature, uint256 price, uint256 deadline, bytes memory listSignature) =
            abi.decode(signature, (bytes, uint256, uint256, bytes));

        if (!PermitWhiteBuyer(msg.sender, whitelistSignature)) {
            revert InvalidWhitelistSignature();
        }
        if (deadline < block.timestamp) {
            revert ListingSignatureExpired();
        }
        if (!PermitList(tokenId, price, deadline, listSignature)) {
            revert InvalidListingSignature();
        }
        if (price == 0) revert PriceIsZero();
        if (price > type(uint96).max) revert PriceOverflow();

        address seller = nft.ownerOf(tokenId);
        Listing memory listing = Listing({seller: seller, price: uint96(price)});

        if (!paymentToken.transferFrom(msg.sender, seller, price)) {
            revert TokenTransferFailed();
        }

        _completePurchase(tokenId, msg.sender, listing, price, true);
    }
}
