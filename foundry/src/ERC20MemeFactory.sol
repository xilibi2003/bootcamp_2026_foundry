// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ERC20Meme} from "./ERC20Meme.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32);
}

interface IUniswapV2Router02 {
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

contract ERC20MemeFactory {
    using SafeERC20 for IERC20;

    struct MemeConfig {
        address owner;
        uint256 mintFee;
    }

    error InvalidToken();
    error InvalidMintFee();
    error OwnerFeeTransferFailed();
    error InvalidAddress();
    error InsufficientMyTokenLiquidity();
    error UniswapPriceNotBetter();

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
    event LiquidityAdded(
        address indexed tokenAddr,
        uint256 memeAmount,
        uint256 myTokenAmount
    );
    event MemeBought(
        address indexed buyer,
        address indexed tokenAddr,
        uint256 ethIn,
        uint256 memeOut
    );

    address public immutable IMPLEMENTATION;
    address public immutable MY_TOKEN;
    address public immutable UNISWAP_FACTORY;
    address public immutable UNISWAP_ROUTER;
    mapping(address token => bool) public isMemeToken;
    mapping(address token => MemeConfig) public memeConfigs;

    constructor(
        address myToken_,
        address uniswapFactory_,
        address uniswapRouter_
    ) {
        if (
            myToken_ == address(0) ||
            uniswapFactory_ == address(0) ||
            uniswapRouter_ == address(0)
        ) {
            revert InvalidAddress();
        }

        IMPLEMENTATION = address(new ERC20Meme());
        MY_TOKEN = myToken_;
        UNISWAP_FACTORY = uniswapFactory_;
        UNISWAP_ROUTER = uniswapRouter_;
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

        mintedAmount = token.mintTo(address(this));
        uint256 liquidityMeme = (mintedAmount * 5) / 100;
        uint256 userAmount = mintedAmount - liquidityMeme;

        IERC20(tokenAddr).safeTransfer(msg.sender, userAmount);
        _addMemeLiquidity(tokenAddr, token, liquidityMeme, mintFee);

        emit MemeMinted(msg.sender, tokenAddr, mintedAmount);
    }

    function buyMeme(
        address tokenAddr,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        if (!isMemeToken[tokenAddr]) revert InvalidToken();

        MemeConfig memory config = memeConfigs[tokenAddr];
        ERC20Meme token = ERC20Meme(tokenAddr);

        address[] memory path = new address[](3);
        path[0] = IUniswapV2Router02(UNISWAP_ROUTER).WETH();
        path[1] = MY_TOKEN;
        path[2] = tokenAddr;

        uint256[] memory quotedAmounts = IUniswapV2Router02(UNISWAP_ROUTER)
            .getAmountsOut(msg.value, path);
        uint256 mintQuote = (msg.value * token.perMint()) / config.mintFee;

        if (quotedAmounts[quotedAmounts.length - 1] <= mintQuote) {
            revert UniswapPriceNotBetter();
        }

        amounts = IUniswapV2Router02(UNISWAP_ROUTER).swapExactETHForTokens{
            value: msg.value
        }(amountOutMin, path, msg.sender, deadline);

        emit MemeBought(
            msg.sender,
            tokenAddr,
            msg.value,
            amounts[amounts.length - 1]
        );
    }

    function _addMemeLiquidity(
        address tokenAddr,
        ERC20Meme token,
        uint256 memeAmount,
        uint256 mintFee
    ) internal {
        if (memeAmount == 0) return;

        uint256 myTokenAmount = _quoteMyTokenLiquidity(
            tokenAddr,
            token.perMint(),
            memeAmount,
            mintFee
        );

        if (IERC20(MY_TOKEN).balanceOf(address(this)) < myTokenAmount) {
            revert InsufficientMyTokenLiquidity();
        }

        IERC20(MY_TOKEN).forceApprove(UNISWAP_ROUTER, myTokenAmount);
        IERC20(tokenAddr).forceApprove(UNISWAP_ROUTER, memeAmount);

        IUniswapV2Router02(UNISWAP_ROUTER).addLiquidity(
            MY_TOKEN,
            tokenAddr,
            myTokenAmount,
            memeAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit LiquidityAdded(tokenAddr, memeAmount, myTokenAmount);
    }

    function _quoteMyTokenLiquidity(
        address tokenAddr,
        uint256 perMint,
        uint256 memeAmount,
        uint256 mintFee
    ) internal view returns (uint256 myTokenAmount) {
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(
            MY_TOKEN,
            tokenAddr
        );

        if (pair == address(0)) {
            return (memeAmount * mintFee) / perMint;
        }

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        if (reserve0 == 0 || reserve1 == 0) {
            return (memeAmount * mintFee) / perMint;
        }

        address token0 = IUniswapV2Pair(pair).token0();
        if (token0 == MY_TOKEN) {
            return (uint256(reserve0) * memeAmount) / uint256(reserve1);
        }

        return (uint256(reserve1) * memeAmount) / uint256(reserve0);
    }
}
