// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20("MockToken", "MOCK") {
  address owner = msg.sender;

  constructor() {
    _mint(msg.sender, 10_000 ether);
  }

  function mint(address account, uint256 amount) external {
    if (msg.sender != owner) revert();
    _mint(account, amount);
  }
}
