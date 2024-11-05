// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IRootCLPool {
    /// @notice Chain Id this pool links to
    function chainid() external view returns (uint256);

    /// @notice The contract that deployed the pool, which must adhere to the ICLFactory interface
    /// @return The contract address
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function tickSpacing() external view returns (int24);

    /// @notice Initialize function used in proxy deployment
    /// @dev Can be called once only
    /// Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @dev not locked because it initializes unlocked
    /// @param _chainid Chain Id this pool links to
    /// @param _factory The CL factory contract address
    /// @param _token0 The first token of the pool by address sort order
    /// @param _token1 The second token of the pool by address sort order
    /// @param _tickSpacing The pool tick spacing
    function initialize(uint256 _chainid, address _factory, address _token0, address _token1, int24 _tickSpacing)
        external;
}
