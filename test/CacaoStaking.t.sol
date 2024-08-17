// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {YUMStaking} from "../src/YUMStaking.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockToken} from "../src/MockToken.sol";

contract StakingTest is Test {
  YUMStaking public staking;
  IERC20 asset;
  address deployer = makeAddr("deployer");
  address user1 = makeAddr("user1");
  address user2 = makeAddr("user2");

  function setUp() public {
    vm.createSelectFork("arbitrum");
    uint256 cooldownPeriod = 3 days;
    asset = IERC20(address(new MockToken()));
    staking = new YUMStaking(asset, deployer, cooldownPeriod);
    console.log("YUMStaking deployed at: ", address(staking));

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

  function test_reddemBeforeCooldownShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);

    vm.expectRevert(YUMStaking.InvalidAmount.selector);
    staking.redeem(user1, user1, 0);
    vm.expectRevert(YUMStaking.InvalidAmount.selector);

    staking.redeem(user1, user1, 0);
    assertEq(staking.balanceOf(user1), amount);
  }

  function test_withdrawAfterCooldown() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount);
    skip(1 days);
    vm.expectRevert(YUMStaking.RedeemRequestNotReady.selector);
    staking.redeem(user1, user1, 0);
    skip(2 days);
    staking.redeem(user1, user1, 0);
    assertEq(staking.balanceOf(user1), 0);
  }

  function test_redeemAfterCooldown() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount);
    skip(1 days);
    vm.expectRevert(YUMStaking.RedeemRequestNotReady.selector);
    staking.redeem(user1, user1, 0);
    skip(2 days);
    staking.redeem(user1, user1, 0);
    assertEq(staking.balanceOf(user1), 0);
  }

  function test_redeemWithoutRequestingShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);

    vm.expectRevert(YUMStaking.InvalidAmount.selector);
    staking.redeem(user1, user1, 0);

    vm.expectRevert(YUMStaking.InvalidAmount.selector);
    staking.redeem(user1, user1, 0);
  }

  function test_partiallyRedeem() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount / 2);

    skip(1 days);
    vm.expectRevert(YUMStaking.RedeemRequestNotReady.selector);
    staking.redeem(user1, user1, 0);

    skip(2 days);
    staking.redeem(user1, user1, 0);
    assertEq(IERC20(asset).balanceOf(user1), amount / 2);
    vm.expectRevert(YUMStaking.RequestAlreadyProcessed.selector);
    staking.redeem(user1, user1, 0);
  }

  function test_withdrawMoreThanStakedShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    vm.expectRevert(YUMStaking.InsufficientBalance.selector);
    staking.requestRedeem(amount + 1);
  }

  function test_withdrawMoreThanStakedMinusRequestedShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(1);
    vm.expectRevert(YUMStaking.InsufficientBalance.selector);
    staking.requestRedeem(amount);
  }

  function test_redeemTheSameRequestIdShouldFail() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount);
    skip(3 days);
    staking.redeem(user1, user1, 0);
    vm.expectRevert(YUMStaking.RequestAlreadyProcessed.selector);
    staking.redeem(user1, user1, 0);
  }

  function test_makeMinimumRequestAndWithdrawAllAmount() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(1);
    skip(3 days);
    staking.redeem(user1, user1, 0);
  }

  function test_cancelRequestShouldReduceActiveRequests() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount);
    assertEq(staking.fetchRequests(user1, YUMStaking.RequestStatus.Pending).length, 1);
    staking.cancelRequest(0);
    assertEq(staking.fetchRequests(user1, YUMStaking.RequestStatus.Pending).length, 0);
  }

  function test_processRequestShouldReduceActiveRequests() public {
    uint amount = 1 ether;
    vm.startPrank(user1);
    asset.approve(address(staking), amount);
    staking.deposit(amount, user1);
    staking.requestRedeem(amount);
    assertEq(staking.fetchRequests(user1, YUMStaking.RequestStatus.Pending).length, 1);
    skip(3 days);
    staking.redeem(user1, user1, 0);
    assertEq(staking.fetchRequests(user1, YUMStaking.RequestStatus.Pending).length, 0);
  }
}
