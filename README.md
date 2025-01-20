# Velodrome Superchain Slipstream Contracts

This repository contains the smart contracts for the Velodrome Superchain Slipstream. It is adapted from the original Slipstream contracts for use on the Velodrome Superchain.

See `SPECIFICATION.md` for more information. See the original [Slipstream](https://github.com/velodrome-finance/slipstream) repository for more information about Slipstream.

## Installation

This repository is a hybrid hardhat and foundry repository.

Install hardhat dependencies with `yarn install`.
Install foundry dependencies with `forge install`.

Run hardhat tests with `yarn test`.
Run forge tests with `forge test`.

## Testing

### Invariants

To run the invariant tests, echidna must be installed. The following instructions require additional installations (e.g. of solc-select). 

```
echidna test/invariants/E2E_mint_burn.sol --config test/invariants/E2E_mint_burn.config.yaml --contract E2E_mint_burn
echidna test/invariants/E2E_swap.sol --config test/invariants/E2E_swap.config.yaml --contract E2E_swap
```

## Deployment

See `script/README.md` for deployment instructions.

## Licensing

This project follows the [Apache Foundation](https://infra.apache.org/licensing-howto.html)
guideline for licensing. See LICENSE and NOTICE files.

## Bug Bounty
Velodrome has a live bug bounty hosted on ([Immunefi](https://immunefi.com/bounty/velodromefinance/)).

## Deployment

| Chain      | Addresses          | Deployment Commit |
|------------|--------------------|-------------------|
| Optimism   | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/root-optimism.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      |
| Mode       | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/mode.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      |
| Lisk       | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/lisk.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      |
| Fraxtal    | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/fraxtal.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      |
| Metal      | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/metal.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      | 
| Superseed  | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/superseed.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      |
| Ink        | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/ink.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      | 
| Soneium    | [Addresses](https://github.com/velodrome-finance/superchain-slipstream/blob/main/deployment-addresses/soneium.json)           | [v1.0](https://github.com/velodrome-finance/superchain-slipstream/commit/63b2e08a11f42d91dc6f8487643ecb3d79e745c4)      | 

See the main [Superchain repository](https://github.com/velodrome-finance/superchain-contracts) for the core root contracts.
