// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenBankTest is Test {
    TokenBank public bank;
    IERC20 public usdt;

    // 以太坊主网 USDT 合约地址
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address alice = makeAddr("alice");

    function setUp() public {
        // 绑定主网 USDT
        usdt = IERC20(USDT_ADDRESS);

        // 部署 TokenBank，目标代币为 USDT
        bank = new TokenBank(USDT_ADDRESS);

        // 使用 deal 直接给 alice 铸造 USDT 用于测试（USDT 精度为 6）
        deal(USDT_ADDRESS, alice, 10000 * 1e6);
    }

    /// @notice 测试使用主网 USDT 进行 deposit 和 withdraw
    function test_DepositAndWithdrawUSDT() public {
        uint256 depositAmount = 1000 * 1e6; // 存入 1000 USDT

        // 验证 alice 的初始 USDT 余额
        assertEq(
            usdt.balanceOf(alice),
            10000 * 1e6,
            "Alice initial balance incorrect"
        );

        // alice 开始操作
        vm.startPrank(alice);

        // 1. 授权 TokenBank 操作 USDT
        // 因为主网 USDT 的 approve 没有返回 bool，直接调 IERC20.approve 会引发 revert。
        // 所以我们在测试里也要借用 SafeERC20 的 forceApprove
        SafeERC20.forceApprove(usdt, address(bank), depositAmount);

        // 2. 调用存款
        bank.deposit(depositAmount);

        // 3. 验证存款后的状态
        assertEq(
            usdt.balanceOf(alice),
            9000 * 1e6,
            "Alice balance after deposit mismatch"
        );
        assertEq(
            usdt.balanceOf(address(bank)),
            depositAmount,
            "Bank USDT balance mismatch"
        );
        assertEq(
            bank.balances(alice),
            depositAmount,
            "Bank logic balance mismatch"
        );

        // 4. 调用提款
        // 提取 400 USDT
        uint256 withdrawAmount = 400 * 1e6;
        bank.withdraw(withdrawAmount);

        // 5. 验证提款后的状态
        assertEq(
            usdt.balanceOf(alice),
            9400 * 1e6,
            "Alice balance after withdraw mismatch"
        );
        assertEq(
            usdt.balanceOf(address(bank)),
            600 * 1e6,
            "Bank USDT balance after withdraw mismatch"
        );
        assertEq(
            bank.balances(alice),
            600 * 1e6,
            "Bank logic balance after withdraw mismatch"
        );

        vm.stopPrank();
    }
}
