// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "./interfaces/IERC20.sol";
import {ERC20Vote} from "./lib/ERC20Vote.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {FixedPointMathLib} from "./lib/FixedPointMathLib.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title YUMStaking
 * @notice A staking contract that allows users to deposit an asset and receive shares in return.
 * @dev The contract is mainly a fork of vTHOR staking contract (https://github.com/thorswap/evm-contracts/blob/main/src/contracts/tokens/vTHOR.sol)
 */
contract YUMStaking is ERC20Vote, ReentrancyGuard, Ownable2Step {
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
  constructor(IERC20 asset_, address initialOwner, uint256 _cooldownPeriod) ERC20Vote("YUMStaking", "vYUM", 18) Ownable(initialOwner) {
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
   * @notice Previews the amount of assets received for a given amount of shares.
   * @param shares The amount of shares to redeem.
   * @return The amount of assets that would be received.
   */
  function previewRedeem(uint256 shares) public view returns (uint256) {
    return convertToAssets(shares);
  }

  /**
   * @notice Returns the maximum amount of shares that can be redeemed by a given owner.
   * @param owner The address of the owner.
   * @return The maximum amount of shares that can be redeemed.
   */
  function maxRedeem(address owner) public view returns (uint256) {
    uint256 currentBalance = balanceOf[owner];
    Request[] storage requestedWithdrawals = requestsPerUser[owner];
    uint256 totalRequested = 0;
    for (uint256 i = 0; i < requestedWithdrawals.length; i++) {
      if (requestedWithdrawals[i].status == RequestStatus.Pending) {
        totalRequested += requestedWithdrawals[i].shares;
      }
    }
    if (currentBalance < totalRequested) return 0;
    return currentBalance - totalRequested;
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
   * @notice Redeems a given amount of shares for the equivalent amount of assets.
   * @param receiver The address receiving the assets.
   * @param owner The address of the shares' owner.
   * @return assets The amount of assets redeemed.
   */
  function redeem(address receiver, address owner, uint256 id) external nonReentrant returns (uint256 assets) {
    _processAndVerifyCooldownPeriod(id);
    uint shares = requests[msg.sender][id].shares;

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
  /*                             redeem requests                                */
  /* -------------------------------------------------------------------------- */

  event RedeemRequest(address indexed owner, uint256 id, uint256 amount);
  event CancelRequest(address indexed owner, uint256 id, uint256 amount);
  error RedeemRequestNotReady();
  error InsufficientBalance();
  error NoWithdrawalRequests();
  error InvalidAmount();
  error RequestAlreadyProcessed();
  error RequestCancelled();
  event CooldownPeriodUpdated(uint256 newCooldownPeriod);

  uint256 public globalIds;
  uint256 public cooldownPeriod;
  mapping(address user => mapping(uint256 id => Request)) public requests;
  mapping(address user => Request[] requests) internal requestsPerUser;

  enum RequestStatus {
    Pending,
    Processed,
    Cancelled
  }

  struct Request {
    uint256 id;
    uint256 shares;
    uint256 timeOfRequest;
    RequestStatus status;
  }

  /**
   * @notice Sets the cooldown period for withdrawal requests.
   * @param timeInSeconds The new cooldown period in seconds.
   */
  function setCooldownPeriod(uint256 timeInSeconds) external onlyOwner {
    emit CooldownPeriodUpdated(timeInSeconds);
    cooldownPeriod = timeInSeconds;
  }

  /**
   * @notice Requests to redeem a given amount of shares.
   * @param amount The amount of shares to redeem.
   */
  function requestRedeem(uint256 amount) external {
    if (maxRedeem(msg.sender) < amount) revert InsufficientBalance();
    Request memory newRequest = Request(globalIds, amount, block.timestamp, RequestStatus.Pending);
    requests[msg.sender][globalIds] = newRequest;
    requestsPerUser[msg.sender].push(newRequest);
    emit RedeemRequest(msg.sender, globalIds, amount);
    ++globalIds;
  }

  function cancelRequest(uint256 id) external {
    Request storage request = requests[msg.sender][id];
    if (request.status == RequestStatus.Processed) revert RequestAlreadyProcessed();
    if (request.status == RequestStatus.Cancelled) revert RequestCancelled();
    request.status = RequestStatus.Cancelled;
    for (uint256 i = 0; i < requestsPerUser[msg.sender].length; i++) {
      if (requestsPerUser[msg.sender][i].id == id) {
        requestsPerUser[msg.sender][i].status = RequestStatus.Cancelled;
        break;
      }
    }
    emit CancelRequest(msg.sender, id, request.shares);
  }

  /**
   * @notice Processes a withdrawal request.
   * @param id The id of the request.
   */
  function _processAndVerifyCooldownPeriod(uint256 id) internal {
    Request storage request = requests[msg.sender][id];
    if (request.status == RequestStatus.Processed) revert RequestAlreadyProcessed();
    if (request.status == RequestStatus.Cancelled) revert RequestCancelled();
    if (block.timestamp < request.timeOfRequest + cooldownPeriod) revert RedeemRequestNotReady();
    if (request.shares == 0) revert InvalidAmount();
    request.status = RequestStatus.Processed;
    for (uint256 i = 0; i < requestsPerUser[msg.sender].length; i++) {
      if (requestsPerUser[msg.sender][i].id == id) {
        requestsPerUser[msg.sender][i].status = RequestStatus.Processed;
        break;
      }
    }
  }

  /**
   * @notice Fetches active requests for a given user.
   * @param user The address of the user.
   * @return The requests for the user.
   */
  function fetchRequests(address user, RequestStatus status) external view returns (Request[] memory) {
    uint256 count;
    for (uint256 i = 0; i < requestsPerUser[user].length; i++) {
      if (requestsPerUser[user][i].status == status) {
        count++;
      }
    }
    Request[] memory filteredRequests = new Request[](count);
    uint256 index;
    for (uint256 i = 0; i < requestsPerUser[user].length; i++) {
      if (requestsPerUser[user][i].status == status) {
        filteredRequests[index] = requestsPerUser[user][i];
        index++;
      }
    }
    return filteredRequests;
  }
}
