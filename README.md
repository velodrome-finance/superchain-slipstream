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

The latest deployment ([gauge unstake, `6b27156`](https://github.com/velodrome-finance/superchain-slipstream/commit/6b27156619d0a98902efe46463d62caf72b34a1f)) deploys the contracts below at the same address on every supported chain (Optimism, Mode, Lisk, Fraxtal, Metal, Superseed, Ink, Soneium, Swell, Unichain, Celo).

### Shared addresses (identical across all chains)

| Contract | Address |
|----------|---------|
| `LeafCLGaugeFactory` / `RootCLGaugeFactory` | `0x21dd3D2fe97ACD3bD4E597b515e572373f1C895D` |
| `LeafCLPoolFactory` / `RootCLPoolFactory` | `0x718E46d0962A66942E233760a8bd6038Ce54EdCD` |
| `LeafCLPool` / `RootCLPool` (implementation) | `0x5270d75326b0dD0607E4c8d8648A7f8CA7bFc003` |
| `LpMigrator` | `0xCE7420BaF8E3C4EDb3B27Be6425FA1304E0d09fE` |
| `MixedRouteQuoter` | `0x6Fb85c9dF1cd5B04227852997a47A97FD674d57e` |
| `MixedRouteQuoterV2` | `0x150C433608bEdb4a24c61b89712f0AE6e145df2d` |
| `MixedRouteQuoterV3` | `0x910c887157A0B6F048dA241e013fedbd5323851F` |
| `NonfungiblePositionManager` (NFT) | `0xefD0f78F93f578036AE34D52A813a4BE7D8D2D52` |
| `NonfungibleTokenPositionDescriptor` | `0xDb142C1f71697AE7BCC6EB9061b10aFd86a24D35` |
| `Quoter` | `0x426ef6F781bA0Fbc1A7b0D3399D6FA6548464C85` |
| `SwapRouter` | `0xc58C8aC11b62D9f649Ba6EBA19d6b70FcbBb2E80` |

### Per-chain addresses

`slipstreamSugar`, `swapFeeModule`, and `unstakedFeeModule` are deployed at chain-specific addresses. See the per-chain JSON files in [`deployment-addresses/`](./deployment-addresses) for the full address list on each chain.

See the main [Superchain repository](https://github.com/velodrome-finance/superchain-contracts) for the core root contracts.
