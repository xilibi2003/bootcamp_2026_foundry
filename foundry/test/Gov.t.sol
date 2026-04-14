// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CKToken} from "../src/CKToken.sol";
import {Gov} from "../src/Gov.sol";
import {Bank} from "../src/Bank.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";

contract GovTest is Test {
    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant TRANSFER_AMOUNT = 100_000 ether;
    uint256 internal constant WITHDRAW_AMOUNT = 3 ether;

    CKToken internal token;
    Gov internal gov;
    Bank internal bank;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        token = new CKToken(address(this), INITIAL_SUPPLY);
        gov = new Gov(token);
        bank = new Bank();

        token.transfer(alice, 400_000 ether);
        token.transfer(bob, 300_000 ether);

        token.delegate(address(this));

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(bob);
        token.delegate(bob);

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        bank.transferAdmin(address(gov));
    }

    function test_CKTokenTransferUpdatesCheckpoints() public {
        vm.roll(block.number + 1);
        uint256 snapshotBlock = block.number - 1;

        assertEq(token.getVotes(address(this)), 300_000 ether);
        assertEq(token.getVotes(alice), 400_000 ether);
        assertEq(token.getPastVotes(address(this), snapshotBlock), 300_000 ether);
        assertEq(token.getPastVotes(alice, snapshotBlock), 400_000 ether);

        token.transfer(alice, TRANSFER_AMOUNT);

        assertEq(token.getVotes(address(this)), 200_000 ether);
        assertEq(token.getVotes(alice), 500_000 ether);

        vm.roll(block.number + 1);
        uint256 afterTransferBlock = block.number - 1;
        assertEq(token.getPastVotes(address(this), afterTransferBlock), 200_000 ether);
        assertEq(token.getPastVotes(alice, afterTransferBlock), 500_000 ether);
        assertEq(token.getPastVotes(address(this), snapshotBlock), 300_000 ether);
        assertEq(token.getPastVotes(alice, snapshotBlock), 400_000 ether);
    }

    function test_GovernanceCanWithdrawFromBank() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Withdraw funds to treasury";

        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(Bank.withdraw, (WITHDRAW_AMOUNT, payable(treasury)));

        uint256 proposalId = gov.propose(targets, values, calldatas, description);

        vm.roll(block.number + gov.votingDelay() + 1);

        vm.prank(alice);
        gov.castVote(proposalId, 1);

        vm.prank(bob);
        gov.castVote(proposalId, 1);

        gov.castVote(proposalId, 1);

        vm.roll(block.number + gov.votingPeriod() + 1);

        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 bankBalanceBefore = address(bank).balance;

        gov.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(treasury.balance, treasuryBalanceBefore + WITHDRAW_AMOUNT);
        assertEq(address(bank).balance, bankBalanceBefore - WITHDRAW_AMOUNT);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }
}
