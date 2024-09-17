// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "contracts/core/interfaces/ICLPool.sol";

import "contracts/core/libraries/LowGasSafeMath.sol";
import "contracts/core/libraries/SafeCast.sol";
import "contracts/core/libraries/Tick.sol";
import "contracts/core/libraries/TickBitmap.sol";
import "contracts/core/libraries/Position.sol";
import "contracts/core/libraries/Oracle.sol";

import "contracts/core/libraries/FullMath.sol";
import "contracts/core/libraries/FixedPoint128.sol";
import "contracts/core/libraries/TransferHelper.sol";
import "contracts/core/libraries/TickMath.sol";
import "contracts/core/libraries/LiquidityMath.sol";
import "contracts/core/libraries/SqrtPriceMath.sol";
import "contracts/core/libraries/SwapMath.sol";

import "contracts/core/interfaces/ICLFactory.sol";
import "contracts/core/interfaces/IFactoryRegistry.sol";
import "contracts/core/interfaces/IERC20Minimal.sol";
import "contracts/core/interfaces/callback/ICLMintCallback.sol";
import "contracts/core/interfaces/callback/ICLSwapCallback.sol";
import "contracts/core/interfaces/callback/ICLFlashCallback.sol";
import "contracts/libraries/VelodromeTimeLibrary.sol";
import {ICLRootPool} from "contracts/mainnet/pool/ICLRootPool.sol";

/// @notice RootPool used as basis for creating RootGauges
/// @dev Not a real pool
contract CLRootPool is ICLRootPool {
    /// @inheritdoc ICLRootPool
    uint256 public override chainId;
    /// @inheritdoc ICLPoolConstants
    address public override factory;
    /// @inheritdoc ICLPoolConstants
    address public override token0;
    /// @inheritdoc ICLPoolConstants
    address public override token1;
    /// @inheritdoc ICLPoolConstants
    address public override gauge;
    /// @inheritdoc ICLPoolConstants
    address public override nft;
    /// @inheritdoc ICLPoolConstants
    address public override factoryRegistry;
    /// @inheritdoc ICLPoolConstants
    int24 public override tickSpacing;
    /// @inheritdoc ICLPoolConstants
    uint128 public override maxLiquidityPerTick;

    constructor() {}

    /// @inheritdoc ICLRootPool
    function initialize(
        uint256 _chainId,
        address _factory,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        address _factoryRegistry,
        uint160 _sqrtPriceX96
    ) external override {
        require(factory == address(0) && _factory != address(0));
        chainId = _chainId;
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        tickSpacing = _tickSpacing;
        factoryRegistry = _factoryRegistry;
    }
}
