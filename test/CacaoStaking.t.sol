// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CacaoStaking} from "../src/CacaoStaking.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockToken} from "../src/MockToken.sol";

contract CounterTest is Test {
  CacaoStaking public staking;
  IERC20 asset;
  address deployer = makeAddr("deployer");
  address user1 = makeAddr("user1");
  address user2 = makeAddr("user2");

  function setUp() public {
    asset = IERC20(address(new MockToken()));
    staking = new CacaoStaking(asset, deployer);
    console.log("CacaoStaking deployed at: ", address(staking));
  }
}
