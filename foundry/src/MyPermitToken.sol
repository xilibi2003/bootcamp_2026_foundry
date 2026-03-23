// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Permit
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MyPermitToken
 * @dev 基于 OpenZeppelin ERC20Permit 实现的 EIP-2612 代币
 *      总发行量为 1000 个 Token（考虑 18 位小数，实际为 1000 * 10^18）
 *      所有代币在部署时一次性铸造给指定地址
 */
contract MyPermitToken is ERC20, ERC20Permit {
    // 固定总供应量：1000 个 Token（含 18 位小数）
    uint256 public constant TOTAL_SUPPLY = 1000 * 10 ** 18;

    /**
     * @dev 构造函数：初始化代币名称、符号，并将全部代币铸造给初始持有人
     * @param initialOwner 接收初始供应量的地址
     */
    constructor(address initialOwner)
        ERC20("MyPermitToken", "MPT")
        ERC20Permit("MyPermitToken")
    {
        _mint(initialOwner, TOTAL_SUPPLY);
    }
}
