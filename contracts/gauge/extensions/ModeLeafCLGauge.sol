// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {LeafCLGauge} from "../LeafCLGauge.sol";
import {IFeeSharing} from "../../extensions/interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../extensions/interfaces/IModeFeeSharing.sol";

/// @notice Gauge wrapper with fee sharing support
contract ModeLeafCLGauge is LeafCLGauge {
    constructor(
        address _pool,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        address _bridge,
        bool _isPool
    )
        LeafCLGauge(_pool, _token0, _token1, _tickSpacing, _feesVotingReward, _rewardToken, _voter, _nft, _bridge, _isPool)
    {
        address sfs = IModeFeeSharing(_nft).sfs();
        uint256 tokenId = IModeFeeSharing(_nft).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
