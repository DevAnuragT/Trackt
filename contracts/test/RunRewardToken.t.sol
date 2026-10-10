// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {RunRewardToken} from "../src/RunRewardToken.sol";

contract RunRewardTokenTest is TestBase {
    RunRewardToken internal token;

    address internal owner = address(this);
    address internal minter = address(0xBEEF);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new RunRewardToken();
    }

    // ----- Metadata & ownership -----

    function test_Metadata() public {
        assertEq(token.decimals(), uint256(18), "decimals");
        assertEq(token.totalSupply(), uint256(0), "supply starts at 0");
        assertEq(token.owner(), owner, "owner is deployer");
    }

    // ----- Minter management -----

    function test_SetMinter() public {
        token.setMinter(minter, true);
        assertTrue(token.isMinter(minter), "minter granted");
        token.setMinter(minter, false);
        assertFalse(token.isMinter(minter), "minter revoked");
    }

    function test_SetMinter_RevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(RunRewardToken.NotOwner.selector);
        token.setMinter(minter, true);
    }

    function test_SetMinter_RevertsForZeroAddress() public {
        vm.expectRevert(RunRewardToken.ZeroAddress.selector);
        token.setMinter(address(0), true);
    }

    // ----- Minting -----

    function test_Mint_ByMinter() public {
        token.setMinter(minter, true);
        vm.prank(minter);
        token.mint(alice, 1_000 ether);
        assertEq(token.balanceOf(alice), 1_000 ether, "alice balance");
        assertEq(token.totalSupply(), 1_000 ether, "total supply");
    }

    function test_Mint_RevertsForNonMinter() public {
        vm.prank(alice);
        vm.expectRevert(RunRewardToken.NotMinter.selector);
        token.mint(alice, 1 ether);
    }

    function test_Mint_RevertsForZeroRecipient() public {
        token.setMinter(owner, true);
        vm.expectRevert(RunRewardToken.ZeroAddress.selector);
        token.mint(address(0), 1 ether);
    }

    // ----- Transfers -----

    function test_Transfer() public {
        _mint(alice, 100 ether);
        vm.prank(alice);
        token.transfer(bob, 40 ether);
        assertEq(token.balanceOf(alice), 60 ether, "alice after transfer");
        assertEq(token.balanceOf(bob), 40 ether, "bob after transfer");
    }

    function test_Transfer_RevertsOnInsufficientBalance() public {
        _mint(alice, 10 ether);
        vm.prank(alice);
        vm.expectRevert(RunRewardToken.InsufficientBalance.selector);
        token.transfer(bob, 11 ether);
    }

    function test_Transfer_RevertsToZero() public {
        _mint(alice, 10 ether);
        vm.prank(alice);
        vm.expectRevert(RunRewardToken.ZeroAddress.selector);
        token.transfer(address(0), 1 ether);
    }

    // ----- Approvals -----

    function test_ApproveAndTransferFrom() public {
        _mint(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, 30 ether);
        assertEq(token.allowance(alice, bob), 30 ether, "allowance set");

        vm.prank(bob);
        token.transferFrom(alice, bob, 20 ether);
        assertEq(token.balanceOf(bob), 20 ether, "bob received");
        assertEq(token.allowance(alice, bob), 10 ether, "allowance decremented");
    }

    function test_TransferFrom_InfiniteAllowanceNotDecremented() public {
        _mint(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, bob, 50 ether);
        assertEq(token.allowance(alice, bob), type(uint256).max, "infinite allowance preserved");
    }

    function test_TransferFrom_RevertsOnInsufficientAllowance() public {
        _mint(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, 5 ether);
        vm.prank(bob);
        vm.expectRevert(RunRewardToken.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 6 ether);
    }

    // ----- Ownership -----

    function test_TransferOwnership() public {
        token.transferOwnership(alice);
        assertEq(token.owner(), alice, "ownership moved");
    }

    function test_TransferOwnership_RevertsForZero() public {
        vm.expectRevert(RunRewardToken.ZeroAddress.selector);
        token.transferOwnership(address(0));
    }

    // ----- Fuzz -----

    function testFuzz_MintThenTransfer(uint128 mintAmt, uint128 sendAmt) public {
        vm.assume(sendAmt <= mintAmt);
        _mint(alice, mintAmt);
        vm.prank(alice);
        token.transfer(bob, sendAmt);
        assertEq(token.balanceOf(bob), uint256(sendAmt), "fuzz bob balance");
        assertEq(token.balanceOf(alice), uint256(mintAmt) - uint256(sendAmt), "fuzz alice balance");
    }

    // ----- Helpers -----

    function _mint(address to, uint256 amount) internal {
        token.setMinter(owner, true);
        token.mint(to, amount);
    }
}
