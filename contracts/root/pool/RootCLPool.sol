// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IRootCLPool} from "../interfaces/pool/IRootCLPool.sol";

/// @notice RootPool used as basis for creating RootGauges
/// @dev Not a real pool
contract RootCLPool is IRootCLPool {
    /// @inheritdoc IRootCLPool
    uint256 public override chainid;
    /// @inheritdoc IRootCLPool
    address public override factory;
    /// @inheritdoc IRootCLPool
    address public override token0;
    /// @inheritdoc IRootCLPool
    address public override token1;
    /// @inheritdoc IRootCLPool
    int24 public override tickSpacing;

    /// @inheritdoc IRootCLPool
    function initialize(uint256 _chainid, address _factory, address _token0, address _token1, int24 _tickSpacing)
        external
        override
    {
        require(factory == address(0) && _factory != address(0));
        chainid = _chainid;
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        tickSpacing = _tickSpacing;
    }
}
