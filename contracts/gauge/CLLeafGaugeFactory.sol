// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "contracts/core/interfaces/ICLPool.sol";
import "./interfaces/ICLLeafGaugeFactory.sol";
import "./CLLeafGauge.sol";
import "contracts/core/interfaces/ICLFactory.sol";
import {CreateXLibrary} from "contracts/libraries/CreateXLibrary.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";

/// @notice Factory that creates leaf gauges on the superchain
contract CLLeafGaugeFactory is ICLLeafGaugeFactory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override factory;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override xerc20;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override bridge;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override nft;

    struct GaugeCreateX {
        uint256 chainId;
        bytes32 salt;
        address pool;
        bytes11 entropy;
    }

    constructor(address _voter, address _nft, address _factory, address _xerc20, address _bridge) {
        voter = _voter;
        nft = _nft;
        factory = _factory;
        xerc20 = _xerc20;
        bridge = _bridge;
    }

    /// @inheritdoc ICLLeafGaugeFactory
    function createGauge(address _token0, address _token1, int24 _tickSpacing, address _feesVotingReward, bool _isPool)
        external
        override
        returns (address gauge)
    {
        GaugeCreateX memory gcx;

        gcx.pool = ICLFactory(factory).getPool({tokenA: _token0, tokenB: _token1, tickSpacing: _tickSpacing});

        /// @dev Create pool just in case pool does not exist already. Expect it to exist most of the time.
        if (address(gcx.pool) == address(0)) {
            gcx.pool = ICLFactory(factory).createPool({
                tokenA: _token0,
                tokenB: _token1,
                tickSpacing: _tickSpacing,
                sqrtPriceX96: 79228162514264337593543950336 // encodePriceSqrt(1, 1)
            });
        }

        assembly {
            let chainId := chainid()
            mstore(add(gcx, 0x20), chainId)
        }

        gcx.salt = keccak256(abi.encodePacked(gcx.chainId, _token0, _token1, _tickSpacing));
        gcx.entropy = bytes11(gcx.salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: gcx.entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(CLLeafGauge).creationCode,
                abi.encode(
                    gcx.pool,
                    _token0,
                    _token1,
                    _tickSpacing,
                    _feesVotingReward, // fee contract
                    xerc20, // xerc20 corresponding to reward token
                    voter, // superchain voter contract
                    nft, // nft (nfpm) contract
                    bridge, // bridge to communicate x-chain
                    _isPool
                )
            )
        });
    }
}
