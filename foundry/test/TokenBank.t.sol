// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract TokenBankTest is Test {
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant
        PERMIT2_PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );
    address internal constant PERMIT2_ADDRESS =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant MY_PERMIT_TOKEN_ADDRESS =
        0x5FbDB2315678afecb367f032d93F642f64180aa3;

    TokenBank public bank;
    IERC20 public usdt;

    address alice = makeAddr("alice");

    function _getPermit2TransferDigest(
        address tokenAddress,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        address spender
    ) internal view returns (bytes32) {
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, tokenAddress, amount)
        );
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT2_PERMIT_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                spender,
                nonce,
                deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("Permit2"),
                block.chainid,
                PERMIT2_ADDRESS
            )
        );

        return keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
    }

    function setUp() public {
        // 绑定本地已部署的 MyPermitToken
        usdt = IERC20(MY_PERMIT_TOKEN_ADDRESS);

        // 部署 TokenBank，目标代币为 MyPermitToken
        bank = new TokenBank(MY_PERMIT_TOKEN_ADDRESS);

        // 使用 deal 直接给 alice 分配 MyPermitToken 用于测试（18 位精度）
        deal(MY_PERMIT_TOKEN_ADDRESS, alice, 10000 * 1e18);
    }

    /// @notice 测试使用已部署的 MyPermitToken 进行 deposit 和 withdraw
    function test_DepositAndWithdrawUSDT() public {
        uint256 depositAmount = 1000 * 1e18; // 存入 1000 MPT

        // 验证 alice 的初始 Token 余额
        assertEq(
            usdt.balanceOf(alice),
            10000 * 1e18,
            "Alice initial balance incorrect"
        );

        // alice 开始操作
        vm.startPrank(alice);

        // 1. 授权 TokenBank 操作 MyPermitToken
        SafeERC20.forceApprove(usdt, address(bank), depositAmount);

        // 2. 调用存款
        bank.deposit(depositAmount);

        // 3. 验证存款后的状态
        assertEq(
            usdt.balanceOf(alice),
            9000 * 1e18,
            "Alice balance after deposit mismatch"
        );
        assertEq(
            usdt.balanceOf(address(bank)),
            depositAmount,
            "Bank token balance mismatch"
        );
        assertEq(
            bank.balances(alice),
            depositAmount,
            "Bank logic balance mismatch"
        );

        // 4. 调用提款
        // 提取 400 MPT
        uint256 withdrawAmount = 400 * 1e18;
        bank.withdraw(withdrawAmount);

        // 5. 验证提款后的状态
        assertEq(
            usdt.balanceOf(alice),
            9400 * 1e18,
            "Alice balance after withdraw mismatch"
        );
        assertEq(
            usdt.balanceOf(address(bank)),
            600 * 1e18,
            "Bank token balance after withdraw mismatch"
        );
        assertEq(
            bank.balances(alice),
            600 * 1e18,
            "Bank logic balance after withdraw mismatch"
        );

        vm.stopPrank();
    }

    function test_PermitDepositWithMyPermitToken() public {
        uint256 alicePrivateKey = 0xA11CE;
        address permitAlice = vm.addr(alicePrivateKey);
        uint256 depositAmount = 250 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 days;

        MyPermitToken permitToken = new MyPermitToken(permitAlice);
        TokenBank permitBank = new TokenBank(address(permitToken));

        uint256 nonce = permitToken.nonces(permitAlice);
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                permitAlice,
                address(permitBank),
                depositAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permitToken.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.prank(permitAlice);
        permitBank.permitDeposit(depositAmount, deadline, v, r, s);

        assertEq(
            permitToken.balanceOf(permitAlice),
            permitToken.totalSupply() - depositAmount,
            "Alice balance after permitDeposit mismatch"
        );
        assertEq(
            permitToken.balanceOf(address(permitBank)),
            depositAmount,
            "Bank token balance mismatch"
        );
        assertEq(
            permitBank.balances(permitAlice),
            depositAmount,
            "Bank logic balance mismatch"
        );
        assertEq(
            permitToken.allowance(permitAlice, address(permitBank)),
            0,
            "Allowance should be consumed after deposit"
        );
        assertEq(
            permitToken.nonces(permitAlice),
            nonce + 1,
            "Permit nonce should increment"
        );
    }

    function test_DepositWithPermit2() public {
        vm.createSelectFork(vm.rpcUrl("local"));
        assertTrue(
            PERMIT2_ADDRESS.code.length > 0,
            "Permit2 contract not deployed on local Anvil"
        );

        uint256 alicePrivateKey = 0xB0B;
        address permitAlice = vm.addr(alicePrivateKey);
        uint256 depositAmount = 150 * 10 ** 18;
        uint256 nonce = 7;
        uint256 deadline = block.timestamp + 1 days;

        MyPermitToken permitToken = new MyPermitToken(permitAlice);
        TokenBank permitBank = new TokenBank(address(permitToken));

        vm.prank(permitAlice);
        permitToken.approve(PERMIT2_ADDRESS, depositAmount);

        bytes32 digest = _getPermit2TransferDigest(
            address(permitToken),
            depositAmount,
            nonce,
            deadline,
            address(permitBank)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(permitAlice);
        permitBank.depositWithPermit2(
            PERMIT2_ADDRESS,
            depositAmount,
            nonce,
            deadline,
            signature
        );

        assertEq(
            permitToken.balanceOf(permitAlice),
            permitToken.totalSupply() - depositAmount,
            "Alice balance after depositWithPermit2 mismatch"
        );
        assertEq(
            permitToken.balanceOf(address(permitBank)),
            depositAmount,
            "Bank token balance mismatch"
        );
        assertEq(
            permitBank.balances(permitAlice),
            depositAmount,
            "Bank logic balance mismatch"
        );
    }
}
