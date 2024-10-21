// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MultisignatureWallet.sol";
import "../src/MyERC20Token.sol";

contract MultisignatureWalletTest is Test {
    //   AdminTokenBank public bank;
    MyERC20Token public token;
    address public owner;
    address public admin;
    address public user;

    function setUp() public {
        token = new MyERC20Token("MyNFTToken", "MTK");
        owner = address(this);
        admin = address(0x3389);
        user = address(0x1);
        // bank = new AdminTokenBank(admin, address(token));

        // give user 1000 tokens
        token.mint(user, 10_000 * 10 ** 18);
    }

    function test_add_signer() public {
      
    }
}
