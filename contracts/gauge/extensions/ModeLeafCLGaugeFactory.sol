// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {ILeafCLGaugeFactory, LeafCLGaugeFactory, CreateXLibrary} from "../LeafCLGaugeFactory.sol";
import {IModeFeeSharing} from "../../extensions/interfaces/IModeFeeSharing.sol";
import {IFeeSharing} from "../../extensions/interfaces/IFeeSharing.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {ModeLeafCLGauge} from "./ModeLeafCLGauge.sol";

/// @notice Gauge Factory wrapper with fee sharing support
contract ModeLeafCLGaugeFactory is LeafCLGaugeFactory {
    using CreateXLibrary for bytes11;

    constructor(address _voter, address _nft, address _xerc20, address _bridge)
        LeafCLGaugeFactory(_voter, _nft, _xerc20, _bridge)
    {
        address sfs = IModeFeeSharing(_nft).sfs();
        uint256 tokenId = IModeFeeSharing(_nft).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }

    /// @inheritdoc ILeafCLGaugeFactory
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
            mstore(gcx, chainId)
        }

        gcx.token0 = ICLPool(_pool).token0();
        gcx.token1 = ICLPool(_pool).token1();
        gcx.tickSpacing = ICLPool(_pool).tickSpacing();
        gcx.salt = keccak256(abi.encodePacked(gcx.chainid, gcx.token0, gcx.token1, gcx.tickSpacing));
        gcx.entropy = bytes11(gcx.salt);

        gauge = CreateXLibrary.CREATEX.deployCreate3({
            salt: gcx.entropy.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(ModeLeafCLGauge).creationCode,
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
