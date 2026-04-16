// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {
    Ownable
} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    SafeERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract OPToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error NotExerciseDay();
    error NotExpired();
    error AlreadyExpired();
    error MintClosed();
    error TransferFailed();
    error TokenExpired();

    uint256 public constant STRIKE_PRICE = 1800 ether;
    uint256 public constant EXERCISE_DATE = 1790812800; // 2026-10-01 00:00:00 UTC
    uint256 public constant EXERCISE_WINDOW = 1 days;

    IERC20 public immutable usdt;
    bool public expired;

    constructor(
        address initialOwner,
        IERC20 usdt_
    ) ERC20("Option Token", "OPT") Ownable(initialOwner) {
        usdt = usdt_;
    }

    function mint(address to) external payable onlyOwner {
        if (msg.value == 0) revert ZeroAmount();
        if (expired) revert AlreadyExpired();
        if (block.timestamp >= EXERCISE_DATE) revert MintClosed();

        _mint(to, msg.value);
    }

    function exercise(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (expired) revert AlreadyExpired();
        if (!_isExerciseDay(block.timestamp)) revert NotExerciseDay();

        uint256 usdtAmount = (amount * STRIKE_PRICE) / 1 ether;

        usdt.safeTransferFrom(msg.sender, owner(), usdtAmount);

        _burn(msg.sender, amount);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function expire() external onlyOwner {
        if (block.timestamp < EXERCISE_DATE + EXERCISE_WINDOW)
            revert NotExpired();
        if (expired) revert AlreadyExpired();

        expired = true;

        // 过期后剩余 OPT 自动失效，不再链上逐个遍历持有人并 burn。
        uint256 remainingETH = address(this).balance;
        if (remainingETH != 0) {
            (bool success, ) = payable(owner()).call{value: remainingETH}("");
            if (!success) revert TransferFailed();
        }
    }

    function _isExerciseDay(uint256 timestamp) internal pure returns (bool) {
        return
            timestamp >= EXERCISE_DATE &&
            timestamp < EXERCISE_DATE + EXERCISE_WINDOW;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (expired && from != address(0) && to != address(0) && value != 0) {
            revert TokenExpired();
        }

        super._update(from, to, value);
    }
}
