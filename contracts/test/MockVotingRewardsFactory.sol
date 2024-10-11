// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IVotingRewardsFactory} from "./interfaces/IVotingRewardsFactory.sol";
import {MockFeesVotingReward} from "./MockFeesVotingReward.sol";
import {MockIncentiveVotingReward} from "./MockIncentiveVotingReward.sol";

/// @dev stub, unused in tests
///      see fork tests for more rigorous integration testing including voting rewards
contract MockVotingRewardsFactory is IVotingRewardsFactory {
    /// @inheritdoc IVotingRewardsFactory
    function createRewards(
        address[] memory // _rewards
    ) external override returns (address feesVotingReward, address incentiveVotingReward) {
        feesVotingReward = address(new MockFeesVotingReward());
        incentiveVotingReward = address(new MockIncentiveVotingReward());
    }
}
