# CacaoSwap Staking

## Overview

The YUMStaking contract is designed to allow users to stake a specific ERC20 token (referred to as the asset) and receive shares in return. These shares represent the user's stake in the contract and can be redeemed for the underlying asset at any time. The contract ensures secure and efficient handling of deposits, mints, withdrawals, and redemptions, providing a reliable staking mechanism for users. Maximum deposit and mint limits are set to the maximum possible value, allowing flexibility for users. The contract ensures accurate conversion between assets and shares and includes security features to protect user funds.

## How It Works

### Deposit Assets:

Users can deposit the specified ERC20 asset into the contract.In return for their deposit, they receive shares that represent their stake in the contract. The amount of shares received is proportional to the amount of assets deposited.

### Mint Shares:

Users can choose to mint a specific number of shares by depositing the corresponding amount of assets. This allows users to specify the number of shares they want to receive rather than the amount of assets they want to deposit.

### Withdraw Assets:

Users can withdraw a specified amount of assets from the contract.To do this, they need to burn the equivalent amount of shares they hold. The contract calculates the number of shares required to withdraw the requested amount of assets.

### Redeem Shares:

Users can redeem their shares for the underlying assets. The contract calculates the amount of assets corresponding to the number of shares being redeemed and transfers these assets to the user. This process also involves burning the redeemed shares.

### Staking and Shares:

When users deposit assets, the contract mints new shares and assigns them to the user based on the deposit amount.
Shares are a representation of the user’s stake and can be redeemed or used to withdraw assets.

### Asset Conversion:

The contract includes functions to convert between assets and shares, ensuring that users can easily determine the amount of shares they will receive for a given deposit or the amount of assets they will receive for a given redemption.
