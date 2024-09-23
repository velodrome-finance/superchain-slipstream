// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IRootVotingRewardsFactory} from "contracts/mainnet/interfaces/rewards/IRootVotingRewardsFactory.sol";

import {MockRootBribeVotingReward} from "./MockRootBribeVotingReward.sol";
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
        returns (address feesVotingReward, address bribeVotingReward)
    {
        bribeVotingReward =
            address(new MockRootBribeVotingReward({_bridge: bridge, _voter: msg.sender, _rewards: _rewards}));
        feesVotingReward = address(
            new MockRootFeesVotingReward({
                _bridge: bridge,
                _voter: msg.sender,
                _bribeVotingReward: bribeVotingReward,
                _rewards: _rewards
            })
        );
    }
}
