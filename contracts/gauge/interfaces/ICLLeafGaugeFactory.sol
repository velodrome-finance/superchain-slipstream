// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLLeafGaugeFactory {
    /// @notice Voter contract
    function voter() external view returns (address);
    /// @notice Address of the NonfungiblePositionManager used to create nfts that gauges will accept
    function nft() external view returns (address);
    /// @notice Factory contract that produces pools that this gauge will link to
    function factory() external view returns (address);
    /// @notice XERC20 contract, also is the reward token used by the gauge
    function xerc20() external view returns (address);
    /// @notice Velodrome bridge contract
    function bridge() external view returns (address);

    /// @notice Creates a new gauge
    /// @param _token0 Token0 address
    /// @param _token1 Token1 address
    /// @param _tickSpacing The pool's tick spacing
    /// @param _feesVotingReward Reward token for fees voting
    /// @param isPool True if the gauge is linked to a pool
    function createGauge(address _token0, address _token1, int24 _tickSpacing, address _feesVotingReward, bool isPool)
        external
        returns (address gauge);
}
