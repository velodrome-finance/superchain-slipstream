// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IModeFeeSharing} from "./interfaces/IModeFeeSharing.sol";
import {IFeeSharing} from "./interfaces/IFeeSharing.sol";

/// @notice Wrapper to include fee sharing support in Superchain contracts
abstract contract ModeFeeSharing is IModeFeeSharing {
    /// @inheritdoc IModeFeeSharing
    address public constant override sfs = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;
    /// @inheritdoc IModeFeeSharing
    uint256 public immutable override tokenId;

    constructor(address _recipient) {
        tokenId = IFeeSharing(sfs).register(_recipient);
    }
}
