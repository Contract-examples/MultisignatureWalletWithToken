// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract MultisignatureWallet is Ownable {
    using SafeERC20 for IERC20;

    // multisignature wallet signers
    address[] public signers;

    // required approvals
    uint256 public requiredApprovals;

    // proposal struct
    struct Proposal {
        address to;
        uint256 amount;
        uint256 approvals;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    // proposal mapping
    mapping(uint256 => Proposal) public proposals;

    // proposal count
    uint256 public proposalCount;

    // token
    IERC20 public token;

    // balance
    uint256 public balances;

    // error
    error DepositTooLow();
    error InsufficientBalance();
    error NotSigner();
    error ProposalAlreadyExecuted();
    error InsufficientApprovals();
    error InvalidSigners();
    error InvalidThreshold();
    error AlreadyApproved();

    // event
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address to, uint256 amount);
    event ProposalApproved(uint256 indexed proposalId, address signer);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address _token, address[] memory _signers, uint256 _requiredApprovals) Ownable(msg.sender) {
        if (_signers.length == 0) revert InvalidSigners();
        if (_requiredApprovals == 0 || _requiredApprovals > _signers.length) revert InvalidThreshold();

        token = IERC20(_token);
        signers = _signers;
        requiredApprovals = _requiredApprovals;
    }

    // check if the sender is a signer
    modifier onlySigner() {
        bool isSigner = false;
        for (uint256 i = 0; i < signers.length; i++) {
            if (msg.sender == signers[i]) {
                isSigner = true;
                break;
            }
        }
        if (!isSigner) revert NotSigner();
        _;
    }

    // create proposal
    function createProposal(address to, uint256 amount) external onlySigner {
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.to = to;
        proposal.amount = amount;
        proposal.approvals = 0;
        proposal.executed = false;

        emit ProposalCreated(proposalId, to, amount);
    }

    // approve proposal
    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.hasApproved[msg.sender]) revert AlreadyApproved();

        proposal.approvals++;
        proposal.hasApproved[msg.sender] = true;

        emit ProposalApproved(proposalId, msg.sender);
    }

    // execute proposal
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.approvals < requiredApprovals) revert InsufficientApprovals();
        if (proposal.amount > balances) revert InsufficientBalance();

        proposal.executed = true;
        balances -= proposal.amount;
        token.safeTransfer(proposal.to, proposal.amount);

        // emit proposal executed event
        emit ProposalExecuted(proposalId);

        // emit withdraw event
        emit Withdraw(proposal.to, proposal.amount);
    }

    function deposit(uint256 amount) public {
        // if amount is 0, revert
        if (amount == 0) {
            revert DepositTooLow();
        }

        // transfer token from user to contract (safe transfer)
        token.safeTransferFrom(_msgSender(), address(this), amount);

        // update balance
        balances += amount;

        // emit event
        emit Deposit(_msgSender(), amount);
    }
}
