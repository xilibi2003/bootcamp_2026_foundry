// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SimpleMultiSigWallet} from "../src/SimpleMultiSigWallet.sol";

contract Receiver {
    uint256 public number;
    uint256 public totalReceived;

    event NumberChanged(uint256 newNumber, uint256 msgValue);

    function setNumber(uint256 newNumber) external payable {
        number = newNumber;
        totalReceived += msg.value;
        emit NumberChanged(newNumber, msg.value);
    }
}

contract SimpleMultiSigWalletTest is Test {
    SimpleMultiSigWallet public wallet;
    Receiver public receiver;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = charlie;

        wallet = new SimpleMultiSigWallet(owners, 2);
        receiver = new Receiver();

        vm.deal(address(wallet), 10 ether);
    }

    function test_ProposalByOwnerCreatesProposalAndAutoConfirms() public {
        bytes memory data = abi.encodeCall(Receiver.setNumber, (7));

        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 1 ether, data);

        (
            address to,
            uint256 value,
            bytes memory storedData,
            bool executed,
            uint256 confirmationCount
        ) = wallet.getProposal(proposalId);

        assertEq(proposalId, 0);
        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(storedData, data);
        assertFalse(executed);
        assertEq(confirmationCount, 1);
        assertTrue(wallet.isConfirmed(proposalId, alice));
    }

    function test_ProposalByNonOwnerReverts() public {
        vm.prank(david);
        vm.expectRevert("not owner");
        wallet.proposal(address(receiver), 0, "");
    }

    function test_ComfirmAddsConfirmation() public {
        bytes memory data = abi.encodeCall(Receiver.setNumber, (11));

        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 0, data);

        vm.prank(bob);
        wallet.comfirm(proposalId);

        (, , , , uint256 confirmationCount) = wallet.getProposal(proposalId);
        assertEq(confirmationCount, 2);
        assertTrue(wallet.isConfirmed(proposalId, bob));
    }

    function test_ComfirmTwiceReverts() public {
        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 0, "");

        vm.prank(alice);
        vm.expectRevert("already confirmed");
        wallet.comfirm(proposalId);
    }

    function test_ExecuteAfterThresholdAllowsAnyone() public {
        bytes memory data = abi.encodeCall(Receiver.setNumber, (99));

        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 1 ether, data);

        vm.prank(bob);
        wallet.comfirm(proposalId);

        vm.prank(david);
        wallet.execute(proposalId);

        (, , , bool executed, uint256 confirmationCount) = wallet.getProposal(
            proposalId
        );

        assertTrue(executed);
        assertEq(confirmationCount, 2);
        assertEq(receiver.number(), 99);
        assertEq(receiver.totalReceived(), 1 ether);
        assertEq(address(receiver).balance, 1 ether);
        assertEq(address(wallet).balance, 9 ether);
    }

    function test_ExecuteBeforeThresholdReverts() public {
        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 0, "");

        vm.expectRevert("confirmations not enough");
        wallet.execute(proposalId);
    }

    function test_ExecuteCannotRunTwice() public {
        bytes memory data = abi.encodeCall(Receiver.setNumber, (1));

        vm.prank(alice);
        uint256 proposalId = wallet.proposal(address(receiver), 0, data);

        vm.prank(charlie);
        wallet.confirm(proposalId);

        wallet.execute(proposalId);

        vm.expectRevert("proposal already executed");
        wallet.execute(proposalId);
    }
}
