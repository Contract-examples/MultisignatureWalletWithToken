// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultisignatureWallet {
    using SafeERC20 for IERC20;

    // multisignature wallet signers
    address[] public signers;
    // required approvals
    uint256 public immutable requiredApprovals;
    // token
    IERC20 public immutable token;
    // balance
    uint256 public balance;

    // proposal struct
    struct Proposal {
        address to;
        uint256 amount;
        uint256 approvals;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    // proposals mapping
    mapping(uint256 => Proposal) public proposals;
    // proposal count
    uint256 public proposalCount;

    error Unauthorized();
    error InvalidParameters();
    error ProposalAlreadyExecuted();
    error InsufficientApprovals();
    error InsufficientBalance();

    event Deposit(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address to, uint256 amount);
    event ProposalApproved(uint256 indexed proposalId, address signer);
    event ProposalExecuted(uint256 indexed proposalId, address to, uint256 amount);

    constructor(address _token, address[] memory _signers, uint256 _requiredApprovals) {
        if (_signers.length == 0 || _requiredApprovals == 0 || _requiredApprovals > _signers.length) {
            revert InvalidParameters();
        }

        token = IERC20(_token);
        signers = _signers;
        requiredApprovals = _requiredApprovals;
    }

    modifier onlySigner() {
        if (!isSigner(msg.sender)) revert Unauthorized();
        _;
    }

    function isSigner(address account) public view returns (bool) {
        for (uint256 i = 0; i < signers.length; i++) {
            if (account == signers[i]) return true;
        }
        return false;
    }

    function createProposal(address to, uint256 amount) external onlySigner {
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.to = to;
        proposal.amount = amount;

        emit ProposalCreated(proposalId, to, amount);
    }

    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.hasApproved[msg.sender]) return;

        proposal.approvals++;
        proposal.hasApproved[msg.sender] = true;

        emit ProposalApproved(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.approvals < requiredApprovals) revert InsufficientApprovals();
        if (proposal.amount > balance) revert InsufficientBalance();

        proposal.executed = true;
        balance -= proposal.amount;
        token.safeTransfer(proposal.to, proposal.amount);

        emit ProposalExecuted(proposalId, proposal.to, proposal.amount);
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidParameters();

        token.safeTransferFrom(msg.sender, address(this), amount);
        balance += amount;

        emit Deposit(msg.sender, amount);
    }
}
