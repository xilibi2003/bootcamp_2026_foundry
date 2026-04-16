// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {
    error InvalidAmount();
    error InvalidLeverage();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error NotLiquidatable();
    error SelfLiquidationNotAllowed();

    uint256 public constant BPS = 10_000;
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8_000;

    uint256 public vK;
    uint256 public vETHAmount;
    uint256 public vUSDCAmount;

    IERC20 public USDC; // 自己创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC
        uint256 borrowed; // 借入的资金
        int256 position; // 虚拟 eth 持仓
    }

    mapping(address => PositionInfo) public positions;

    constructor(uint256 vEth, uint256 vUSDC) {
        if (vEth == 0 || vUSDC == 0) revert InvalidAmount();

        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
        USDC = IERC20(address(new MockUSDC()));
    }

    function mintUSDC(address to, uint256 amount) external {
        MockUSDC(address(USDC)).mint(to, amount);
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint256 level, bool long) external {
        if (positions[msg.sender].position != 0) revert PositionAlreadyOpen();
        if (_margin == 0) revert InvalidAmount();
        if (level < 1) revert InvalidLeverage();

        PositionInfo storage pos = positions[msg.sender];

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        uint256 amount = _margin * level;
        uint256 borrowAmount = amount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        if (long) {
            uint256 baseOut = _getBaseOut(amount);
            vUSDCAmount += amount;
            vETHAmount -= baseOut;
            pos.position = int256(baseOut);
        } else {
            if (amount >= vUSDCAmount) revert InvalidAmount();

            uint256 baseIn = _getBaseInForQuoteOut(amount);
            vUSDCAmount -= amount;
            vETHAmount += baseIn;
            pos.position = -int256(baseIn);
        }
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        PositionInfo memory position = positions[msg.sender];
        if (position.position == 0) revert NoOpenPosition();

        int256 pnl = calculatePnL(msg.sender);
        uint256 payout = _equityAfterPnl(position.margin, pnl);

        _closePosition(msg.sender, position);

        if (payout != 0) {
            USDC.transfer(msg.sender, payout);
        }
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        if (_user == msg.sender) revert SelfLiquidationNotAllowed();

        PositionInfo memory position = positions[_user];
        if (position.position == 0) revert NoOpenPosition();

        int256 pnl = calculatePnL(_user);
        int256 equity = int256(position.margin) + pnl;
        if (equity > int256(position.margin / 5)) revert NotLiquidatable();

        uint256 payout = _equityAfterPnl(position.margin, pnl);
        _closePosition(_user, position);

        if (payout != 0) {
            USDC.transfer(msg.sender, payout);
        }
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory position = positions[user];
        if (position.position == 0) revert NoOpenPosition();

        uint256 notional = position.margin + position.borrowed;

        if (position.position > 0) {
            uint256 quoteOut = _getQuoteOutForBaseIn(
                uint256(position.position)
            );
            return int256(quoteOut) - int256(notional);
        }

        uint256 quoteIn = _getQuoteInForBaseOut(uint256(-position.position));
        return int256(notional) - int256(quoteIn);
    }

    function getMarkPrice() external view returns (uint256) {
        return (vUSDCAmount * 1e18) / vETHAmount;
    }

    function _closePosition(
        address user,
        PositionInfo memory position
    ) internal {
        if (position.position > 0) {
            uint256 baseIn = uint256(position.position);
            uint256 quoteOut = _getQuoteOutForBaseIn(baseIn);
            vETHAmount += baseIn;
            vUSDCAmount -= quoteOut;
        } else {
            uint256 baseOut = uint256(-position.position);
            uint256 quoteIn = _getQuoteInForBaseOut(baseOut);
            vETHAmount -= baseOut;
            vUSDCAmount += quoteIn;
        }

        delete positions[user];
    }

    function _equityAfterPnl(
        uint256 margin,
        int256 pnl
    ) internal pure returns (uint256) {
        int256 equity = int256(margin) + pnl;
        if (equity <= 0) {
            return 0;
        }

        return uint256(equity);
    }

    // quoteIn -> vUSDC
    function _getBaseOut(uint256 quoteIn) internal view returns (uint256) {
        uint256 newUSDCReserve = vUSDCAmount + quoteIn;
        uint256 newETHReserve = vK / newUSDCReserve;
        return vETHAmount - newETHReserve;
    }

    // 卖 ETH -> vUSDC

    function _getBaseInForQuoteOut(
        uint256 quoteOut
    ) internal view returns (uint256) {
        uint256 newUSDCReserve = vUSDCAmount - quoteOut;
        uint256 newETHReserve = vK / newUSDCReserve;
        return newETHReserve - vETHAmount;
    }

    function _getQuoteOutForBaseIn(
        uint256 baseIn
    ) internal view returns (uint256) {
        uint256 newETHReserve = vETHAmount + baseIn;
        uint256 newUSDCReserve = vK / newETHReserve;
        return vUSDCAmount - newUSDCReserve;
    }

    function _getQuoteInForBaseOut(
        uint256 baseOut
    ) internal view returns (uint256) {
        uint256 newETHReserve = vETHAmount - baseOut;
        uint256 newUSDCReserve = vK / newETHReserve;
        return newUSDCReserve - vUSDCAmount;
    }
}
