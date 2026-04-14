// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    Governor
} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {
    GovernorCountingSimple
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {
    GovernorVotes
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {
    IVotes
} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

contract Gov is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    uint48 private constant VOTING_DELAY = 1;
    uint32 private constant VOTING_PERIOD = 10;
    uint256 private constant PROPOSAL_THRESHOLD = 1000 ether;

    constructor(
        IVotes token
    )
        Governor("CK Governor")
        GovernorVotes(token)
        GovernorVotesQuorumFraction(4)
    {}

    function votingDelay() public pure override returns (uint256) {
        return VOTING_DELAY;
    }

    function votingPeriod() public pure override returns (uint256) {
        return VOTING_PERIOD;
    }

    function proposalThreshold() public pure override returns (uint256) {
        return PROPOSAL_THRESHOLD;
    }
}
