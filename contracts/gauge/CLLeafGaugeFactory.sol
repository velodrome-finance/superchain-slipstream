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
    address public immutable override xerc20;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override bridge;
    /// @inheritdoc ICLLeafGaugeFactory
    address public immutable override nft;

    struct GaugeCreateX {
        uint256 chainId;
        bytes32 salt;
        address pool;
        address token0;
        address token1;
        int24 tickSpacing;
        bytes11 entropy;
    }

    constructor(address _voter, address _nft, address _xerc20, address _bridge) {
        voter = _voter;
        nft = _nft;
        xerc20 = _xerc20;
        bridge = _bridge;
    }

    /// @inheritdoc ICLLeafGaugeFactory
    function createGauge(address _pool, address _feesVotingReward, bool _isPool)
        external
        override
        returns (address gauge)
    {
        require(msg.sender == voter, "NV");
        GaugeCreateX memory gcx;

        gcx.pool = _pool;

        assembly {
            let chainId := chainid()
            mstore(add(gcx, 0x20), chainId)
        }

        gcx.token0 = ICLPool(_pool).token0();
        gcx.token1 = ICLPool(_pool).token1();
        gcx.tickSpacing = ICLPool(_pool).tickSpacing();
        gcx.salt = keccak256(abi.encodePacked(gcx.chainId, gcx.token0, gcx.token1, gcx.tickSpacing));
        gcx.entropy = bytes11(gcx.salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: gcx.entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(CLLeafGauge).creationCode,
                abi.encode(
                    gcx.pool,
                    gcx.token0,
                    gcx.token1,
                    gcx.tickSpacing,
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
