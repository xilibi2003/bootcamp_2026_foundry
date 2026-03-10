// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

// ══════════════════════════════════════════════════════════
//  Handler：供 Invariant 测试使用的操作集合
//  模拟 10 个地址之间随意转账，fuzzer 会随机调用这里的函数
// ══════════════════════════════════════════════════════════
contract TransferHandler is Test {
    MyToken public token;

    // 10 个固定测试地址
    address[10] public actors;

    // 记录成功转账次数，便于调试
    uint256 public totalCalls;

    constructor(MyToken _token) {
        token = _token;

        // 初始化 10 个地址
        for (uint256 i = 0; i < 10; i++) {
            actors[i] = makeAddr(string(abi.encodePacked("actor", i)));
        }

        // actors[0] 作为初始持币者，持有全部 1000 MTK
        // 由测试合约在 setUp 里调用 token.transfer 完成
        // 这里仅记录 actors[0]，实际转账在测试合约 setUp 里完成
    }

    /// @dev Fuzzer 随机调用此函数模拟任意两地址间转账
    function transfer(
        uint256 fromSeed,
        uint256 toSeed,
        uint256 amount
    ) external {
        uint256 fromIdx = fromSeed % 10;
        uint256 toIdx = toSeed % 10;

        address from = actors[fromIdx];
        address to = actors[toIdx];

        uint256 balance = token.balanceOf(from);
        if (balance == 0) return; // 余额为 0 跳过，不 revert

        // 将 amount 约束在 [1, balance]
        amount = bound(amount, 1, balance);

        vm.prank(from);
        token.transfer(to, amount);

        totalCalls++;
    }
}

// ══════════════════════════════════════════════════════════
//  MyTokenTest：Fuzz 测试 + Invariant 测试
// ══════════════════════════════════════════════════════════
contract MyTokenTest is Test {
    MyToken public token;
    TransferHandler public handler;

    uint256 constant TOTAL = 1000 * 10 ** 18;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // 测试合约部署 token，owner 作为 initialOwner 拿到全部 1000 MTK
        token = new MyToken(owner);

        // 创建 Handler（内部生成 10 个 actor 地址）
        handler = new TransferHandler(token);

        // 先获取 actor0，避免它作为外部调用消耗掉 vm.prank
        address actor0 = handler.actors(0);

        // 将全部代币从 owner 转给 actors[0]，作为 Invariant 测试的起始资金
        vm.prank(owner);
        token.transfer(actor0, TOTAL);

        // 告诉 Foundry Invariant 测试只针对 handler 发起调用
        targetContract(address(handler));
    }

    // ════════════════════════════════════
    // 一、基础单元测试
    // ════════════════════════════════════

    /// @notice 部署后 totalSupply 等于 1000 MTK
    function test_InitialSupply() public {
        MyToken t = new MyToken(address(this));
        assertEq(t.totalSupply(), TOTAL);
        assertEq(t.balanceOf(address(this)), TOTAL);
    }

    // ════════════════════════════════════
    // 二、Fuzz 测试：transfer 正确性
    // ════════════════════════════════════

    /// @notice [Fuzz] 转账后 sender 减少，receiver 增加，两者之和不变
    function testFuzz_Transfer_BalancesUpdatedCorrectly(uint256 amount) public {
        // 给 alice 全部 token（setUp 中 owner 已经把 token 给了 handler，这里重新部署一个）
        MyToken t = new MyToken(alice);
        amount = bound(amount, 1, t.balanceOf(alice));

        uint256 aliceBefore = t.balanceOf(alice);
        uint256 bobBefore = t.balanceOf(bob);

        vm.prank(alice);
        t.transfer(bob, amount);

        assertEq(
            t.balanceOf(alice),
            aliceBefore - amount,
            "Alice balance should decrease"
        );
        assertEq(
            t.balanceOf(bob),
            bobBefore + amount,
            "Bob balance should increase"
        );
    }

    /// @notice [Fuzz] 转账后 totalSupply 不变
    function testFuzz_Transfer_TotalSupplyUnchanged(uint256 amount) public {
        MyToken t = new MyToken(alice);
        amount = bound(amount, 1, t.balanceOf(alice));

        vm.prank(alice);
        t.transfer(bob, amount);

        assertEq(
            t.totalSupply(),
            TOTAL,
            "Total supply must not change after transfer"
        );
    }

    /// @notice [Fuzz] 超出余额转账应 revert
    function testFuzz_Transfer_InsufficientBalanceReverts(
        uint256 amount
    ) public {
        // alice 余额为 0，任意正数都会 revert
        amount = bound(amount, 1, type(uint128).max);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, amount);
    }

    /// @notice [Fuzz] 转账到 address(0) 应 revert
    function testFuzz_Transfer_ToZeroAddressReverts(uint256 amount) public {
        MyToken t = new MyToken(alice);
        amount = bound(amount, 1, t.balanceOf(alice));

        vm.prank(alice);
        vm.expectRevert();
        t.transfer(address(0), amount);
    }

    /// @notice [Fuzz] approve + transferFrom 授权转账正确性
    function testFuzz_TransferFrom_BalancesCorrect(uint256 amount) public {
        MyToken t = new MyToken(alice);
        amount = bound(amount, 1, t.balanceOf(alice));

        // alice 授权 bob
        vm.prank(alice);
        t.approve(bob, amount);

        uint256 aliceBefore = t.balanceOf(alice);

        // bob 使用授权额度转给自己
        vm.prank(bob);
        t.transferFrom(alice, bob, amount);

        assertEq(
            t.balanceOf(alice),
            aliceBefore - amount,
            "Alice balance mismatch"
        );
        assertEq(t.balanceOf(bob), amount, "Bob balance mismatch");
        assertEq(t.allowance(alice, bob), 0, "Allowance should be consumed");
    }

    /// @notice [Fuzz] transferFrom 超出授权额度应 revert
    function testFuzz_TransferFrom_ExceedsAllowanceReverts(
        uint256 approveAmount,
        uint256 transferAmount
    ) public {
        MyToken t = new MyToken(alice);
        // 确保 approveAmount < transferAmount 且都合法
        approveAmount = bound(approveAmount, 0, TOTAL - 1);
        transferAmount = bound(transferAmount, approveAmount + 1, TOTAL);

        vm.prank(alice);
        t.approve(bob, approveAmount);

        vm.prank(bob);
        vm.expectRevert();
        t.transferFrom(alice, bob, transferAmount);
    }

    // ════════════════════════════════════
    // 三、Invariant 测试：总发行量永不变
    // ════════════════════════════════════

    /// @dev Invariant 1：不管 10 个地址间如何转账，totalSupply 始终等于 TOTAL
    function invariant_TotalSupplyAlwaysConstant() public view {
        assertEq(
            token.totalSupply(),
            TOTAL,
            "Invariant broken: totalSupply changed"
        );
    }

    /// @dev Invariant 2：10 个 actor 余额之和始终等于 totalSupply
    ///      （因为初始时全部代币在 actors[0]，转账只在 actors 间流转）
    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        uint256 sum = 0;
        for (uint256 i = 0; i < 10; i++) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(
            sum,
            TOTAL,
            "Invariant broken: sum of actor balances != totalSupply"
        );
    }

    /// @dev 打印 Invariant 测试统计信息（run 后可见）
    function invariant_PrintStats() public view {
        console.log("Total transfer calls:", handler.totalCalls());
    }
}
