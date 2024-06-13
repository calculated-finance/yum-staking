// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC4626} from "./interfaces/IERC4626.sol";
import {ERC20Vote} from "./lib/ERC20Vote.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {FixedPointMathLib} from "./lib/FixedPointMathLib.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";

/**
 * @title CacaoStaking
 * @notice A staking contract that allows users to deposit an asset and receive shares in return.
 * @dev The contract is mainly a fork of vTHOR staking contract (https://github.com/thorswap/evm-contracts/blob/main/src/contracts/tokens/vTHOR.sol)
 */
contract CacaoStaking is IERC4626, ERC20Vote, ReentrancyGuard {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  error ZeroShares();
  error ZeroAssets();

  IERC20 internal _asset;

  constructor(IERC20 asset_) ERC20Vote("CacaoSwapStaking", "CSST", 18) {
    _asset = asset_;
  }

  /* -------------------------------------------------------------------------- */
  /*                               view functions                               */
  /* -------------------------------------------------------------------------- */

  function asset() external view returns (address) {
    return address(_asset);
  }

  function totalAssets() public view returns (uint256) {
    return _asset.balanceOf(address(this));
  }

  function convertToShares(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  function convertToAssets(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
  }

  function previewDeposit(uint256 assets) public view returns (uint256) {
    return convertToShares(assets);
  }

  function previewMint(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
  }

  function previewWithdraw(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
  }

  function previewRedeem(uint256 shares) public view returns (uint256) {
    return convertToAssets(shares);
  }

  function maxWithdraw(address owner) public view returns (uint256) {
    return convertToAssets(balanceOf[owner]);
  }

  function maxRedeem(address owner) public view returns (uint256) {
    return balanceOf[owner];
  }

  function maxDeposit(address) external pure returns (uint256) {
    return type(uint256).max;
  }

  function maxMint(address) external pure returns (uint256) {
    return type(uint256).max;
  }
  /* -------------------------------------------------------------------------- */
  /*                               core functions                               */
  /* -------------------------------------------------------------------------- */

  function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
    // Check for rounding error since we round down in previewDeposit.
    if ((shares = previewDeposit(assets)) == 0) revert ZeroShares();
    // Need to transfer before minting or ERC777s could reenter.
    address(_asset).safeTransferFrom(msg.sender, address(this), assets);
    _mint(receiver, shares);
    emit Deposit(msg.sender, receiver, assets, shares);
  }

  function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
    assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.
    // Need to transfer before minting or ERC777s could reenter.
    address(_asset).safeTransferFrom(msg.sender, address(this), assets);
    _mint(receiver, shares);
    emit Deposit(msg.sender, receiver, assets, shares);
  }

  function withdraw(uint256 assets, address receiver, address owner) external nonReentrant returns (uint256 shares) {
    shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.
      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }
    _burn(owner, shares);
    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    address(_asset).safeTransfer(receiver, assets);
  }

  function redeem(uint256 shares, address receiver, address owner) external nonReentrant returns (uint256 assets) {
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.
      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }
    // Check for rounding error since we round down in previewRedeem.
    if ((assets = previewRedeem(shares)) == 0) revert ZeroAssets();
    _burn(owner, shares);
    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    address(_asset).safeTransfer(receiver, assets);
  }
}
