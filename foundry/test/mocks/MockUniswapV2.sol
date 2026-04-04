// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;

    function initialize(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves()
        external
        view
        returns (uint112, uint112, uint32)
    {
        return (reserve0, reserve1, 0);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }
}

contract MockUniswapV2Router02 {
    using SafeERC20 for IERC20;

    address public immutable WETH;

    uint256[] internal quoteAmounts;
    uint256[] internal swapAmounts;

    address[] public lastSwapPath;
    uint256 public lastSwapValue;
    address public lastSwapTo;

    uint256 public lastLiquidityAmountMyToken;
    uint256 public lastLiquidityAmountMeme;

    constructor(address weth_) {
        WETH = weth_;
    }

    function setQuoteAmounts(uint256[] calldata amounts_) external {
        delete quoteAmounts;
        for (uint256 i = 0; i < amounts_.length; i++) {
            quoteAmounts.push(amounts_[i]);
        }
    }

    function setSwapAmounts(uint256[] calldata amounts_) external {
        delete swapAmounts;
        for (uint256 i = 0; i < amounts_.length; i++) {
            swapAmounts.push(amounts_[i]);
        }
    }

    function getAmountsOut(
        uint256,
        address[] calldata
    ) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](quoteAmounts.length);
        for (uint256 i = 0; i < quoteAmounts.length; i++) {
            amounts[i] = quoteAmounts[i];
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256,
        uint256,
        address,
        uint256
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBDesired);

        lastLiquidityAmountMyToken = amountADesired;
        lastLiquidityAmountMeme = amountBDesired;

        return (amountADesired, amountBDesired, amountADesired + amountBDesired);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external payable returns (uint256[] memory amounts) {
        amounts = new uint256[](swapAmounts.length);
        for (uint256 i = 0; i < swapAmounts.length; i++) {
            amounts[i] = swapAmounts[i];
        }

        require(amounts.length == path.length, "bad path len");
        require(amounts[amounts.length - 1] >= amountOutMin, "slippage");

        delete lastSwapPath;
        for (uint256 i = 0; i < path.length; i++) {
            lastSwapPath.push(path[i]);
        }

        lastSwapValue = msg.value;
        lastSwapTo = to;

        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);
        return amounts;
    }
}
