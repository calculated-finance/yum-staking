// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CacaoStaking} from "../src/CacaoStaking.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockToken} from "../src/MockToken.sol";

contract StakingTest is Test {
  error WithdrawalRequestNotReady();
  error RequestAlreadyProcessed();
  error InvalidAmount();

  CacaoStaking public staking;
  IERC20 asset;
  address deployer = makeAddr("deployer");
  address user1 = makeAddr("user1");
  address user2 = makeAddr("user2");

  function setUp() public {
    vm.createSelectFork("arbitrum");
    uint256 cooldownPeriod = 3 days;
    asset = IERC20(address(new MockToken()));
    staking = new CacaoStaking(asset, deployer, cooldownPeriod);
    console.log("CacaoStaking deployed at: ", address(staking));

    deal(address(asset), user1, 1 ether);
    deal(address(asset), user2, 1 ether);
  }

  function test_deposit() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    assertEq(staking.balanceOf(user1), amount);
  }

  function test_withdrawBeforeCooldownShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);

    vm.expectRevert(InvalidAmount.selector);
    staking.withdraw(user1, user1, 0);
    vm.expectRevert(InvalidAmount.selector);

    staking.redeem(user1, user1, 0);
    assertEq(staking.balanceOf(user1), amount);
  }

  function test_withdrawAfterCooldown() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestWithdrawOrRedeem(amount);
    skip(1 days);
    vm.expectRevert(WithdrawalRequestNotReady.selector);
    staking.withdraw(user1, user1, 0);
    skip(2 days);
    staking.withdraw(user1, user1, 0);
    assertEq(staking.balanceOf(user1), 0);
  }

  function test_redeemAfterCooldown() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestWithdrawOrRedeem(amount);
    skip(1 days);
    vm.expectRevert(WithdrawalRequestNotReady.selector);
    staking.redeem(user1, user1, 0);
    skip(2 days);
    staking.redeem(user1, user1, 0);
    assertEq(staking.balanceOf(user1), 0);
  }

  function test_redeemAndWithdrawWithoutRequesting() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);

    vm.expectRevert(InvalidAmount.selector);
    staking.redeem(user1, user1, 0);

    vm.expectRevert(InvalidAmount.selector);
    staking.withdraw(user1, user1, 0);
  }

  function test_partiallyWithdraw() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestWithdrawOrRedeem(amount / 2);

    skip(1 days);
    vm.expectRevert(WithdrawalRequestNotReady.selector);
    staking.withdraw(user1, user1, 0);

    skip(2 days);
    staking.withdraw(user1, user1, 0);
    assertEq(IERC20(asset).balanceOf(user1), amount / 2);
    vm.expectRevert(RequestAlreadyProcessed.selector);
    staking.withdraw(user1, user1, 0);
  }

  function test_withdrawWithTheSameRequestIdShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestWithdrawOrRedeem(amount);
    skip(3 days);
    staking.withdraw(user1, user1, 0);
    vm.expectRevert(RequestAlreadyProcessed.selector);
    staking.withdraw(user1, user1, 0);
  }

  function test_makeMinimumRequestAndWithdrawAllAmount() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestWithdrawOrRedeem(1);
    skip(3 days);
    staking.withdraw(user1, user1, 0);
  }

  // If i make a request, I should transfer that request amount
}
