// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IRootVotingRewardsFactory} from "contracts/root/interfaces/rewards/IRootVotingRewardsFactory.sol";

import {MockRootIncentiveVotingReward} from "./MockRootIncentiveVotingReward.sol";
import {MockRootFeesVotingReward} from "./MockRootFeesVotingReward.sol";

contract MockRootVotingRewardsFactory is IRootVotingRewardsFactory {
    /// @inheritdoc IRootVotingRewardsFactory
    address public immutable override bridge;

    constructor(address _bridge) {
        bridge = _bridge;
    }

    /// @inheritdoc IRootVotingRewardsFactory
    function createRewards(address, address[] memory _rewards)
        external
        override
        returns (address feesVotingReward, address incentiveVotingReward)
    {
        incentiveVotingReward =
            address(new MockRootIncentiveVotingReward({_bridge: bridge, _voter: msg.sender, _rewards: _rewards}));
        feesVotingReward = address(
            new MockRootFeesVotingReward({
                _bridge: bridge,
                _voter: msg.sender,
                _incentiveVotingReward: incentiveVotingReward,
                _rewards: _rewards
            })
        );
    }
}
