// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    // 测试使用的钱包地址
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address dave = makeAddr("dave");
    address eve = makeAddr("eve");
    address admin;

    // 给每个测试地址预充 ETH
    function setUp() public {
        bank = new Bank();
        admin = address(this); // 部署者即 admin

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);
        vm.deal(eve, 100 ether);
    }

    // ─────────────────────────────────────────────
    // 1. 存款记录测试
    // ─────────────────────────────────────────────

    /// @notice 单个地址存款后余额应被正确记录
    function test_DepositRecordsSingleUser() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();

        assertEq(bank.balances(alice), 10 ether, "Alice balance mismatch");
    }

    /// @notice 同一地址多次存款应累加余额
    function test_DepositAccumulatesBalance() public {
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        vm.prank(alice);
        bank.deposit{value: 3 ether}();

        assertEq(
            bank.balances(alice),
            8 ether,
            "Alice accumulated balance mismatch"
        );
    }

    /// @notice 多个不同地址存款后余额各自独立
    function test_DepositRecordsMultipleUsers() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();
        vm.prank(bob);
        bank.deposit{value: 20 ether}();
        vm.prank(charlie);
        bank.deposit{value: 15 ether}();

        assertEq(bank.balances(alice), 10 ether, "Alice balance mismatch");
        assertEq(bank.balances(bob), 20 ether, "Bob balance mismatch");
        assertEq(bank.balances(charlie), 15 ether, "Charlie balance mismatch");
    }

    /// @notice 通过 receive() 直接转账也应正确记录
    function test_DepositViaReceive() public {
        vm.prank(alice);
        (bool ok, ) = address(bank).call{value: 7 ether}("");
        assertTrue(ok);
        assertEq(
            bank.balances(alice),
            7 ether,
            "Alice receive balance mismatch"
        );
    }

    /// @notice 存款金额为 0 应该 revert
    function test_DepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be > 0");
        bank.deposit{value: 0}();
    }

    /// @notice 存款应该触发 Deposited 事件
    function test_DepositEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Bank.Deposited(alice, 5 ether, 5 ether);
        bank.deposit{value: 5 ether}();
    }

    // ─────────────────────────────────────────────
    // 2. 前三名排序测试
    // ─────────────────────────────────────────────

    /// @notice 只有一个用户时，top1 应为该用户
    function test_Top3_SingleUser() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();

        (address[3] memory users, uint256[3] memory amounts) = bank.getTop3();
        assertEq(users[0], alice, "Top1 should be alice");
        assertEq(amounts[0], 10 ether, "Top1 amount mismatch");
        assertEq(users[1], address(0), "Top2 should be empty");
        assertEq(users[2], address(0), "Top3 should be empty");
    }

    /// @notice 三个用户各自存款后，前三名应按余额降序排列
    function test_Top3_ThreeUsers_Ordering() public {
        // Bob 存最多，Charlie 其次，Alice 最少
        vm.prank(alice);
        bank.deposit{value: 10 ether}();
        vm.prank(bob);
        bank.deposit{value: 30 ether}();
        vm.prank(charlie);
        bank.deposit{value: 20 ether}();

        (address[3] memory users, uint256[3] memory amounts) = bank.getTop3();

        assertEq(users[0], bob, "Top1 should be bob");
        assertEq(users[1], charlie, "Top2 should be charlie");
        assertEq(users[2], alice, "Top3 should be alice");

        assertEq(amounts[0], 30 ether, "Top1 amount mismatch");
        assertEq(amounts[1], 20 ether, "Top2 amount mismatch");
        assertEq(amounts[2], 10 ether, "Top3 amount mismatch");
    }

    /// @notice 超过三个用户时，榜单只保留存款最多的前三名
    function test_Top3_FiveUsers_OnlyTopThreeRetained() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}(); // 第4
        vm.prank(bob);
        bank.deposit{value: 50 ether}(); // 第1
        vm.prank(charlie);
        bank.deposit{value: 30 ether}(); // 第2
        vm.prank(dave);
        bank.deposit{value: 5 ether}(); // 第5
        vm.prank(eve);
        bank.deposit{value: 20 ether}(); // 第3

        (address[3] memory users, uint256[3] memory amounts) = bank.getTop3();

        assertEq(users[0], bob, "Top1 should be bob (50 ETH)");
        assertEq(users[1], charlie, "Top2 should be charlie (30 ETH)");
        assertEq(users[2], eve, "Top3 should be eve (20 ETH)");

        assertEq(amounts[0], 50 ether);
        assertEq(amounts[1], 30 ether);
        assertEq(amounts[2], 20 ether);
    }

    /// @notice 已在榜单的用户追加存款后，排名应动态更新
    function test_Top3_UpdatesWhenExistingUserDepositsMore() public {
        vm.prank(alice);
        bank.deposit{value: 30 ether}(); // 初始第1
        vm.prank(bob);
        bank.deposit{value: 20 ether}(); // 初始第2
        vm.prank(charlie);
        bank.deposit{value: 10 ether}(); // 初始第3

        // Charlie 追加大额存款，应该晋升为第1
        vm.prank(charlie);
        bank.deposit{value: 40 ether}(); // charlie 总计 50 ETH

        (address[3] memory users, ) = bank.getTop3();

        assertEq(users[0], charlie, "Top1 should now be charlie");
        assertEq(users[1], alice, "Top2 should be alice");
        assertEq(users[2], bob, "Top3 should be bob");
    }

    /// @notice 榜外用户存款超过第三名后，应挤入前三
    function test_Top3_NewUserEntersTop3() public {
        vm.prank(alice);
        bank.deposit{value: 30 ether}();
        vm.prank(bob);
        bank.deposit{value: 20 ether}();
        vm.prank(charlie);
        bank.deposit{value: 10 ether}();

        // Dave 存 25 ETH，应挤掉 Charlie 进入第2名
        vm.prank(dave);
        bank.deposit{value: 25 ether}();

        (address[3] memory users, uint256[3] memory amounts) = bank.getTop3();

        assertEq(users[0], alice, "Top1 should be alice");
        assertEq(users[1], dave, "Top2 should be dave");
        assertEq(users[2], bob, "Top3 should be bob");

        assertEq(amounts[0], 30 ether);
        assertEq(amounts[1], 25 ether);
        assertEq(amounts[2], 20 ether);
    }

    /// @notice 所有用户存款额相同时，先存款的用户排名靠前
    function test_Top3_TiedAmounts_FirstDepositWins() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();
        vm.prank(bob);
        bank.deposit{value: 10 ether}();
        vm.prank(charlie);
        bank.deposit{value: 10 ether}();
        vm.prank(dave);
        bank.deposit{value: 10 ether}(); // 同额，不能挤进榜单

        (address[3] memory users, ) = bank.getTop3();

        // alice、bob、charlie 先存，应占据前三
        assertEq(users[0], alice);
        assertEq(users[1], bob);
        assertEq(users[2], charlie);
    }

    // ─────────────────────────────────────────────
    // 3. 管理员提款测试
    // ─────────────────────────────────────────────

    /// @notice 管理员可以成功提款到指定地址
    function test_Withdraw_AdminCanWithdraw() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();

        // 提款给 bob（EOA，能正常接收 ETH）
        uint256 balBefore = bob.balance;
        bank.withdraw(5 ether, payable(bob));
        assertEq(bob.balance, balBefore + 5 ether, "Bob should receive 5 ETH");
        assertEq(address(bank).balance, 5 ether, "Bank should have 5 ETH left");
    }

    /// @notice 非管理员调用 withdraw 应 revert
    function test_Withdraw_NonAdminReverts() public {
        vm.prank(alice);
        bank.deposit{value: 10 ether}();

        vm.prank(bob);
        vm.expectRevert("Only admin");
        bank.withdraw(1 ether, payable(bob));
    }
}
