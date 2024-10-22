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

    // proposal type
    enum ProposalType {
        Transfer,
        AddSigner,
        RemoveSigner
    }

    // proposal struct
    struct Proposal {
        address to;
        uint256 amount;
        uint256 approvals;
        mapping(address => bool) hasApproved;
        bool executed;
        ProposalType proposalType;
        address signerToAddOrRemove; // used for add or remove signer
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
    event ProposalCreated(
        uint256 indexed proposalId, address to, uint256 amount, ProposalType proposalType, address signerToAddOrRemove
    );
    event ProposalApproved(uint256 indexed proposalId, address signer);
    event ProposalExecuted(
        uint256 indexed proposalId, address to, uint256 amount, ProposalType proposalType, address signerToAddOrRemove
    );
    event SignerAdded(address signer);
    event SignerRemoved(address signer);
    event SignerTransfer(address to, uint256 amount);

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

    // create proposal
    function createProposal(
        address to,
        uint256 amount,
        ProposalType proposalType,
        address signerToAddOrRemove
    )
        external
        onlySigner
    {
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.to = to;
        proposal.amount = amount;
        // set proposal type
        proposal.proposalType = proposalType;
        // set signer to add or remove
        proposal.signerToAddOrRemove = signerToAddOrRemove;

        emit ProposalCreated(proposalId, to, amount, proposalType, signerToAddOrRemove);
    }

    // approve proposal
    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.hasApproved[msg.sender]) return;

        // increase approvals
        proposal.approvals++;
        // set approved
        proposal.hasApproved[msg.sender] = true;

        emit ProposalApproved(proposalId, msg.sender);
    }

    // execute proposal
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.approvals < requiredApprovals) revert InsufficientApprovals();

        proposal.executed = true;

        if (proposal.proposalType == ProposalType.Transfer) {
            if (proposal.amount > balance) revert InsufficientBalance();
            // transfer token to the address first
            token.safeTransfer(proposal.to, proposal.amount);
            // then update balance
            balance -= proposal.amount;
            // emit signer transfer
            emit SignerTransfer(proposal.to, proposal.amount);
        } else if (proposal.proposalType == ProposalType.AddSigner) {
            if (!isSigner[proposal.signerToAddOrRemove]) {
                isSigner[proposal.signerToAddOrRemove] = true;
                signerCount++;
                // emit signer added
                emit SignerAdded(proposal.signerToAddOrRemove);
            }
        } else if (proposal.proposalType == ProposalType.RemoveSigner) {
            if (isSigner[proposal.signerToAddOrRemove]) {
                if (signerCount <= requiredApprovals) revert CannotRemoveSigner();
                isSigner[proposal.signerToAddOrRemove] = false;
                signerCount--;
                // emit signer removed
                emit SignerRemoved(proposal.signerToAddOrRemove);
            }
        }

        // emit proposal executed
        emit ProposalExecuted(
            proposalId, proposal.to, proposal.amount, proposal.proposalType, proposal.signerToAddOrRemove
        );
    }

    // check if a signer has approved a proposal
    function hasApproved(uint256 proposalId, address signer) public view returns (bool) {
        return proposals[proposalId].hasApproved[signer];
    }

    // deposit
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidParameters();

        token.safeTransferFrom(msg.sender, address(this), amount);
        balance += amount;

        emit Deposit(msg.sender, amount);
    }
}
