// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import {CLFactory} from "../CLFactory.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice CL Factory wrapper with fee sharing support
contract ModeCLFactory is CLFactory, ModeFeeSharing {
    constructor(
        address _owner,
        address _swapFeeManager,
        address _unstakedFeeManager,
        address _voter,
        address _poolImplementation,
        address _gaugeFactory,
        address _nft,
        address _recipient
    )
        CLFactory(_owner, _swapFeeManager, _unstakedFeeManager, _voter, _poolImplementation, _gaugeFactory, _nft)
        ModeFeeSharing(_recipient)
    {}
}
