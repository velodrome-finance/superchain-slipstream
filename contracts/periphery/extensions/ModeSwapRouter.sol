// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import {SwapRouter} from "../SwapRouter.sol";
import {IFeeSharing} from "../../extensions/interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../extensions/interfaces/IModeFeeSharing.sol";

/// @notice Swap Router wrapper with fee sharing support
contract ModeSwapRouter is SwapRouter {
    constructor(address _factory, address _WETH9) SwapRouter(_factory, _WETH9) {
        address sfs = IModeFeeSharing(_factory).sfs();
        uint256 tokenId = IModeFeeSharing(_factory).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
