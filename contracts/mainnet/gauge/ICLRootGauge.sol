// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLRootGauge {
    event NotifyReward(address indexed _sender, uint256 _amount);

    /// @notice Reward token supported by this gauge
    function rewardToken() external view returns (address);

    /// @notice XERC20 token corresponding to reward token
    function xerc20() external view returns (address);

    /// @notice Lockbox to wrap and unwrap reward token to and from XERC20
    function lockbox() external view returns (address);

    /// @notice Bridge contract used to communicate x-chain
    function bridge() external view returns (address);

    /// @notice Chain id associated with this pool / gauge
    function chainid() external view returns (uint256);

    /// @notice Helper used by Voter
    function left() external view returns (uint256);

    /// @notice Used by voter to deposit rewards to the gauge
    function notifyRewardAmount(uint256 _amount) external;
}
