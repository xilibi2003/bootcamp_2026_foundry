// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleMultiSigWallet {
    struct Proposal {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    address[] public owners;
    uint256 public immutable threshold;
    uint256 public proposalCount;

    mapping(address => bool) public isOwner;
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event Deposit(address indexed sender, uint256 amount);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "proposal not exists");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) payable {
        uint256 length = _owners.length;
        require(length > 0, "owners required");
        require(_threshold > 0 && _threshold <= length, "invalid threshold");

        for (uint256 i = 0; i < length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function proposal(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 proposalId) {
        require(to != address(0), "invalid target");

        proposalId = proposalCount;
        proposalCount++;

        Proposal storage item = proposals[proposalId];
        item.to = to;
        item.value = value;
        item.data = data;
        item.confirmationCount = 1;

        isConfirmed[proposalId][msg.sender] = true;

        emit ProposalCreated(proposalId, msg.sender, to, value, data);
        emit ProposalConfirmed(proposalId, msg.sender);
    }

    function comfirm(uint256 proposalId) external {
        _confirm(proposalId);
    }

    function confirm(uint256 proposalId) external {
        _confirm(proposalId);
    }

    function execute(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage item = proposals[proposalId];
        require(!item.executed, "proposal already executed");
        require(
            item.confirmationCount >= threshold,
            "confirmations not enough"
        );

        item.executed = true;

        (bool success, ) = item.to.call{value: item.value}(item.data);
        require(success, "execution failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }

    function getProposal(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationCount
        )
    {
        Proposal storage item = proposals[proposalId];
        return (
            item.to,
            item.value,
            item.data,
            item.executed,
            item.confirmationCount
        );
    }

    function _confirm(uint256 proposalId)
        internal
        onlyOwner
        proposalExists(proposalId)
    {
        Proposal storage item = proposals[proposalId];
        require(!item.executed, "proposal already executed");
        require(!isConfirmed[proposalId][msg.sender], "already confirmed");

        isConfirmed[proposalId][msg.sender] = true;
        item.confirmationCount++;

        emit ProposalConfirmed(proposalId, msg.sender);
    }
}
