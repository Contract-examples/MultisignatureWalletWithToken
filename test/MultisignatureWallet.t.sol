// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MultisignatureWallet.sol";
import "../src/MyERC20Token.sol";

contract MultisignatureWalletTest is Test {
    MultisignatureWallet public wallet;
    MyERC20Token public token;
    address[] public signers;
    uint256 public constant REQUIRED_APPROVALS = 2;

    address public user1;
    address public user2;
    address public user3;
    address public nonSigner;

    function setUp() public {
        token = new MyERC20Token("TestToken", "TT");

        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        nonSigner = address(0x4);

        signers = [user1, user2, user3];
        wallet = new MultisignatureWallet(address(token), signers, REQUIRED_APPROVALS);

        // mint tokens to each signer
        token.mint(user1, 1000 * 10 ** 18);
        token.mint(user2, 1000 * 10 ** 18);
        token.mint(user3, 1000 * 10 ** 18);
    }

    function testConstructor() public view {
        assertEq(wallet.signerCount(), 3);
        assertEq(wallet.requiredApprovals(), REQUIRED_APPROVALS);
        assertTrue(wallet.isSigner(user1));
        assertTrue(wallet.isSigner(user2));
        assertTrue(wallet.isSigner(user3));
        assertFalse(wallet.isSigner(nonSigner));
    }

    function testDeposit() public {
        uint256 amount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(wallet), amount);
        wallet.deposit(amount);
        vm.stopPrank();

        assertEq(wallet.balance(), amount);
        assertEq(token.balanceOf(address(wallet)), amount);
    }

    function testCreateProposal() public {
        vm.prank(user1);
        wallet.createProposal(nonSigner, 50 * 10 ** 18, MultisignatureWallet.ProposalType.Transfer, address(0));

        (
            address to,
            uint256 amount,
            uint256 approvals,
            bool executed,
            MultisignatureWallet.ProposalType proposalType,
            address signerToAddOrRemove
        ) = wallet.proposals(0);
        assertEq(to, nonSigner);
        assertEq(amount, 50 * 10 ** 18);
        assertEq(approvals, 0);
        assertFalse(executed);
        assertEq(uint256(proposalType), uint256(MultisignatureWallet.ProposalType.Transfer));
        assertEq(signerToAddOrRemove, address(0));
    }

    function testApproveProposal() public {
        vm.prank(user1);
        wallet.createProposal(nonSigner, 50 * 10 ** 18, MultisignatureWallet.ProposalType.Transfer, address(0));

        vm.prank(user2);
        wallet.approveProposal(0);

        (,, uint256 approvals,,,) = wallet.proposals(0);
        assertEq(approvals, 1);
        assertTrue(wallet.hasApproved(0, user2));
        assertFalse(wallet.hasApproved(0, user1));
    }

    function testExecuteTransferProposal() public {
        uint256 amount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(wallet), amount);
        wallet.deposit(amount);
        wallet.createProposal(nonSigner, 50 * 10 ** 18, MultisignatureWallet.ProposalType.Transfer, address(0));
        wallet.approveProposal(0);
        vm.stopPrank();

        vm.prank(user2);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        (address to, uint256 proposalAmount,, bool executed, MultisignatureWallet.ProposalType proposalType,) =
            wallet.proposals(0);
        assertTrue(executed);
        assertEq(to, nonSigner);
        assertEq(proposalAmount, 50 * 10 ** 18);
        assertEq(uint256(proposalType), uint256(MultisignatureWallet.ProposalType.Transfer));
        assertEq(token.balanceOf(nonSigner), 50 * 10 ** 18);
        assertEq(wallet.balance(), 50 * 10 ** 18);
    }

    function testAddSigner() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.AddSigner, nonSigner);

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user3);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        assertTrue(wallet.isSigner(nonSigner));
        assertEq(wallet.signerCount(), 4);
    }

    function testAddSigner2() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.AddSigner, nonSigner);

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user1);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        assertTrue(wallet.isSigner(nonSigner));
        assertEq(wallet.signerCount(), 4);
    }

    function testRemoveSigner() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.RemoveSigner, user3);

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user3);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        assertFalse(wallet.isSigner(user3));
        assertEq(wallet.signerCount(), 2);
    }

    function testRemoveSigner2() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.RemoveSigner, user3);

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user1);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        assertFalse(wallet.isSigner(user3));
        assertEq(wallet.signerCount(), 2);
    }

    function testFailNonSignerCreateProposal() public {
        vm.prank(nonSigner);
        wallet.createProposal(nonSigner, 50 * 10 ** 18, MultisignatureWallet.ProposalType.Transfer, address(0));
    }

    function testFailInsufficientBalance() public {
        vm.prank(user1);
        wallet.createProposal(nonSigner, 50 * 10 ** 18, MultisignatureWallet.ProposalType.Transfer, address(0));

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user3);
        wallet.approveProposal(0);

        wallet.executeProposal(0);
    }

    function testFailAddSignerWithoutEnoughApprovals() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.AddSigner, nonSigner);

        vm.prank(user2);
        wallet.approveProposal(0);

        wallet.executeProposal(0);
    }

    function testFailRemoveSignerWithoutEnoughApprovals() public {
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.RemoveSigner, user3);

        vm.prank(user2);
        wallet.approveProposal(0);

        wallet.executeProposal(0);
    }

    function testFailRemoveLastRequiredSigner() public {
        // First, remove one signer to reach the minimum required signers
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.RemoveSigner, user3);

        vm.prank(user2);
        wallet.approveProposal(0);

        vm.prank(user3);
        wallet.approveProposal(0);

        wallet.executeProposal(0);

        // Now try to remove another signer, which should fail
        vm.prank(user1);
        wallet.createProposal(address(0), 0, MultisignatureWallet.ProposalType.RemoveSigner, user2);

        vm.prank(user2);
        wallet.approveProposal(1);

        wallet.executeProposal(1);

        // TODO: test revert
    }
}
