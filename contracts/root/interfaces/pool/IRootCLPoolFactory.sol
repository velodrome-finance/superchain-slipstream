// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IVoter} from "../../../core/interfaces/IVoter.sol";

/// @title Velodrome Superchain Root CL Pool Factory interface
/// @notice The Factory is used to create Root CL Pools
interface IRootCLPoolFactory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a root pool is created
    /// @param token0 The first token of the root pool by address sort order
    /// @param token1 The second token of the root pool by address sort order
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param chainid The Chain ID of the root pool
    /// @param pool The address of the root pool
    event RootPoolCreated(
        address indexed token0, address indexed token1, int24 indexed tickSpacing, uint256 chainid, address pool
    );

    /// @notice Emitted when a new tick spacing is enabled for pool creation via the factory
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools
    /// @param fee The default fee for a pool created with a given tickSpacing
    event TickSpacingEnabled(int24 indexed tickSpacing, uint24 indexed fee);

    /// @notice The address of the pool implementation contract used to deploy proxies / clones
    /// @return The address of the pool implementation contract
    function implementation() external view returns (address);

    /// @notice Address of the bridge contract
    /// @dev Used as a registry of chains
    function bridge() external view returns (address);

    /// @notice Returns the current owner of the root pool factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the root pool factory owner
    function owner() external view returns (address);

    /// @notice Returns a default fee for a tick spacing.
    /// @dev Use getFee for the most up to date fee for a given pool.
    /// A tick spacing can never be removed, so this value should be hard coded or cached in the calling context
    /// @param tickSpacing The enabled tick spacing. Returns 0 if not enabled
    /// @return fee The default fee for the given tick spacing
    function tickSpacingToFee(int24 tickSpacing) external view returns (uint24 fee);

    /// @notice Returns a list of enabled tick spacings. Used to iterate through pools created by the factory
    /// @dev Tick spacings cannot be removed. Tick spacings are not ordered
    /// @return List of enabled tick spacings
    function tickSpacings() external view returns (int24[] memory);

    /// @notice Returns the root pool address for a given pair of tokens, a tick spacing and chainid, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param chainid Chain ID associated with pool
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The pool address
    function getPool(uint256 chainid, address tokenA, address tokenB, int24 tickSpacing)
        external
        view
        returns (address pool);

    /// @notice Return address of pool created by this factory given its `index`
    /// @param index Index of the pool
    /// @return The pool address in the given index
    function allPools(uint256 index) external view returns (address);

    /// @notice Returns all pools created by this factory
    /// @return Array of pool addresses
    function allPools() external view returns (address[] memory);

    /// @notice Returns the number of pools created from this factory
    /// @return Number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Always returns false as these pools are not real pools
    /// @dev Guarantees gauges attached to pools must be created by the governor
    function isPool(address pool) external view returns (bool);

    /// @notice Always returns false as these pools are not real pools
    /// @dev Guarantees gauges attached to pools must be created by the governor
    function isPair(address pool) external view returns (bool);

    /// @notice Creates a root pool for the given two tokens and a tick spacing
    /// @param chainid leaf chain's chainid
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param tickSpacing The desired tick spacing for the pool
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. The call will
    /// revert if the pool already exists, the tick spacing is invalid, or the token arguments are invalid
    /// @return pool The address of the newly created pool
    function createPool(uint256 chainid, address tokenA, address tokenB, int24 tickSpacing)
        external
        returns (address pool);

    /// @notice Updates the owner of the root pool factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the root pool factory
    function setOwner(address _owner) external;

    /// @notice Enables a certain tickSpacing
    /// @dev Tick spacings may never be removed once enabled
    /// @param tickSpacing The spacing between ticks to be enforced in the pool
    /// @param fee The default fee associated with a given tick spacing
    function enableTickSpacing(int24 tickSpacing, uint24 fee) external;
}
