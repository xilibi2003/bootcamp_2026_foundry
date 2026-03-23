// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenBank {
    using SafeERC20 for IERC20;

    IERC20 public token;
    
    // 记录每个地址存入的 token 数量
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    /**
     * @dev 存入 Token 到 TokenBank。
     * 存入前，用户需要先在 MyToken 合约中调用 `approve(TokenBankAddress, amount)`，
     * 授权 TokenBank 合约可以转移对应数量的 token。
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount must be > 0");
        
        // 调用 safeTransferFrom 将用户的 token 转移到本合约
        token.safeTransferFrom(msg.sender, address(this), amount);

        // 更新用户在 TokenBank 的余额记录
        balances[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @dev 通过 EIP-2612 permit 完成离线签名授权后直接存款。
     * 用户无需提前单独调用 approve，只需提交签名参数即可完成授权和存款。
     */
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(amount > 0, "Deposit amount must be > 0");

        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @dev 提取自己之前存入的 token。
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance in TokenBank");

        // 扣除用户的余额
        balances[msg.sender] -= amount;

        // 调用 safeTransfer 将 token 转回给用户
        token.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}
