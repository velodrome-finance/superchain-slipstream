// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {NonfungiblePositionManager} from "../NonfungiblePositionManager.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";

/// @notice NFT Position Manager wrapper with fee sharing support
contract ModeNonfungiblePositionManager is NonfungiblePositionManager, ModeFeeSharing {
    constructor(
        address _owner,
        address _factory,
        address _WETH9,
        address _tokenDescriptor,
        string memory name,
        string memory symbol,
        address _recipient
    ) NonfungiblePositionManager(_owner, _factory, _WETH9, _tokenDescriptor, name, symbol) ModeFeeSharing(_recipient) {}
}
