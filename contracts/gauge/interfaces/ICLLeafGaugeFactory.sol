// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLLeafGaugeFactory {
    /// @notice Voter contract
    function voter() external view returns (address);
    /// @notice Address of the NonfungiblePositionManager used to create nfts that gauges will accept
    function nft() external view returns (address);
    /// @notice XERC20 contract, also is the reward token used by the gauge
    function xerc20() external view returns (address);
    /// @notice Velodrome bridge contract
    function bridge() external view returns (address);

    /// @notice Creates a new gauge
    /// @param _pool Pool to create a gauge for
    /// @param _feesVotingReward Reward token for fees voting
    /// @param isPool True if the gauge is linked to a pool
    function createGauge(address _pool, address _feesVotingReward, bool isPool) external returns (address gauge);
}
