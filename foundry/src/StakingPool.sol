// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ReentrancyGuard
} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IToken} from "./interfaces/IToken.sol";
import {IStaking} from "./interfaces/IStaking.sol";

contract StakingPool is IStaking, ReentrancyGuard {
    error ZeroAmount();
    error InsufficientStake();
    error TransferFailed();
    error ZeroAddress();

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    uint256 public constant REWARD_PER_BLOCK = 10 ether;
    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    IToken public immutable token;
    uint256 public totalStaked;
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;

    mapping(address account => UserInfo) public users;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 amount);

    constructor(IToken token_) {
        if (address(token_) == address(0)) revert ZeroAddress();

        token = token_;
        lastRewardBlock = block.number;
    }

    function stake() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        UserInfo storage user = users[msg.sender];

        _updatePool();
        _accrueRewards(user);
        _claimRewardsIfAny(user, msg.sender);

        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt =
            (user.amount * accRewardPerShare) /
            ACC_REWARD_PRECISION;

        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage user = users[msg.sender];
        if (user.amount < amount) revert InsufficientStake();

        _updatePool();
        _accrueRewards(user);
        _claimRewardsIfAny(user, msg.sender);

        user.amount -= amount;
        totalStaked -= amount; // address(this).balance;
        user.rewardDebt =
            (user.amount * accRewardPerShare) /
            ACC_REWARD_PRECISION;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Unstaked(msg.sender, amount);
    }

    function claim() external nonReentrant {
        UserInfo storage user = users[msg.sender];

        _updatePool();
        _accrueRewards(user);
        _claimRewards(user, msg.sender);
        user.rewardDebt =
            (user.amount * accRewardPerShare) /
            ACC_REWARD_PRECISION;
    }

    function balanceOf(address account) external view returns (uint256) {
        return users[account].amount;
    }

    function earned(address account) external view returns (uint256) {
        UserInfo memory user = users[account];
        uint256 currentAccRewardPerShare = accRewardPerShare;

        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = blocks * REWARD_PER_BLOCK;
            currentAccRewardPerShare +=
                (reward * ACC_REWARD_PRECISION) /
                totalStaked;
        }

        uint256 accumulatedReward = (user.amount * currentAccRewardPerShare) /
            ACC_REWARD_PRECISION;

        return user.pendingRewards + accumulatedReward - user.rewardDebt;
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * REWARD_PER_BLOCK;

        accRewardPerShare += (reward * ACC_REWARD_PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }

    function _accrueRewards(UserInfo storage user) internal {
        if (user.amount == 0) {
            return;
        }

        uint256 accumulatedReward = (user.amount * accRewardPerShare) /
            ACC_REWARD_PRECISION;
        uint256 pending = accumulatedReward - user.rewardDebt;

        if (pending != 0) {
            user.pendingRewards += pending;
        }
    }

    function _claimRewardsIfAny(UserInfo storage user, address account) internal {
        if (user.pendingRewards == 0) {
            return;
        }

        _claimRewards(user, account);
    }

    function _claimRewards(UserInfo storage user, address account) internal {
        uint256 reward = user.pendingRewards;
        if (reward == 0) revert ZeroAmount();

        user.pendingRewards = 0;
        token.mint(account, reward);

        emit Claimed(account, reward);
    }
}
