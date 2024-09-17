// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "contracts/core/interfaces/pool/ICLPoolConstants.sol";
import "contracts/core/interfaces/pool/ICLPoolState.sol";
import "contracts/core/interfaces/pool/ICLPoolDerivedState.sol";
import "contracts/core/interfaces/pool/ICLPoolActions.sol";
import "contracts/core/interfaces/pool/ICLPoolOwnerActions.sol";
import "contracts/core/interfaces/pool/ICLPoolEvents.sol";

interface ICLRootPool is ICLPoolConstants {
    /// @notice Chain Id this pool links to
    function chainId() external view returns (uint256);

    /// @notice Initialize function used in proxy deployment
    /// @dev Can be called once only
    /// Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @dev not locked because it initializes unlocked
    /// @param _chainId Chain Id this pool links to
    /// @param _factory The CL factory contract address
    /// @param _token0 The first token of the pool by address sort order
    /// @param _token1 The second token of the pool by address sort order
    /// @param _tickSpacing The pool tick spacing
    /// @param _factoryRegistry The address of the factory registry managing the pool factory
    /// @param _sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    function initialize(
        uint256 _chainId,
        address _factory,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        address _factoryRegistry,
        uint160 _sqrtPriceX96
    ) external;
}
