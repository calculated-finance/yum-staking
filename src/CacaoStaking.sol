// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "./interfaces/IERC20.sol";
import {ERC20Vote} from "./lib/ERC20Vote.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {FixedPointMathLib} from "./lib/FixedPointMathLib.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title CacaoStaking
 * @notice A staking contract that allows users to deposit an asset and receive shares in return.
 * @dev The contract is mainly a fork of vTHOR staking contract (https://github.com/thorswap/evm-contracts/blob/main/src/contracts/tokens/vTHOR.sol)
 */
contract CacaoStaking is ERC20Vote, ReentrancyGuard, Ownable2Step {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

  /// @dev Error thrown when zero shares are calculated
  error ZeroShares();

  /// @dev Error thrown when zero assets are calculated
  error ZeroAssets();

  IERC20 internal _asset;

  /**
   * @dev Initializes the staking contract with the given asset.
   * @param asset_ The asset to be staked.
   */
  constructor(IERC20 asset_, address initialOwner, uint256 _cooldownPeriod) ERC20Vote("CacaoSwapStaking", "CSST", 18) Ownable(initialOwner) {
    _asset = asset_;
    cooldownPeriod = _cooldownPeriod;
  }

  /* -------------------------------------------------------------------------- */
  /*                               view functions                               */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Returns the address of the staked asset.
   * @return The address of the staked asset.
   */
  function asset() external view returns (address) {
    return address(_asset);
  }

  /**
   * @notice Returns the total assets staked in the contract.
   * @return The total assets staked in the contract.
   */
  function totalAssets() public view returns (uint256) {
    return _asset.balanceOf(address(this));
  }

  /**
   * @notice Converts a given amount of assets to shares.
   * @param assets The amount of assets to convert.
   * @return The equivalent amount of shares.
   */
  function convertToShares(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  /**
   * @notice Converts a given amount of shares to assets.
   * @param shares The amount of shares to convert.
   * @return The equivalent amount of assets.
   */
  function convertToAssets(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
  }

  /**
   * @notice Previews the amount of shares received for a given amount of assets.
   * @param assets The amount of assets to deposit.
   * @return The amount of shares that would be received.
   */
  function previewDeposit(uint256 assets) public view returns (uint256) {
    return convertToShares(assets);
  }

  /**
   * @notice Previews the amount of assets required for a given amount of shares.
   * @param shares The amount of shares to mint.
   * @return The amount of assets that would be required.
   */
  function previewMint(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
  }

  /**
   * @notice Previews the amount of shares required for a given amount of assets to withdraw.
   * @param assets The amount of assets to withdraw.
   * @return The amount of shares that would be required.
   */
  function previewWithdraw(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
  }

  /**
   * @notice Previews the amount of assets received for a given amount of shares.
   * @param shares The amount of shares to redeem.
   * @return The amount of assets that would be received.
   */
  function previewRedeem(uint256 shares) public view returns (uint256) {
    return convertToAssets(shares);
  }

  /**
   * @notice Returns the maximum amount of assets that can be withdrawn by a given owner.
   * @param owner The address of the owner.
   * @return The maximum amount of assets that can be withdrawn.
   */
  function maxWithdraw(address owner) public view returns (uint256) {
    return convertToAssets(balanceOf[owner]);
  }

  /**
   * @notice Returns the maximum amount of shares that can be redeemed by a given owner.
   * @param owner The address of the owner.
   * @return The maximum amount of shares that can be redeemed.
   */
  function maxRedeem(address owner) public view returns (uint256) {
    return balanceOf[owner];
  }

  /**
   * @notice Returns the maximum amount of assets that can be deposited by any address.
   * @return The maximum amount of assets that can be deposited.
   */
  function maxDeposit(address) external pure returns (uint256) {
    return type(uint256).max;
  }

  /**
   * @notice Returns the maximum amount of shares that can be minted by any address.
   * @return The maximum amount of shares that can be minted.
   */
  function maxMint(address) external pure returns (uint256) {
    return type(uint256).max;
  }
  /* -------------------------------------------------------------------------- */
  /*                               core functions                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Deposits a given amount of assets and mints the equivalent amount of shares.
   * @param assets The amount of assets to deposit.
   * @param receiver The address receiving the shares.
   * @return shares The amount of shares minted.
   */
  function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
    // Check for rounding error since we round down in previewDeposit.
    if ((shares = previewDeposit(assets)) == 0) revert ZeroShares();
    // Need to transfer before minting or ERC777s could reenter.
    address(_asset).safeTransferFrom(msg.sender, address(this), assets);
    _mint(receiver, shares);
    emit Deposit(msg.sender, receiver, assets, shares);
  }

  /**
   * @notice Mints a given amount of shares by depositing the equivalent amount of assets.
   * @param shares The amount of shares to mint.
   * @param receiver The address receiving the shares.
   * @return assets The amount of assets deposited.
   */
  function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
    assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.
    // Need to transfer before minting or ERC777s could reenter.
    address(_asset).safeTransferFrom(msg.sender, address(this), assets);
    _mint(receiver, shares);
    emit Deposit(msg.sender, receiver, assets, shares);
  }

  /**
   * @notice Withdraws a given amount of assets by burning the equivalent amount of shares.
   * @param receiver The address receiving the assets.
   * @param owner The address of the shares' owner.
   * @return shares The amount of shares burned.
   */
  function withdraw(address receiver, address owner, uint256 id) public nonReentrant returns (uint256 shares) {
    /* ---------------------------------- added --------------------------------- */
    _processAndVerifyCooldownPeriod(id);
    uint assets = requests[msg.sender][id].amount;
    /* ---------------------------------- added --------------------------------- */

    shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.
      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }
    _burn(owner, shares);
    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    address(_asset).safeTransfer(receiver, assets);
  }

  /**
   * @notice Redeems a given amount of shares for the equivalent amount of assets.
   * @param receiver The address receiving the assets.
   * @param owner The address of the shares' owner.
   * @return assets The amount of assets redeemed.
   */
  function redeem(address receiver, address owner, uint256 id) external nonReentrant returns (uint256 assets) {
    /* ---------------------------------- added --------------------------------- */
    _processAndVerifyCooldownPeriod(id);
    uint shares = requests[msg.sender][id].amount;

    /* ---------------------------------- added --------------------------------- */

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

  /* -------------------------------------------------------------------------- */
  /*                             withdrawal requests                            */
  /* -------------------------------------------------------------------------- */

  event WithdrawalRequest(address indexed owner, uint256 id, uint256 amount);
  error WithdrawalRequestNotReady();
  error InsufficientBalance();
  error NoWithdrawalRequests();
  error InvalidAmount();
  error RequestAlreadyProcessed();
  event CooldownPeriodUpdated(uint256 newCooldownPeriod);

  uint256 globalIds;
  uint256 public cooldownPeriod;
  mapping(address user => mapping(uint256 id => Request)) public requests;

  struct Request {
    uint256 amount;
    uint256 timeOfRequest;
    bool processed;
  }

  function setCooldownPeriod(uint256 timeInSeconds) external onlyOwner {
    emit CooldownPeriodUpdated(timeInSeconds);
    cooldownPeriod = timeInSeconds;
  }

  function requestWithdrawOrRedeem(uint256 amount) external {
    if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
    requests[msg.sender][globalIds] = Request(amount, block.timestamp, false);
    emit WithdrawalRequest(msg.sender, globalIds, amount);
    ++globalIds;
  }

  function _processAndVerifyCooldownPeriod(uint256 id) internal {
    Request storage request = requests[msg.sender][id];
    if (request.processed) revert RequestAlreadyProcessed();
    if (block.timestamp < request.timeOfRequest + cooldownPeriod) revert WithdrawalRequestNotReady();
    if (request.amount == 0) revert InvalidAmount();
    emit log(block.timestamp);
    emit log(request.timeOfRequest + cooldownPeriod);
    request.processed = true;
  }

  event log(string);
  event log(uint);
}
