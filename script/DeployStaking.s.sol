// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {YUMStaking} from "../src/YUMStaking.sol";
import {MockToken} from "../src/MockToken.sol";
import {console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract DeployStaking is Script {
  address token = 0x9F41b34f42058a7b74672055a5fae22c4b113Fd1;
  address initialOwner = 0x2B62456efa5Cc0c09F0aa9a1ccEcFcca2396a4e9;
  uint256 cooldownPeriod = 14 days;

  function run() external {
    uint256 privateKey = vm.envUint("PRIVATE_KEY"); // Obtained from .env file
    vm.startBroadcast(privateKey);
    new YUMStaking(IERC20(token), initialOwner, cooldownPeriod);
    vm.stopBroadcast();
  }

  // address staking = 0x2BFDeD2599De2549e163dcFEFCD0d7f8a234Eb9e;
  // YUMStaking stakingContract = YUMStaking(staking);

  // function run() external {
  //   uint256 privateKey = vm.envUint("PRIVATE_KEY"); // Obtained from .env file
  //   vm.startBroadcast(privateKey);
  //   stakingContract.setCooldownPeriod(5 seconds);
  //   vm.stopBroadcast();
  // }
}
