// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IVotingRewardsFactory {
    /// @notice creates a BribeVotingReward and a FeesVotingReward contract for a gauge
    /// @param _rewards Addresses of pool tokens to be used as valid rewards tokens
    /// @return feesVotingReward Address of FeesVotingReward contract created
    /// @return bribeVotingReward Address of BribeVotingReward contract created
    function createRewards(address[] memory _rewards)
        external
        returns (address feesVotingReward, address bribeVotingReward);
}
