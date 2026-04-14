// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBank.sol";

contract Bank is IBank {
    address public admin;

    mapping(address => uint256) public balances;

    // topUsers[0] 是第 1 名，topUsers[1] 是第 2 名，topUsers[2] 是第 3 名
    address[3] public topUsers;

    event Deposited(address indexed user, uint256 amount, uint256 userBalance);
    event Withdrawn(address indexed admin, address indexed to, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin");

        address previousAdmin = admin;
        admin = newAdmin;

        emit AdminTransferred(previousAdmin, newAdmin);
    }

    // 支持 Metamask 等钱包直接向合约地址转账
    receive() external payable virtual {
        _deposit(msg.sender, msg.value);
    }

    fallback() external payable virtual {
        _deposit(msg.sender, msg.value);
    }

    // 显式存款方法（可选）
    function deposit() external payable virtual {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address user, uint256 amount) internal virtual {
        require(amount > 0, "Amount must be > 0");

        balances[user] += amount;

        _updateTopUsers(user);
        

        emit Deposited(user, amount, balances[user]);
    }

    // 仅管理员可提取任意金额到指定地址
    function withdraw(uint256 amount, address payable to) external override onlyAdmin {
        require(to != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient contract balance");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, to, amount);
    }

    // 返回前 3 名地址和对应存款金额
    function getTop3() external view returns (address[3] memory users, uint256[3] memory amounts) {
        users = topUsers;
        for (uint256 i = 0; i < 3; i++) {
            amounts[i] = balances[users[i]];
        }
    }

    function _updateTopUsers(address user) internal {
        // 如果 user 已在榜单里，先移除后再按新余额插入
        for (uint256 i = 0; i < 3; i++) {
            if (topUsers[i] == user) {
                for (uint256 j = i; j < 2; j++) {
                    topUsers[j] = topUsers[j + 1];
                }
                topUsers[2] = address(0);
                break;
            }
        }

        uint256 userBalance = balances[user];

        // 插入排序到前 3（按余额降序）
        for (uint256 i = 0; i < 3; i++) {
            address current = topUsers[i];
            if (current == address(0) || userBalance > balances[current]) {
                for (uint256 j = 2; j > i; j--) {
                    topUsers[j] = topUsers[j - 1];
                }
                topUsers[i] = user;
                return;
            }
        }
    }
}
