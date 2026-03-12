// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1363Receiver
 * @dev Interface for any contract that wants to support `transferAndCall` or `transferFromAndCall`
 *      from ERC1363 token contracts.
 *
 *      实现此接口的合约可以在收到 ERC1363 Token 时收到回调通知。
 *      类似 ERC721 的 `onERC721Received`。
 */
interface IERC1363Receiver {
    /**
     * @notice Handle the receipt of ERC1363 tokens.
     * @dev 当通过 `transferAndCall` 或 `transferFromAndCall` 收到 Token 时，此函数会被调用。
     *      若要接受 Token，必须返回此函数的 selector（即 `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`）。
     *      若返回其他值或抛出异常，Token 转账将会回滚。
     *
     * @param operator  调用 `transferAndCall` 或 `transferFromAndCall` 的地址
     * @param from      Token 原始持有者地址（发送方）
     * @param amount    转移的 Token 数量
     * @param data      附带的额外调用数据（可为空）
     * @return bytes4   必须返回 `IERC1363Receiver.onTransferReceived.selector`
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4);
}
