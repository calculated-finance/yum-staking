// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {CacaoStaking} from "../src/CacaoStaking.sol";
import {MockToken} from "../src/MockToken.sol";
import {console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract CacaoStakingDeploy is Script {
  address token = 0x9F41b34f42058a7b74672055a5fae22c4b113Fd1; // Replace with the actual token address

  CacaoStaking public staking;

  function run() external {
    uint256 privateKey = vm.envUint("PRIVATE_KEY"); // Obtained from .env file
    address account = vm.addr(privateKey);
    console.log("Running script with account: ", account);

    vm.startBroadcast(privateKey); // Execute deployment with private key
    MockToken mockToken = new MockToken();
    console.log("mockToken deployed to: ", address(mockToken));
    console.log("mockToken balance of owner is: ", mockToken.balanceOf(account));

    staking = new CacaoStaking(IERC20(address(mockToken)), account);
    console.log("Staking contract deployed to: ", address(staking));

    vm.stopBroadcast();
  }
}

// forge script script/CacaoStakingDeploy.s.sol --fork-url http://localhost:8545
// forge script script/Airdrop.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify -vvvvv
