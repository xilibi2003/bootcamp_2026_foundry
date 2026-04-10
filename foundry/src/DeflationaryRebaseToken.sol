// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    IERC20Metadata
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    Math
} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title DeflationaryRebaseToken
 * @dev 基于 shares 的 ERC20 rebase Token。
 *      初始发行量 1 亿，每满 1 年在上一年基础上通缩 1%。
 *      用户实际持仓按 shares 占比计算，rebase 后 balanceOf 会自动反映最新余额。
 */
contract DeflationaryRebaseToken is IERC20, IERC20Metadata {
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error RebaseTooEarly();

    uint256 public constant INITIAL_SUPPLY = 100_000_000 ether;
    uint256 public constant REBASE_INTERVAL = 365 days;

    uint256 public constant ANNUAL_BPS = 100;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    string private _name;
    string private _symbol;

    uint256 private immutable _totalShares;
    uint256 private _totalSupply;
    uint256 public lastRebaseTimestamp;

    mapping(address account => uint256) private _shareBalances;
    mapping(address owner => mapping(address spender => uint256))
        private _allowances;

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();

        _name = "Deflationary Rebase Token";
        _symbol = "DRT";
        _totalSupply = INITIAL_SUPPLY;
        _totalShares = INITIAL_SUPPLY;
        lastRebaseTimestamp = block.timestamp;
        _shareBalances[initialOwner] = _totalShares;

        emit Transfer(address(0), initialOwner, INITIAL_SUPPLY);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // balance = share * totalSupply * 0.99 / totalShares
    function balanceOf(address account) public view returns (uint256) {
        return Math.mulDiv(_shareBalances[account], _totalSupply, _totalShares);
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();

        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < value) revert InsufficientAllowance();

        unchecked {
            _allowances[from][msg.sender] = currentAllowance - value;
        }

        emit Approval(from, msg.sender, _allowances[from][msg.sender]);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 每满一年执行一次 1% 通缩；若跨越多个完整年度，会按复利连续执行多次。
     */
    function rebase() external returns (uint256 newTotalSupply) {
        uint256 elapsedYears = (block.timestamp - lastRebaseTimestamp) /
            REBASE_INTERVAL;
        if (elapsedYears == 0) revert RebaseTooEarly();

        newTotalSupply = _totalSupply;

        for (uint256 i = 0; i < elapsedYears; i++) {
            newTotalSupply =
                (newTotalSupply * (BPS_DENOMINATOR - ANNUAL_BPS)) /
                BPS_DENOMINATOR;
        }

        _totalSupply = newTotalSupply;
        lastRebaseTimestamp += elapsedYears * REBASE_INTERVAL;
    }

    function sharesOf(address account) external view returns (uint256) {
        return _shareBalances[account];
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 shareAmount = _sharesForAmount(from, value);
        uint256 fromShares = _shareBalances[from];
        if (fromShares < shareAmount) revert InsufficientBalance();

        unchecked {
            _shareBalances[from] = fromShares - shareAmount;
            _shareBalances[to] += shareAmount;
        }

        emit Transfer(from, to, value);
    }

    function _sharesForAmount(
        address from,
        uint256 amount
    ) internal view returns (uint256 shareAmount) {
        if (amount == 0) {
            return 0;
        }

        uint256 displayedBalance = balanceOf(from);
        if (displayedBalance < amount) revert InsufficientBalance();

        if (displayedBalance == amount) {
            return _shareBalances[from];
        }

        shareAmount = Math.mulDiv(amount, _totalShares, _totalSupply);
        if (Math.mulDiv(shareAmount, _totalSupply, _totalShares) < amount) {
            shareAmount += 1;
        }
    }
}
