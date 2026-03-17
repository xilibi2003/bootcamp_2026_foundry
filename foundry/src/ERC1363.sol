// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IERC1363Receiver.sol";

/**
 * @title ERC1363Token
 * @dev 基于 ERC1363 标准实现的具备回调功能的 ERC20 Token。
 *
 *      ERC1363 在 ERC20 基础上新增了两个核心函数：
 *      1. `transferAndCall`    - 转账并触发接收方合约的 `onTransferReceived` 回调
 *      2. `transferFromAndCall`- transferFrom 并触发接收方合约的 `onTransferReceived` 回调
 *
 *      核心优势：让用户只需一笔交易就能完成"转账+通知"，
 *      极大简化了 DeFi 协议的交互流程（原 ERC20 需要两笔交易）。
 *
 *      参考标准：https://eips.ethereum.org/EIPS/eip-1363
 */
contract ERC1363Token is ERC20 {
    // ──────────────────────────────────────────────────────────────────────────
    // 回调函数选择器常量（避免重复计算，节省 Gas）
    // ──────────────────────────────────────────────────────────────────────────

    /// @dev IERC1363Receiver.onTransferReceived 的 bytes4 选择器
    bytes4 private constant ON_TRANSFER_RECEIVED =
        bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"));

    // ──────────────────────────────────────────────────────────────────────────
    // 事件
    // ──────────────────────────────────────────────────────────────────────────

    /// @dev 当 transferAndCall 或 transferFromAndCall 成功完成回调时触发
    event TransferWithCallback(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 构造函数
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @param name_     Token 名称，例如 "MyERC1363Token"
     * @param symbol_   Token 符号，例如 "M63"
     * @param supply    初始铸造数量（单位：个，内部自动乘以 10^18）
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply
    ) ERC20(name_, symbol_) {
        // 将初始供应量铸造给部署者
        _mint(msg.sender, supply * 10 ** decimals());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // ERC1363 核心函数 —— transferAndCall
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @notice 转账 Token 并触发接收方合约的 `onTransferReceived` 回调（不附带额外数据）
     * @param to        接收 Token 的合约地址（必须实现 IERC1363Receiver）
     * @param amount    转账数量
     * @return bool     始终返回 true，失败时 revert
     */
    function transferAndCall(
        address to,
        uint256 amount
    ) external returns (bool) {
        return transferAndCall(to, amount, "");
    }

    /**
     * @notice 转账 Token 并触发接收方合约的 `onTransferReceived` 回调（附带额外数据）
     * @dev 流程：
     *      1. 调用标准 ERC20 transfer 完成转账
     *      2. 检查 `to` 是否为合约地址
     *      3. 调用 `to.onTransferReceived(operator, from, amount, data)`
     *      4. 验证返回值必须为正确的 selector，否则 revert
     *
     * @param to        接收 Token 的合约地址（必须实现 IERC1363Receiver）
     * @param amount    转账数量
     * @param data      附带的额外数据（会透传给 `onTransferReceived`）
     * @return bool     始终返回 true，失败时 revert
     */
    function transferAndCall(
        address to,
        uint256 amount,
        bytes memory data
    ) public returns (bool) {
        // 步骤 1：执行标准 ERC20 转账
        transfer(to, amount);

        // 步骤 2 & 3：验证接收方并触发回调
        _checkAndCallTransferReceived(msg.sender, msg.sender, to, amount, data);

        emit TransferWithCallback(msg.sender, msg.sender, to, amount, data);
        return true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // ERC1363 核心函数 —— transferFromAndCall
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @notice 代理转账 Token 并触发接收方合约的 `onTransferReceived` 回调（不附带额外数据）
     * @param from      Token 来源地址（必须提前 approve 给 msg.sender）
     * @param to        接收 Token 的合约地址
     * @param amount    转账数量
     * @return bool     始终返回 true，失败时 revert
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        return transferFromAndCall(from, to, amount, "");
    }

    /**
     * @notice 代理转账 Token 并触发接收方合约的 `onTransferReceived` 回调（附带额外数据）
     * @param from      Token 来源地址（必须提前 approve 给 msg.sender）
     * @param to        接收 Token 的合约地址（必须实现 IERC1363Receiver）
     * @param amount    转账数量
     * @param data      附带的额外数据（会透传给 `onTransferReceived`）
     * @return bool     始终返回 true，失败时 revert
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public returns (bool) {
        // 步骤 1：执行标准 ERC20 transferFrom（会验证 allowance）
        transferFrom(from, to, amount);

        // 步骤 2 & 3：验证接收方并触发回调
        // operator 为 msg.sender（即执行 transferFrom 的代理地址）
        _checkAndCallTransferReceived(msg.sender, from, to, amount, data);

        emit TransferWithCallback(msg.sender, from, to, amount, data);
        return true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 内部辅助函数
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @dev 内部函数：检查 `to` 是否为合约，并调用其 `onTransferReceived`，验证返回值。
     * @param operator  触发本次操作的地址（msg.sender）
     * @param from      Token 原持有者
     * @param to        Token 接收方（目标合约）
     * @param amount    转账数量
     * @param data      透传数据
     */
    function _checkAndCallTransferReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        // 只有合约地址才需要回调；EOA 不实现任何接口
        require(_isContract(to), "ERC1363: transfer to non-contract address");

        // 调用接收方的回调函数
        bytes4 retval = IERC1363Receiver(to).onTransferReceived(
            operator,
            from,
            amount,
            data
        );

        // 验证返回值，防止普通合约误接收 Token
        require(
            retval == ON_TRANSFER_RECEIVED,
            "ERC1363: receiver returned wrong selector"
        );
    }

    /**
     * @dev 辅助函数：判断地址是否为合约（通过检查 extcodesize）
     * @param account 待检查的地址
     * @return bool   true 表示是合约地址
     */
    function _isContract(address account) private view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
