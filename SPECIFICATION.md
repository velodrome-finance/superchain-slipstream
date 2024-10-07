# Superchain Slipstream

The contracts in this repository are modified from the existing Slipstream contracts to allow 
Slipstream to be deployed on the Superchain.

For a more detailed explanation of Slipstream and its contracts, please see the original [Slipstream 
specification](https://github.com/velodrome-finance/slipstream/blob/main/SPECIFICATION.md).

For a more detailed explanation of the core Velodrome Superchain contracts, please see the [Velodrome 
Superchain specification](https://github.com/velodrome-finance/superchain-contracts/blob/main/SPECIFICATION.md).

## Features

Superchain Slipstream contracts supports the same features as the vAMM / sAMM Superchain contracts. 
The new features will be described based on where the originating transaction takes place, even if 
there may be side effects on leaf chains.

### Root

- A user will be able to create a Slipstream gauge on a leaf chain by calling `createGauge` on the 
`Voter` on 
root.
- A user will be able to vote for Slipstream gauges on other chains. 
- A user will be able to claim voting rewards on the leaf chain.
- Emissions can be streamed to a Slipstream gauge on the leaf chain.
- Leaf chain Slipstream gauges will have their maximum weekly emissions capped. This cap is modifiable.
- A user will be able to bridge XVELO to any other chain with a live Superchain deployment.

### Leaf

- A user will be able to claim Slipstream gauge rewards (emissions).
- A user will be able LP in a pool and stake their LP nft in a gauge to earn emissions.
- Protocols will be able to deposit incentives for voters on the leaf chain.

## Contracts

#### Root Pool Factory
- Supports the creation of pools on the root chain for tokens on other chains. 
- The same pool factory can be reused for all leaf chains.
- Cannot create pools on the root chain.
- The interface of this pool deviates from that of v2 and Slipstream pool factories.
- If additional tick spacings are enabled, they must be enabled on both root and leaf pool factories 
in order to create the corresponding gauge.

#### RootPool
- A placeholder pool. Stores chainid and token addresses associated with the pool. 

#### Root Gauge Factory
- Supports the creation of gauges on the root and leaf chain for tokens on other chains.
- Automatically creates a pool on the leaf chain if it does not already exist.
- Supports the setting of emission caps for gauges created by this factory.
- Supports the setting of a default emission cap for gauges created by this factory.
- Supports the setting of a notify admin. This admin will be able to add additional emissions to 
leaf gauges.

#### Root Gauge
- Emissions received by the root gauge from voter will be deposited into the corresponding leaf 
gauge via the message bridge.
    - Emissions in excess of the cap as defined in the gauge factory are returned to the minter.
- Emissions received by the root gauge from the notify admin will be deposited into the corresponding 
leaf gauge via the message bridge.

#### RootBribeVotingReward, RootFeesVotingRewards &RootVotingRewardsFactory

Slipstream reuses the same root voting rewards contracts as the vAMM / sAMM Superchain contracts. 

### Leaf

#### Pool, PoolFactory
- Vanilla Velodrome Slipstream pool and pool factory contracts.

#### LeafGaugeFactory
- Supports the creation of Slipstream gauges on the leaf chain via the message bridge.
- Gauges are created with CREATE3, ensuring that they have the same address on the leaf chain and 
root chain.

#### LeafGauge
- Vanilla Velodrome Slipstream gauge contracts.
- Lightly modified to support emissions deposited from the root chain.

#### BribeVotingRewards, FeesVotingRewards, VotingRewardsFactory

Slipstream reuses the same leaf voting rewards contracts as the vAMM / sAMM Superchain contracts. 