// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ERC20Meme} from "./ERC20Meme.sol";

contract ERC20MemeFactory {
    struct MemeConfig {
        address owner;
        uint256 mintFee;
    }

    error InvalidToken();
    error InvalidMintFee();
    error OwnerFeeTransferFailed();

    event MemeDeployed(
        address indexed creator,
        address indexed tokenAddr,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 mintFee
    );
    event MemeMinted(
        address indexed caller,
        address indexed tokenAddr,
        uint256 amount
    );

    address public immutable IMPLEMENTATION;
    mapping(address token => bool) public isMemeToken;
    mapping(address token => MemeConfig) public memeConfigs;

    constructor() {
        IMPLEMENTATION = address(new ERC20Meme());
    }

    function deployMeme(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 mintFee
    ) external returns (address tokenAddr) {
        tokenAddr = Clones.clone(IMPLEMENTATION);
        isMemeToken[tokenAddr] = true;
        memeConfigs[tokenAddr] = MemeConfig({owner: msg.sender, mintFee: mintFee});

        ERC20Meme(tokenAddr).initialize(symbol, totalSupply, perMint, address(this));

        emit MemeDeployed(
            msg.sender,
            tokenAddr,
            symbol,
            totalSupply,
            perMint,
            mintFee
        );
    }

    function mintMeme(
        address tokenAddr
    ) external payable returns (uint256 mintedAmount) {
        if (!isMemeToken[tokenAddr]) revert InvalidToken();

        MemeConfig memory config = memeConfigs[tokenAddr];
        ERC20Meme token = ERC20Meme(tokenAddr);
        uint256 mintFee = config.mintFee;

        if (msg.value != mintFee) revert InvalidMintFee();

        uint256 ownerFee = (mintFee * 5) / 100;
        if (ownerFee > 0) {
            (bool success, ) = payable(config.owner).call{value: ownerFee}("");
            if (!success) revert OwnerFeeTransferFailed();
        }

        mintedAmount = token.mintTo(msg.sender);
        emit MemeMinted(msg.sender, tokenAddr, mintedAmount);
    }
}
