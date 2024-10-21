// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultisignatureWallet {
    using SafeERC20 for IERC20;

    // signers mapping
    mapping(address => bool) public isSigner;
    // signer count
    uint256 public signerCount;
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
    error NotSigner();
    error CannotRemoveSigner();

    event Deposit(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address to, uint256 amount);
    event ProposalApproved(uint256 indexed proposalId, address signer);
    event ProposalExecuted(uint256 indexed proposalId, address to, uint256 amount);
    event SignerAdded(address signer);
    event SignerRemoved(address signer);

    constructor(address _token, address[] memory _signers, uint256 _requiredApprovals) {
        // check if parameters are valid
        if (_signers.length == 0 || _requiredApprovals == 0 || _requiredApprovals > _signers.length) {
            revert InvalidParameters();
        }

        token = IERC20(_token);

        for (uint256 i = 0; i < _signers.length; i++) {
            isSigner[_signers[i]] = true;
            emit SignerAdded(_signers[i]);
        }
        signerCount = _signers.length;
        requiredApprovals = _requiredApprovals;
    }

    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert Unauthorized();
        _;
    }

    // create proposalq
    function createProposal(address to, uint256 amount) external onlySigner {
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.to = to;
        proposal.amount = amount;

        emit ProposalCreated(proposalId, to, amount);
    }

    // approve proposal
    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.hasApproved[msg.sender]) return;

        proposal.approvals++;
        proposal.hasApproved[msg.sender] = true;

        emit ProposalApproved(proposalId, msg.sender);
    }

    // execute proposal and transfer
    function executeProposalAndTransfer(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.approvals < requiredApprovals) revert InsufficientApprovals();
        if (proposal.amount > balance) revert InsufficientBalance();

        proposal.executed = true;
        token.safeTransfer(proposal.to, proposal.amount);
        balance -= proposal.amount;

        emit ProposalExecuted(proposalId, proposal.to, proposal.amount);
    }

    // deposit
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidParameters();

        token.safeTransferFrom(msg.sender, address(this), amount);
        balance += amount;

        emit Deposit(msg.sender, amount);
    }

    // add signer
    function addSigner(address newSigner) external onlySigner {
        if (!isSigner[newSigner]) {
            isSigner[newSigner] = true;
            signerCount++;
            emit SignerAdded(newSigner);
        }
    }

    // remove signer
    function removeSigner(address signerToRemove) external onlySigner {
        if (!isSigner[signerToRemove]) revert NotSigner();
        if (signerCount <= requiredApprovals) revert CannotRemoveSigner();
        isSigner[signerToRemove] = false;
        signerCount--;
        emit SignerRemoved(signerToRemove);
    }
}
