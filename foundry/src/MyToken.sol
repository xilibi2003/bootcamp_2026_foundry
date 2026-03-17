// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title MyToken
 * @dev 基于 OpenZeppelin ERC20 实现的固定供应量代币
 *      总发行量为 1000 个 Token（考虑 18 位小数，实际为 1000 * 10^18）
 *      所有代币在部署时一次性铸造给合约部署者
 */
contract MyToken is ERC20 {
    // 固定总供应量：1000 个 Token（含 18 位小数）
    uint256 public constant TOTAL_SUPPLY = 1000 * 10 ** 18;

    /**
     * @dev 构造函数：初始化代币名称、符号，并将全部 1000 个 Token 铸造给部署者
     * @param initialOwner 接收初始供应量的地址（即部署者）
     */
    constructor(address initialOwner) ERC20("MyToken", "MTK") {
        _mint(initialOwner, TOTAL_SUPPLY);
    }
}
