// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ILeafCLGaugeFactory {
    event SetGaugeStakeManager(address indexed _gaugeStakeManager);
    event SetDefaultMinStakeTime(uint256 _minStakeTime);
    event SetPoolMinStakeTime(address indexed _pool, uint256 _minStakeTime);
    event SetPenaltyRate(uint256 _penaltyRate);

    /// @notice Denominator for penalty calculations (as basis points)
    function MAX_BPS() external view returns (uint256);

    /// @notice Maximum value for minStakeTime (1 week)
    function MAX_MIN_STAKE_TIME() external view returns (uint256);

    /// @notice Voter contract
    function voter() external view returns (address);
    /// @notice Address of the NonfungiblePositionManager used to create nfts that gauges will accept
    function nft() external view returns (address);
    /// @notice XERC20 contract, also is the reward token used by the gauge
    function xerc20() external view returns (address);
    /// @notice Velodrome bridge contract
    function bridge() external view returns (address);

    /// @notice Administrator that can manage stake time and penalty parameters
    function gaugeStakeManager() external view returns (address);

    /// @notice Default minimum time (in seconds) a position must be staked before claiming or withdrawing without penalty
    function defaultMinStakeTime() external view returns (uint256);

    /// @notice Returns the effective minimum stake time for a pool
    /// @dev Returns the per-pool override if set (> 0), otherwise returns defaultMinStakeTime
    /// @param _pool The pool address to query
    function minStakeTimes(address _pool) external view returns (uint256);

    /// @notice Penalty rate (in basis points) applied to rewards on early claim or withdrawal
    function penaltyRate() external view returns (uint256);

    /// @notice Set gaugeStakeManager value on gauge factory
    /// @param _manager New administrator that will be able to manage stake time and penalty parameters
    function setGaugeStakeManager(address _manager) external;

    /// @notice Sets the default minimum stake time before claiming or withdrawing without penalty
    /// @param _minStakeTime The minimum stake time in seconds
    function setDefaultMinStakeTime(uint256 _minStakeTime) external;

    /// @notice Sets a per-pool minimum stake time override before claiming or withdrawing without penalty
    /// @dev Setting to 0 resets the pool to use defaultMinStakeTime
    /// @param _pool The pool address to configure
    /// @param _minStakeTime The minimum stake time in seconds
    function setMinStakeTime(address _pool, uint256 _minStakeTime) external;

    /// @notice Sets the penalty rate for early claim or withdrawal
    /// @param _penaltyRate The penalty rate in basis points
    function setPenaltyRate(uint256 _penaltyRate) external;

    /// @notice Creates a new gauge
    /// @param _pool Pool to create a gauge for
    /// @param _feesVotingReward Reward token for fees voting
    /// @param isPool True if the gauge is linked to a pool
    function createGauge(address _pool, address _feesVotingReward, bool isPool) external returns (address gauge);
}
