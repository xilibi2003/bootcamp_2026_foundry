// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error NothingToRelease();

    event ERC20Released(address indexed token, uint256 amount);

    uint256 public constant CLIFF_DURATION = 12 * 30 days;
    uint256 public constant RELEASE_INTERVAL = 30 days;
    uint256 public constant TOTAL_RELEASE_MONTHS = 24;

    address public immutable beneficiary;
    IERC20 public immutable token;
    uint256 public immutable startTimestamp;
    uint256 public released;

    constructor(address beneficiary_, address token_) {
        if (beneficiary_ == address(0) || token_ == address(0)) {
            revert ZeroAddress();
        }

        beneficiary = beneficiary_;
        token = IERC20(token_);
        startTimestamp = block.timestamp;
    }

    function cliffEndTimestamp() public view returns (uint256) {
        return startTimestamp + CLIFF_DURATION;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 totalAllocation = token.balanceOf(address(this)) + released;

        if (timestamp < cliffEndTimestamp()) {
            return 0;
        }

        uint256 elapsedSinceCliff = timestamp - cliffEndTimestamp();
        uint256 unlockedMonths = (elapsedSinceCliff / RELEASE_INTERVAL) + 1;

        if (unlockedMonths >= TOTAL_RELEASE_MONTHS) {
            return totalAllocation;
        }

        return (totalAllocation * unlockedMonths) / TOTAL_RELEASE_MONTHS;
    }

    function release() external {
        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();

        released += amount;
        token.safeTransfer(beneficiary, amount);

        emit ERC20Released(address(token), amount);
    }
}
