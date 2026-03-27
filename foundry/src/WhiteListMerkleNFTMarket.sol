// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MyPermitToken} from "./MyPermitToken.sol";

contract WhiteListMerkleNFTMarket is Multicall, ReentrancyGuard {
    error InvalidToken();
    error InvalidNft();
    error InvalidMerkleRoot();
    error PriceIsZero();
    error PriceOverflow();
    error NotOwner();
    error AlreadyListed();
    error NotListed();
    error InvalidWhitelistProof();
    error InsufficientAllowance();
    error SellerNotOwner();
    error TokenTransferFailed();

    struct Listing {
        address seller;
        uint96 price;
    }

    MyPermitToken public immutable paymentToken;
    IERC721 public immutable nft;
    bytes32 public immutable merkleRoot;

    mapping(uint256 tokenId => Listing) public listings;

    event Listed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event PermitPrePaid(address indexed buyer, uint256 amount);
    event Purchased(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    constructor(address paymentToken_, address nft_, bytes32 merkleRoot_) {
        if (paymentToken_ == address(0)) revert InvalidToken();
        if (nft_ == address(0)) revert InvalidNft();
        if (merkleRoot_ == bytes32(0)) revert InvalidMerkleRoot();

        paymentToken = MyPermitToken(paymentToken_);
        nft = IERC721(nft_);
        merkleRoot = merkleRoot_;
    }

    function list(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert PriceIsZero();
        if (price > type(uint96).max) revert PriceOverflow();
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (listings[tokenId].seller != address(0)) revert AlreadyListed();

        listings[tokenId] = Listing({seller: msg.sender, price: uint96(price)});

        emit Listed(msg.sender, tokenId, price);
    }

    function permitPrePay(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        paymentToken.permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        emit PermitPrePaid(msg.sender, amount);
    }

    function buyNFTInWhitelist(
        uint256 tokenId,
        bytes32[] calldata proof
    ) external nonReentrant {
        if (!_isWhitelisted(msg.sender, proof)) revert InvalidWhitelistProof();

        Listing memory listing = _getListing(tokenId);
        uint256 discountedPrice = uint256(listing.price) / 2;

        if (paymentToken.allowance(msg.sender, address(this)) < discountedPrice) {
            revert InsufficientAllowance();
        }
        if (nft.ownerOf(tokenId) != listing.seller) revert SellerNotOwner();

        delete listings[tokenId];

        if (!paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice)) {
            revert TokenTransferFailed();
        }

        nft.transferFrom(listing.seller, msg.sender, tokenId);

        emit Purchased(msg.sender, listing.seller, tokenId, discountedPrice);
    }

    function isWhitelisted(
        address account,
        bytes32[] calldata proof
    ) external view returns (bool) {
        return _isWhitelisted(account, proof);
    }

    function _isWhitelisted(
        address account,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, _leaf(account));
    }

    function _getListing(
        uint256 tokenId
    ) internal view returns (Listing memory listing) {
        listing = listings[tokenId];
        if (listing.seller == address(0)) revert NotListed();
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }
}
